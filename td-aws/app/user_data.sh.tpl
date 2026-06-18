#!/bin/bash
set -e
dnf install -y python3-pip
pip3 install flask gunicorn psycopg2-binary

mkdir -p /app
cat > /app/app.py << 'PYEOF'
import os, re, hashlib, secrets
import psycopg2
from psycopg2 import errors as pg_errors
from flask import Flask, request, jsonify

app = Flask(__name__)

DB_CONFIG = {
    "host":     os.environ["DB_HOST"],
    "dbname":   os.environ["DB_NAME"],
    "user":     os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"],
    "port":     5432,
}

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

def hash_password(pw):
    salt = secrets.token_hex(16)
    h = hashlib.sha256((salt + pw).encode()).hexdigest()
    return salt + ":" + h

@app.get("/health")
def health():
    return "ok", 200

@app.post("/api/signup")
def signup():
    data      = request.get_json(force=True)
    email     = data.get("email", "").strip()
    password  = data.get("password", "")
    full_name = data.get("full_name", "").strip()

    if not email or not EMAIL_RE.match(email):
        return jsonify({"error": "Email invalide"}), 400
    if not password:
        return jsonify({"error": "Mot de passe requis"}), 400

    pw_hash = hash_password(password)
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur  = conn.cursor()
        cur.execute(
            "INSERT INTO users (email, password_hash, full_name) VALUES (%s, %s, %s)",
            (email, pw_hash, full_name or None),
        )
        conn.commit(); cur.close(); conn.close()
    except pg_errors.UniqueViolation:
        return jsonify({"error": "Email deja utilise"}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"status": "created", "email": email}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYEOF

# Créer le schéma (avec retry car RDS peut prendre du temps)
cat > /app/init_db.py << 'PYEOF'
import psycopg2, os, time
for _ in range(15):
    try:
        conn = psycopg2.connect(
            host=os.environ["DB_HOST"], dbname=os.environ["DB_NAME"],
            user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"])
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id            SERIAL PRIMARY KEY,
                email         VARCHAR(255) NOT NULL UNIQUE,
                password_hash VARCHAR(255),
                full_name     VARCHAR(255),
                created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
            )
        """)
        conn.commit(); conn.close()
        print("Schema OK")
        break
    except Exception as e:
        print("DB not ready:", e)
        time.sleep(15)
PYEOF

export DB_HOST="${db_host}"
export DB_NAME="${db_name}"
export DB_USER="${db_user}"
export DB_PASSWORD="${db_password}"
python3 /app/init_db.py

cat > /etc/systemd/system/app.service << EOF
[Unit]
Description=Flask API app tier
After=network.target

[Service]
Environment=DB_HOST=${db_host}
Environment=DB_NAME=${db_name}
Environment=DB_USER=${db_user}
Environment=DB_PASSWORD=${db_password}
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:80 app:app
WorkingDirectory=/app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app
systemctl start app
