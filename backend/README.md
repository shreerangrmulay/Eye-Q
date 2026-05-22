# ProctorAI backend

This is the single backend used by the Flutter app and by Render deployment.

It includes:

- Auth routes: `/auth/login`, `/auth/me`
- Session routes: `/session/start`, `/session/{id}/event`, `/session/{id}/submit`, `/session/end`
- AI routes: `/proctor/upload-frame`, `/proctor/update`
- Admin routes: `/admin/sessions`, `/admin/stats`, `/admin/events`, `/admin/stream/{id}`, `/admin/stream/{id}/side`
- WebSockets: `/ws/admin`, `/ws/session/{id}`

Side-camera URLs can be entered as `IP:PORT`; the backend normalizes that to `http://IP:PORT/video`.

The old standalone Python AI files are archived under `legacy_ai/`. The active app entry point is `app.main:app`.

## Local run

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Demo logins:

- Candidate: `candidate` / `student123`
- Admin: `admin` / `admin123`

## Render

Use this folder as the Render root, or use `backend/render.yaml` as the blueprint.

Render startup keeps the camera and AI stack lazy. OpenCV is imported when a
camera route needs it, while Ultralytics and MediaPipe are imported when a
session processes its first AI frame. YOLO writes its config under `/tmp` and
the default model lookup only falls back to the bundled `models/yolov8n.pt`
nano weights unless `YOLO_MODEL_PATH` is explicitly configured.

The Render blueprint pins the lower-memory processing defaults:

- `AI_FRAME_WIDTH=480`
- `AI_YOLO_IMAGE_SIZE=480`
- `AI_YOLO_MIN_INTERVAL_SECONDS=0.5`
