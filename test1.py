import cv2
import time
from ultralytics import YOLO

# ===================== CAMERAS =====================
front_cam = cv2.VideoCapture(0)  # Laptop webcam
# SIDE_CAM_URL = "http://192.168.88.158:8080/video"
SIDE_CAM_URL = "http://10.117.96.233:8080/video"

side_cam = cv2.VideoCapture(SIDE_CAM_URL)

# ===================== MODELS =====================
yolo = YOLO("yolov8n.pt")

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# ===================== VARIABLES =====================
face_missing_time = 0
CHEAT_THRESHOLD = 5
last_time = time.time()

# ===================== FUNCTIONS =====================
def detect_face(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(
        gray, scaleFactor=1.3, minNeighbors=5
    )
    return len(faces) > 0

def detect_phone(frame):
    results = yolo(frame, conf=0.4, verbose=False)
    for r in results:
        for box in r.boxes:
            if yolo.names[int(box.cls[0])] == "cell phone":
                return True
    return False

# ===================== MAIN LOOP =====================
while True:
    ret1, front = front_cam.read()
    ret2, side = side_cam.read()

    if not ret1 or not ret2:
        print("Camera stream error")
        break

    now = time.time()
    dt = now - last_time
    last_time = now
    cheat_score = 0

    # ---------- FRONT VIEW ----------
    if not detect_face(front):
        face_missing_time += dt
        if face_missing_time > 3:
            cheat_score += 2
            cv2.putText(front, "FACE NOT DETECTED", (20,40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0,0,255), 2)
    else:
        face_missing_time = 0

    # ---------- SIDE VIEW ----------
    if detect_phone(side):
        cheat_score += 5
        cv2.putText(side, "PHONE DETECTED", (20,40),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0,0,255), 2)

    # ---------- DECISION ----------
    status = "CHEATING DETECTED" if cheat_score >= CHEAT_THRESHOLD else "NORMAL"
    color = (0,0,255) if cheat_score >= CHEAT_THRESHOLD else (0,255,0)

    cv2.putText(front, status, (20,80),
                cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)

    cv2.imshow("Front Camera (Laptop)", front)
    cv2.imshow("Side Camera (Phone)", side)

    if cv2.waitKey(1) & 0xFF == 27:
        break

# ===================== CLEANUP =====================
front_cam.release()
side_cam.release()
cv2.destroyAllWindows()
