#!/bin/bash
set -e
dnf update -y
dnf install -y python3 python3-pip
pip3 install flask requests
mkdir -p /opt/web
cat > /opt/web/web.py <<'PYEOF'
import os
import requests
from flask import Flask, request, render_template_string

app = Flask(__name__)

# DNS de l'ALB INTERNE (injecte via user_data)
APP_API_URL = "http://" + os.environ["INTERNAL_ALB_DNS"] + "/api/signup"

FORM = """
<!doctype html><title>Inscription</title>
<h1>Creer un compte</h1>
<form method="post" action="/signup">
  <input name="full_name" placeholder="Nom complet"><br>
  <input name="email" type="email" placeholder="Email" required><br>
  <input name="password" type="password" placeholder="Mot de passe" required><br>
  <button type="submit">S'inscrire</button>
</form>
"""

RESULT = """
<!doctype html><title>Resultat</title>
<h1>{{ titre }}</h1>
<p>{{ message }}</p>
<a href="/">Retour</a>
"""


@app.get("/health")
def health():
    return "ok", 200


@app.get("/")
def form():
    return render_template_string(FORM)


@app.post("/signup")
def signup():
    # TODO 1 -> recuperer les champs du formulaire
    payload = {
        "full_name": request.form.get("full_name", ""),
        "email": request.form.get("email", ""),
        "password": request.form.get("password", ""),
    }

    # TODO 2 -> relayer vers l'API interne (avec timeout)
    try:
        r = requests.post(APP_API_URL, json=payload, timeout=5)
    except requests.RequestException:
        return render_template_string(
            RESULT, titre="Service indisponible",
            message="Impossible de joindre l'API."), 502

    # TODO 3 -> message selon le code retour
    if r.status_code == 201:
        return render_template_string(
            RESULT, titre="Compte cree",
            message="Bienvenue " + payload["email"] + " !")
    elif r.status_code == 400:
        return render_template_string(
            RESULT, titre="Donnees invalides",
            message="Verifiez l'email et le mot de passe."), 400
    elif r.status_code == 409:
        return render_template_string(
            RESULT, titre="Email deja inscrit",
            message="Cet email existe deja."), 409
    else:
        return render_template_string(
            RESULT, titre="Erreur",
            message="Une erreur est survenue."), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYEOF
cat > /etc/systemd/system/websvc.service <<'SVCEOF'
[Unit]
Description=Web tier
After=network.target
[Service]
Environment=INTERNAL_ALB_DNS=${internal_alb_dns}
ExecStart=/usr/bin/python3 /opt/web/web.py
Restart=always
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable --now websvc
