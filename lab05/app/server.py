import os, time, threading
from flask import Flask

app = Flask(__name__)
START = time.time()
STARTUP_DELAY = int(os.getenv("STARTUP_DELAY", "0"))
FAIL_AFTER = int(os.getenv("FAIL_AFTER", "0"))  # 0 = nunca falla healthz
READY_FILE = "/tmp/ready"

# Simula arranque lento: crea READY_FILE hasta después de STARTUP_DELAY
def init():
  time.sleep(STARTUP_DELAY)
  with open(READY_FILE, "w") as f:
    f.write("ready")

threading.Thread(target=init, daemon=True).start()

@app.get("/")
def index():
  return f"pod={os.getenv('HOSTNAME','unknown')} uptime={int(time.time()-START)}s\n", 200

@app.get("/readyz")
def readyz():
  try:
    open(READY_FILE, "r").close()
    return "ready\n", 200
  except:
    return "not-ready\n", 503

@app.get("/healthz")
def healthz():
  if FAIL_AFTER > 0 and (time.time() - START) > FAIL_AFTER:
    return "unhealthy\n", 500
  return "ok\n", 200

if __name__ == "__main__":
  app.run(host="0.0.0.0", port=8080)
