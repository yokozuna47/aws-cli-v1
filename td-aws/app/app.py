import os
import re
import hashlib
import secrets
import psycopg2
from psycopg2 import errors
from flask import Flask, request, jsonify

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ["DB_HOST"],
    "dbname": os.environ["DB_NAME"],
    "user": os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"],
    "port": 5432,
}

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def hash_password(password):
    # sel aleatoire + sha256 ; format stocke : "sel:hash" (jamais de clair)
    salt = secrets.token_hex(16)
    digest = hashlib.sha256((salt + password).encode()).hexdigest()
    return salt + ":" + digest


@app.get("/health")
def health():
    return "ok", 200


@app.post("/api/signup")
def signup():
    data = request.get_json(force=True)
    email = (data.get("email") or "").strip()
    password = data.get("password") or ""
    full_name = (data.get("full_name") or "").strip()

    # TODO 1 -> validation
    if not email or not EMAIL_RE.match(email):
        return jsonify({"error": "email invalide"}), 400
    if not password:
        return jsonify({"error": "mot de passe requis"}), 400

    # TODO 2 -> hachage (jamais de mot de passe en clair)
    password_hash = hash_password(password)

    # TODO 3 -> INSERT parametre (anti-injection SQL) + gestion du doublon
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO users (email, password_hash, full_name) VALUES (%s, %s, %s)",
                (email, password_hash, full_name),
            )
        conn.commit()
    except errors.UniqueViolation:
        if conn:
            conn.rollback()
        return jsonify({"error": "email deja inscrit"}), 409
    except Exception:
        if conn:
            conn.rollback()
        return jsonify({"error": "erreur serveur"}), 500
    finally:
        if conn:
            conn.close()

    return jsonify({"status": "created", "email": email}), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
