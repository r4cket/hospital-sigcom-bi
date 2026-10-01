# -*- coding: utf-8 -*-
"""
Vigila /incoming en busca de *.xlsx. Cuando aparece uno y su tamano se
estabiliza, lo carga con load_sigcom.py y lo mueve a /processed (o /failed).
"""
import datetime as dt
import glob
import os
import shutil
import subprocess
import time

INCOMING = "/incoming"
PROCESSED = "/processed"
FAILED = "/failed"
POLL = int(os.environ.get("POLL_SECONDS", "30"))


def stable(path, wait=3):
    try:
        s1 = os.path.getsize(path)
        time.sleep(wait)
        return s1 == os.path.getsize(path)
    except OSError:
        return False


def process(path):
    cmd = ["python", "/app/load_sigcom.py", "--xlsx", path]
    if os.environ.get("STRICT", "0") == "1":
        cmd.append("--strict")
    return subprocess.call(cmd)


def move(path, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = os.path.join(dest_dir, f"{ts}_{os.path.basename(path)}")
    shutil.move(path, dest)
    return dest


def main():
    for d in (INCOMING, PROCESSED, FAILED):
        os.makedirs(d, exist_ok=True)
    print(f"[watch] vigilando {INCOMING}/*.xlsx cada {POLL}s", flush=True)
    while True:
        for f in sorted(glob.glob(os.path.join(INCOMING, "*.xlsx"))):
            name = os.path.basename(f)
            if name.startswith("~$") or name.startswith("."):
                continue
            if not stable(f):
                continue
            print(f"[watch] procesando {name}", flush=True)
            rc = process(f)
            dest = move(f, PROCESSED if rc == 0 else FAILED)
            estado = "OK" if rc == 0 else f"FALLO (rc={rc})"
            print(f"[watch] {estado} -> {dest}", flush=True)
        time.sleep(POLL)


if __name__ == "__main__":
    main()
