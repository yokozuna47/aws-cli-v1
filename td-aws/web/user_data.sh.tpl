#!/bin/bash
set -e
dnf install -y python3-pip
pip3 install flask gunicorn requests

mkdir -p /app
cat > /app/web.py << 'PYEOF'
import os, requests as rq
from flask import Flask, request, render_template_string

app = Flask(__name__)
APP_API_URL = "http://" + os.environ["INTERNAL_ALB_DNS"] + "/api/signup"

FORM = """<!doctype html><title>Inscription</title>
<h1>Creer un compte</h1>
{% if msg %}<p style="color:{{color}}">{{msg}}</p>{% endif %}
<form method="post" action="/signup">
  <input name="full_name" placeholder="Nom complet"><br><br>
  <input name="email" type="email" placeholder="Email" required><br><br>
  <input name="password" type="password" placeholder="Mot de passe" required><br><br>
  <button>S inscrire</button>
</form>"""

@app.get("/health")
def health(): return "ok", 200

@app.get("/")
def form(): return render_template_string(FORM, msg=None)

@app.post("/signup")
def signup():
    full_name = request.form.get("full_name","")
    email     = request.form.get("email","")
    password  = request.form.get("password","")
    try:
        r = rq.post(APP_API_URL, json={"email":email,"password":password,"full_name":full_name}, timeout=5)
    except Exception as e:
        return render_template_string(FORM, msg=str(e), color="red")
    if r.status_code == 201:
        return render_template_string(FORM, msg="Compte cree pour "+email, color="green")
    elif r.status_code == 409:
        return render_template_string(FORM, msg="Email deja utilise", color="orange")
    else:
        return render_template_string(FORM, msg=r.json().get("error","Erreur"), color="red")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYEOF

cat > /etc/systemd/system/web.service << EOF
[Unit]
Description=Flask web tier
After=network.target

[Service]
Environment=INTERNAL_ALB_DNS=${internal_alb_dns}
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:80 web:app
WorkingDirectory=/app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable web
systemctl start web
