import asyncio
import logging
from collections import defaultdict
from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self):
        self.admin_connections: List[WebSocket] = []
        self.session_connections: Dict[str, List[WebSocket]] = defaultdict(list)

    async def connect_admin(self, websocket: WebSocket):
        await websocket.accept()
        self.admin_connections.append(websocket)
        logger.info("Admin websocket connected; total=%s", len(self.admin_connections))

    async def connect_session(self, session_id: str, websocket: WebSocket):
        await websocket.accept()
        self.session_connections[session_id].append(websocket)
        logger.info(
            "Session websocket connected; session_id=%s total=%s",
            session_id,
            len(self.session_connections[session_id]),
        )

    def disconnect_admin(self, websocket: WebSocket):
        if websocket in self.admin_connections:
            self.admin_connections.remove(websocket)
            logger.info("Admin websocket disconnected; total=%s", len(self.admin_connections))

    def disconnect_session(self, session_id: str, websocket: WebSocket):
        connections = self.session_connections.get(session_id, [])
        if websocket in connections:
            connections.remove(websocket)
            logger.info(
                "Session websocket disconnected; session_id=%s total=%s",
                session_id,
                len(connections),
            )

    async def _send_many(self, connections: List[WebSocket], message: dict):
        stale = []
        for connection in list(connections):
            try:
                await connection.send_json(message)
            except Exception:
                logger.exception("Dropping stale websocket connection")
                stale.append(connection)
        for connection in stale:
            if connection in connections:
                connections.remove(connection)

    async def broadcast_admin(self, message: dict):
        await self._send_many(self.admin_connections, message)

    async def broadcast_session(self, session_id: str, message: dict):
        await self._send_many(self.session_connections.get(session_id, []), message)

    async def broadcast(self, session_id: str, message: dict):
        await asyncio.gather(
            self.broadcast_admin(message),
            self.broadcast_session(session_id, message),
        )


manager = ConnectionManager()
latest_frames: Dict[str, bytes] = {}
latest_annotated_frames: Dict[str, bytes] = {}
latest_side_frames: Dict[str, bytes] = {}
latest_side_annotated_frames: Dict[str, bytes] = {}
latest_frame_times: Dict[str, datetime] = {}
latest_side_frame_times: Dict[str, datetime] = {}


def store_frame(session_id: str, frame_bytes: bytes, annotated_bytes: Optional[bytes] = None):
    latest_frames[session_id] = frame_bytes
    latest_frame_times[session_id] = datetime.now(timezone.utc)
    if annotated_bytes:
        latest_annotated_frames[session_id] = annotated_bytes


def store_side_frame(session_id: str, frame_bytes: bytes, annotated_bytes: Optional[bytes] = None):
    latest_side_frames[session_id] = frame_bytes
    latest_side_frame_times[session_id] = datetime.now(timezone.utc)
    if annotated_bytes:
        latest_side_annotated_frames[session_id] = annotated_bytes


def clear_side_frame(session_id: str):
    latest_side_frames.pop(session_id, None)
    latest_side_annotated_frames.pop(session_id, None)
    latest_side_frame_times.pop(session_id, None)
