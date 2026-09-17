#!/usr/bin/env python3
"""Prove the FlameUp Cloudinary credentials with one real upload.

Uploads a tiny valid JPEG to cloud dg1xa7q5c through the unsigned preset
'flameup', then fetches the returned secure_url to confirm Cloudinary
actually serves the bytes. Mirrors what the app's CloudinaryService does.
"""
import json
import sys
import urllib.request
import uuid

CLOUD = "dg1xa7q5c"
PRESET = "flameup"

import io

from PIL import Image

# A real 1x1 JPEG, generated on the spot — no hand-rolled hex to get wrong.
_buf = io.BytesIO()
Image.new("RGB", (1, 1), (255, 255, 255)).save(_buf, format="JPEG")
JPEG_1X1 = _buf.getvalue()

# --- build a minimal multipart body ------------------------------------
boundary = "----flameupsmoke" + uuid.uuid4().hex
parts = []
for name, value in [("upload_preset", PRESET), ("folder", "flameup"), ("tags", "flameup,smoke-test")]:
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
    )
parts.append(
    (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
        f'filename="smoke.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'
    ).encode()
    + JPEG_1X1
    + b"\r\n"
)
parts.append(f"--{boundary}--\r\n".encode())
body = b"".join(parts)

req = urllib.request.Request(
    f"https://api.cloudinary.com/v1_1/{CLOUD}/image/upload",
    data=body,
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
)

try:
    with urllib.request.urlopen(req, timeout=30) as res:
        out = json.loads(res.read())
except urllib.error.HTTPError as e:
    print(f"UPLOAD FAILED: {e.code} {e.read().decode()[:300]}")
    sys.exit(1)

url = out.get("secure_url")
public_id = out.get("public_id")
print(f"upload OK -> {url}")
print(f"public_id: {public_id}")

# --- verify Cloudinary actually serves it -------------------------------
with urllib.request.urlopen(url, timeout=30) as res:
    served = res.read()

if served[:2] == b"\xff\xd8" and len(served) > 50:
    print(f"delivery OK: {len(served)} bytes served, JPEG magic present")

    # Clean up the smoke-test asset so the account stays tidy.
    print("(smoke-test asset left in place; delete manually if you want)")
else:
    print(f"DELIVERY MISMATCH: got {len(served)} bytes, magic={served[:2].hex()}")
    sys.exit(1)
