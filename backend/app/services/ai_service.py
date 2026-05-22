from __future__ import annotations

import logging
import os
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Tuple

logger = logging.getLogger(__name__)


def _env_int(name: str, default: int, minimum: int, maximum: int) -> int:
    try:
        value = int(os.getenv(name, str(default)))
    except ValueError:
        return default
    return max(minimum, min(value, maximum))


def _env_float(name: str, default: float, minimum: float, maximum: float) -> float:
    try:
        value = float(os.getenv(name, str(default)))
    except ValueError:
        return default
    return max(minimum, min(value, maximum))


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
        self._cv2: Any | None = None
        self._np: Any | None = None
        self._model: Any | None = None
        self._model_checked = False
        self._hands: Any | None = None
        self._hands_checked = False
        self._face_cascade: Any | None = None
        self._previous_gray: Dict[str, Any] = {}
        self._last_charged_event_at: Dict[str, float] = {}
        self._last_yolo_run_at: Dict[str, float] = {}
        self._last_yolo_result: Dict[str, Tuple[int, int, List[str]]] = {}
        self._frame_width = _env_int("AI_FRAME_WIDTH", 480, 320, 1280)
        self._yolo_image_size = _env_int("AI_YOLO_IMAGE_SIZE", 480, 320, 1280)
        self._yolo_min_interval = _env_float("AI_YOLO_MIN_INTERVAL_SECONDS", 0.5, 0.0, 10.0)

    def process_frame(self, session_id: str, frame: Any, camera: str = "front") -> Detection:
        if frame is None:
            return Detection(False, "Invalid camera frame")

        cv2 = self._get_cv2()
        resized = self._resize(frame)
        annotated = resized.copy()
        events: List[Dict] = []

        persons, phones, objects = self._detect_yolo(session_id, camera, resized)
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

    def _get_cv2(self):
        if self._cv2 is None:
            import cv2

            self._cv2 = cv2
        return self._cv2

    def _get_numpy(self):
        if self._np is None:
            import numpy as np

            self._np = np
        return self._np

    def _get_model(self):
        if self._model_checked:
            return self._model

        with self._lock:
            if self._model_checked:
                return self._model

            self._model_checked = True
            os.environ.setdefault("YOLO_CONFIG_DIR", "/tmp")
            try:
                from ultralytics import YOLO
            except Exception:
                logger.exception("Ultralytics unavailable; YOLO detection disabled until backend restart")
                return None

            for candidate in self._model_candidates():
                if not candidate.exists():
                    continue
                try:
                    logger.info("Loading YOLO model on first AI frame; path=%s", candidate)
                    self._model = YOLO(str(candidate))
                    break
                except Exception:
                    logger.exception("YOLO model load failed; path=%s", candidate)
                    self._model = None
        return self._model

    def _model_candidates(self) -> List[Path]:
        configured_model = os.getenv("YOLO_MODEL_PATH")
        backend_dir = Path(__file__).resolve().parents[2]
        candidates = [
            Path(configured_model) if configured_model else None,
            backend_dir / "models" / "yolov8n.pt",
            Path.cwd() / "models" / "yolov8n.pt",
            Path.cwd() / "yolov8n.pt",
            Path.cwd().parent / "models" / "yolov8n.pt",
            Path.cwd().parent / "yolov8n.pt",
        ]
        return [candidate for candidate in candidates if candidate is not None]

    def _get_hands(self):
        if self._hands_checked:
            return self._hands

        with self._lock:
            if self._hands_checked:
                return self._hands

            self._hands_checked = True
            try:
                import mediapipe as mp

                self._hands = mp.solutions.hands.Hands(
                    static_image_mode=True,
                    max_num_hands=2,
                    min_detection_confidence=0.45,
                )
            except Exception:
                logger.exception("MediaPipe hand detection unavailable until backend restart")
                self._hands = None
        return self._hands

    def _get_face_cascade(self):
        if self._face_cascade is None:
            cv2 = self._get_cv2()
            self._face_cascade = cv2.CascadeClassifier(
                cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            )
        return self._face_cascade

    def _resize(self, frame: Any):
        cv2 = self._get_cv2()
        h, w = frame.shape[:2]
        target_width = self._frame_width
        if w <= target_width:
            return frame
        scale = target_width / float(w)
        return cv2.resize(frame, (target_width, int(h * scale)))

    def _detect_yolo(self, session_id: str, camera: str, frame: Any) -> Tuple[int, int, List[str]]:
        cache_key = f"{session_id}:{camera}"
        now = time.monotonic()
        cached = self._last_yolo_result.get(cache_key)
        last_run = self._last_yolo_run_at.get(cache_key, 0.0)
        if cached is not None and now - last_run < self._yolo_min_interval:
            return cached

        model = self._get_model()
        if model is None:
            return cached or (1, 0, [])

        with self._lock:
            results = model.predict(
                frame,
                verbose=False,
                conf=0.35,
                imgsz=self._yolo_image_size,
            )

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
        detection = (persons, phones, objects)
        self._last_yolo_run_at[cache_key] = time.monotonic()
        self._last_yolo_result[cache_key] = detection
        return detection

    def _detect_hands(self, frame: Any) -> int:
        hands = self._get_hands()
        if hands is None:
            return 0
        cv2 = self._get_cv2()
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = hands.process(rgb)
        return len(result.multi_hand_landmarks or [])

    def _detect_faces(self, frame: Any) -> int:
        cv2 = self._get_cv2()
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = self._get_face_cascade().detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(40, 40),
        )
        return len(faces)

    def _movement_score(self, session_id: str, frame: Any) -> float:
        cv2 = self._get_cv2()
        np = self._get_numpy()
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
