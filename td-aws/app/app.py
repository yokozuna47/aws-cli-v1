import os
import re
import hashlib
import secrets
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


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    h = hashlib.sha256((salt + password).encode()).hexdigest()
    return f"{salt}:{h}"


@app.get("/health")
def health():
    return "ok", 200


@app.post("/api/signup")
def signup():
    data = request.get_json(force=True)
    email     = data.get("email", "").strip()
    password  = data.get("password", "")
    full_name = data.get("full_name", "").strip()

    if not email or not EMAIL_RE.match(email):
        return jsonify({"error": "Email invalide"}), 400
    if not password:
        return jsonify({"error": "Mot de passe requis"}), 400

    password_hash = hash_password(password)

    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur  = conn.cursor()
        cur.execute(
            "INSERT INTO users (email, password_hash, full_name) VALUES (%s, %s, %s)",
            (email, password_hash, full_name or None),
        )
        conn.commit()
        cur.close()
        conn.close()
    except pg_errors.UniqueViolation:
        return jsonify({"error": "Email déjà utilisé"}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify({"status": "created", "email": email}), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
