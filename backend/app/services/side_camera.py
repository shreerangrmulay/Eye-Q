from __future__ import annotations

import logging
import re
import threading
import time
from urllib.parse import urlparse

_readers: dict[str, "IPCameraReader"] = {}
_readers_lock = threading.Lock()
_fresh_frame_seconds = 2.5
logger = logging.getLogger(__name__)
_cv2_module = None


def _cv2():
    global _cv2_module
    if _cv2_module is None:
        import cv2

        _cv2_module = cv2
    return _cv2_module


def detect_stream_type(camera_url: str) -> str:
    value = camera_url.strip().lower()
    if value.startswith("rtsp://"):
        return "RTSP"
    if value.startswith("https://"):
        return "HTTPS"
    if value.startswith("http://"):
        return "HTTP"
    return "UNKNOWN"


def _is_ip_like(value: str) -> bool:
    host = value.split(":", 1)[0].strip()
    return bool(re.fullmatch(r"(?:\d{1,3}\.){3}\d{1,3}", host))


def _candidate_urls(camera_input: str) -> list[str]:
    value = camera_input.strip()
    if not value:
        raise ValueError("Camera URL or IP is required")

    if value.startswith(("rtsp://", "http://", "https://")):
        parsed = urlparse(value)
        if not parsed.hostname:
            raise ValueError("Enter a valid camera URL or IP")
        if parsed.scheme in {"http", "https"} and parsed.path in ("", "/"):
            return [value.rstrip("/") + "/video", value.rstrip("/")]
        return [value]

    if not _is_ip_like(value):
        raise ValueError("Enter a valid camera URL or IP")

    if ":" in value:
        host, port = value.rsplit(":", 1)
        if not port.isdigit():
            raise ValueError("Enter a valid camera URL or IP")
        return [
            f"http://{host}:{port}/video",
            f"http://{host}:{port}",
            f"rtsp://{host}:{port}",
        ]

    return [
        f"http://{value}:8080/video",
        f"http://{value}:4747/video",
        f"rtsp://{value}:8554",
        f"rtsp://{value}:8556",
        f"http://{value}/video",
    ]


def normalize_camera_url(camera_input: str) -> str:
    return _candidate_urls(camera_input)[0]


def normalize_side_camera_url(raw_url: str) -> str:
    return normalize_camera_url(raw_url)


class IPCameraReader:
    def __init__(self, url: str):
        self.url = url
        self._lock = threading.Lock()
        self._frame = None
        self._last_frame_at = 0.0
        self._capture = None
        self._running = True
        self._frames_read = 0
        self._frame_failures = 0
        self._fps_window_at = time.monotonic()
        self._thread = threading.Thread(target=self._read_loop, daemon=True)
        self._thread.start()

    def read_fresh_frame(self):
        with self._lock:
            age = time.monotonic() - self._last_frame_at
            if self._frame is None or age > _fresh_frame_seconds:
                return False, None
            return True, self._frame.copy()

    def _read_loop(self):
        while self._running:
            capture = self._open_capture()
            if capture is None:
                time.sleep(0.25)
                continue

            with self._lock:
                self._capture = capture
            logger.info("Side camera capture opened; url=%s", self.url)

            misses = 0
            while self._running:
                try:
                    ok, frame = capture.read()
                except Exception:
                    logger.exception("Side camera frame read crashed; url=%s", self.url)
                    ok, frame = False, None
                if ok and frame is not None:
                    misses = 0
                    with self._lock:
                        self._frame = frame
                        self._last_frame_at = time.monotonic()
                    self._log_frame_read(True)
                    continue

                misses += 1
                self._log_frame_read(False)
                time.sleep(0.1)
                if misses >= 5:
                    logger.warning(
                        "Side camera frame reads stalled; reopening capture; url=%s",
                        self.url,
                    )
                    break

            capture.release()
            with self._lock:
                if self._capture is capture:
                    self._capture = None
            logger.info("Side camera capture closed for reconnect; url=%s", self.url)

    def _open_capture(self):
        cv2 = _cv2()
        try:
            capture = cv2.VideoCapture(self.url)
        except Exception:
            logger.exception("Side camera capture create failed; url=%s", self.url)
            return None
        if not capture.isOpened():
            logger.warning("Side camera capture open failed; url=%s", self.url)
            capture.release()
            return None
        capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        for prop_name in ("CAP_PROP_OPEN_TIMEOUT_MSEC", "CAP_PROP_READ_TIMEOUT_MSEC"):
            prop = getattr(cv2, prop_name, None)
            if prop is not None:
                capture.set(prop, 3000)
        return capture

    def _log_frame_read(self, ok: bool):
        self._frames_read += int(ok)
        self._frame_failures += int(not ok)
        now = time.monotonic()
        elapsed = now - self._fps_window_at
        if elapsed < 5.0:
            return
        logger.info(
            "Side camera reader fps=%.1f frames=%s failed_reads=%s; url=%s",
            self._frames_read / elapsed,
            self._frames_read,
            self._frame_failures,
            self.url,
        )
        self._frames_read = 0
        self._frame_failures = 0
        self._fps_window_at = now

def read_side_camera_frame(url: str, timeout_seconds: float = 4.0):
    reader = _get_reader(url)
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        ok, frame = reader.read_fresh_frame()
        if ok:
            return True, frame
        time.sleep(0.05)
    return False, None


def test_camera_connection(camera_input: str, timeout_seconds: float = 4.0):
    errors: list[str] = []
    for candidate in _candidate_urls(camera_input):
        ok, frame = read_side_camera_frame(candidate, timeout_seconds=timeout_seconds)
        if ok and frame is not None and frame.size > 0:
            return True, candidate, detect_stream_type(candidate), frame
        errors.append(candidate)
    return False, "", "UNKNOWN", None


def _get_reader(url: str) -> IPCameraReader:
    with _readers_lock:
        reader = _readers.get(url)
        if reader is None:
            reader = IPCameraReader(url)
            _readers[url] = reader
        return reader


def get_latest_side_camera_frame(url: str):
    return _get_reader(url).read_fresh_frame()


def validate_side_camera_url(raw_url: str):
    ok, url, _stream_type, frame = test_camera_connection(raw_url)
    if not ok:
        raise ValueError("Unable to connect to side camera")
    return url, frame
