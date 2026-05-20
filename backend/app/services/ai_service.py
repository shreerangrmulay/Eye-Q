from __future__ import annotations

import os
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Tuple

import cv2
import numpy as np

try:
    from ultralytics import YOLO
except Exception:
    YOLO = None

try:
    import mediapipe as mp
except Exception:
    mp = None


@dataclass
class Detection:
    cheating: bool
    message: str
    cheat_type: str = ""
    confidence: float = 0.0
    score_delta: float = 0.0
    events: List[Dict] = field(default_factory=list)
    annotated_jpeg: bytes | None = None


class AIProctorService:
    def __init__(self):
        self._lock = threading.Lock()
        self._model = None
        self._hands = None
        self._previous_gray: Dict[str, np.ndarray] = {}
        self._last_charged_event_at: Dict[str, float] = {}
        self._face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
        self._load_models()

    def _load_models(self):
        if YOLO is not None:
            model_path = os.getenv("YOLO_MODEL_PATH")
            candidates = [
                Path(model_path) if model_path else None,
                Path.cwd() / "models" / "yolov8s.pt",
                Path.cwd() / "models" / "yolov8n.pt",
                Path.cwd() / "yolov8s.pt",
                Path.cwd().parent / "yolov8s.pt",
                Path.cwd().parent / "yolov8n.pt",
            ]
            for candidate in candidates:
                if candidate and candidate.exists():
                    try:
                        self._model = YOLO(str(candidate))
                        break
                    except Exception:
                        self._model = None

        if mp is not None:
            try:
                self._hands = mp.solutions.hands.Hands(
                    static_image_mode=True,
                    max_num_hands=2,
                    min_detection_confidence=0.45,
                )
            except Exception:
                self._hands = None

    def process_frame(self, session_id: str, frame: np.ndarray, camera: str = "front") -> Detection:
        if frame is None:
            return Detection(False, "Invalid camera frame")

        resized = self._resize(frame)
        annotated = resized.copy()
        events: List[Dict] = []

        persons, phones, objects = self._detect_yolo(resized)
        hand_count = self._detect_hands(resized)
        face_count = self._detect_faces(resized)
        movement_score = self._movement_score(session_id, resized)

        if camera == "front" and persons > 1 and face_count > 1:
            events.append(self._event("MULTIPLE_PERSONS", "CRITICAL", "Multiple persons detected", 0.92, 35))
        elif camera == "front" and persons == 0 and face_count == 0:
            events.append(self._event("FACE_MISSING", "MEDIUM", "Candidate face not visible", 0.62, 0))

        if phones > 0:
            prefix = "Side camera: " if camera == "side" else ""
            events.append(self._event("PHONE", "CRITICAL", f"{prefix}Mobile phone detected", 0.95, 30))

        if camera == "front" and hand_count > 1 and movement_score > 0.22:
            events.append(self._event("SUSPICIOUS_MOVEMENT", "LOW", "Unusual hand or body movement", 0.58, 0))

        if objects:
            label = ", ".join(sorted(set(objects))[:3])
            prefix = "Side camera: " if camera == "side" else ""
            events.append(self._event("SUSPICIOUS_OBJECT", "MEDIUM", f"{prefix}Suspicious object visible: {label}", 0.62, 4))

        events = [self._with_cooldown(session_id, event) for event in events]

        for label, value, point in [
            ("Persons", persons, (12, 24)),
            ("Faces", face_count, (12, 48)),
            ("Hands", hand_count, (12, 72)),
            ("Movement", f"{movement_score:.2f}", (12, 96)),
        ]:
            cv2.putText(
                annotated,
                f"{label}: {value}",
                point,
                cv2.FONT_HERSHEY_SIMPLEX,
                0.55,
                (0, 255, 255),
                2,
            )

        if events:
            top = max(events, key=lambda item: item["score_delta"])
            message = top["message"]
            cheat_type = top["event_type"]
            confidence = max(event["confidence"] for event in events)
            score_delta = sum(event["score_delta"] for event in events if event.get("chargeable", True))
            cheating = any(event["severity"] in ("HIGH", "CRITICAL") for event in events)
        else:
            message = "Clear"
            cheat_type = ""
            confidence = 0.12
            score_delta = 0.0
            cheating = False

        ok, buffer = cv2.imencode(".jpg", annotated, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        return Detection(
            cheating=cheating,
            message=message,
            cheat_type=cheat_type,
            confidence=confidence,
            score_delta=score_delta,
            events=events,
            annotated_jpeg=buffer.tobytes() if ok else None,
        )

    def _resize(self, frame: np.ndarray) -> np.ndarray:
        h, w = frame.shape[:2]
        target_width = 640
        if w <= target_width:
            return frame
        scale = target_width / float(w)
        return cv2.resize(frame, (target_width, int(h * scale)))

    def _detect_yolo(self, frame: np.ndarray) -> Tuple[int, int, List[str]]:
        if self._model is None:
            return 1, 0, []

        with self._lock:
            results = self._model.predict(frame, verbose=False, conf=0.35, imgsz=640)

        persons = 0
        phones = 0
        objects: List[str] = []
        suspicious_names = {"book", "remote"}
        for result in results:
            names = result.names
            for box in result.boxes:
                cls_id = int(box.cls[0])
                confidence = float(box.conf[0])
                name = str(names.get(cls_id, "")).lower()
                if name == "person":
                    persons += 1
                elif name in {"cell phone", "mobile phone", "phone"} and confidence >= 0.50:
                    phones += 1
                elif name in suspicious_names:
                    objects.append(name)
        return persons, phones, objects

    def _detect_hands(self, frame: np.ndarray) -> int:
        if self._hands is None:
            return 0
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = self._hands.process(rgb)
        return len(result.multi_hand_landmarks or [])

    def _detect_faces(self, frame: np.ndarray) -> int:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = self._face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(40, 40))
        return len(faces)

    def _movement_score(self, session_id: str, frame: np.ndarray) -> float:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (21, 21), 0)
        previous = self._previous_gray.get(session_id)
        self._previous_gray[session_id] = gray
        if previous is None:
            return 0.0
        diff = cv2.absdiff(previous, gray)
        return float(np.count_nonzero(diff > 30)) / float(diff.size)

    def _event(self, event_type: str, severity: str, message: str, confidence: float, score_delta: float) -> Dict:
        return {
            "event_type": event_type,
            "severity": severity,
            "message": message,
            "confidence": confidence,
            "score_delta": score_delta,
            "chargeable": True,
        }

    def _with_cooldown(self, session_id: str, event: Dict) -> Dict:
        if event["score_delta"] <= 0:
            event["chargeable"] = False
            return event

        now = time.time()
        key = f"{session_id}:{event['event_type']}"
        last = self._last_charged_event_at.get(key, 0.0)
        if now - last < 15.0:
            return {**event, "score_delta": 0.0, "chargeable": False}

        self._last_charged_event_at[key] = now
        return event


ai_service = AIProctorService()
