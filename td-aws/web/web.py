import os
import requests
from flask import Flask, request, render_template_string

app = Flask(__name__)

APP_API_URL = f"http://{os.environ['INTERNAL_ALB_DNS']}/api/signup"

FORM = """
<!doctype html>
<title>Inscription</title>
<h1>Créer un compte</h1>
{% if message %}
  <p style="color:{{ color }}">{{ message }}</p>
{% endif %}
<form method="post" action="/signup">
  <input name="full_name" placeholder="Nom complet"><br><br>
  <input name="email" type="email" placeholder="Email" required><br><br>
  <input name="password" type="password" placeholder="Mot de passe" required><br><br>
  <button type="submit">S'inscrire</button>
</form>
"""


@app.get("/health")
def health():
    return "ok", 200


@app.get("/")
def form():
    return render_template_string(FORM, message=None)


@app.post("/signup")
def signup():
    full_name = request.form.get("full_name", "")
    email     = request.form.get("email", "")
    password  = request.form.get("password", "")

    try:
        resp = requests.post(
            APP_API_URL,
            json={"email": email, "password": password, "full_name": full_name},
            timeout=5,
        )
    except requests.exceptions.RequestException as e:
        return render_template_string(FORM, message=f"Erreur réseau : {e}", color="red")

    if resp.status_code == 201:
        return render_template_string(FORM, message=f"Compte créé pour {email} !", color="green")
    elif resp.status_code == 400:
        return render_template_string(FORM, message=resp.json().get("error", "Données invalides"), color="red")
    elif resp.status_code == 409:
        return render_template_string(FORM, message="Email déjà utilisé.", color="orange")
    else:
        return render_template_string(FORM, message=f"Erreur serveur ({resp.status_code})", color="red")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
