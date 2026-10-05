import json
import os

import azure.functions as func
import requests
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

SIDHUVUD = """<!DOCTYPE html>
<html lang="sv">
<head>
<meta charset="utf-8">
<title>Nordvik Fastigheter - Felanmalan</title>
<style>
  body { font-family: Verdana, sans-serif; background: #1f2e35; color: #e8edf0; margin: 0; }
  header { background: #16222a; padding: 1.2rem 2rem; border-bottom: 3px solid #4fa89b; }
  header h1 { margin: 0; font-size: 1.4rem; letter-spacing: 0.03em; }
  nav a { color: #4fa89b; margin-right: 1.5rem; text-decoration: none; font-weight: bold; }
  main { max-width: 600px; margin: 2rem auto; background: #273a43; padding: 1.5rem 2rem; border-radius: 4px; }
  label { display: block; margin-top: 1rem; font-size: 0.9rem; color: #9fb4bb; }
  input, select, textarea { width: 100%; padding: 0.5rem; margin-top: 0.3rem; border: 1px solid #4fa89b; border-radius: 3px; background: #1f2e35; color: #e8edf0; box-sizing: border-box; }
  button { margin-top: 1.5rem; padding: 0.6rem 1.4rem; background: #4fa89b; color: #16222a; border: none; border-radius: 3px; font-weight: bold; cursor: pointer; }
  .post { border-bottom: 1px solid #4fa89b; padding: 0.8rem 0; }
  .akut { color: #e8a04f; font-weight: bold; }
</style>
</head>
<body>
<header>
  <h1>Nordvik Fastigheter &ndash; Hyresgastportal</h1>
  <nav><a href="/">Ny felanmalan</a><a href="/mina-arenden">Mina anmalningar</a></nav>
</header>
<main>
"""
SIDFOT = "</main></body></html>"


@app.route(route="/", methods=["GET"])
def formular(req: func.HttpRequest) -> func.HttpResponse:
    html = SIDHUVUD + """
<h2>Ny felanmalan</h2>
<form action="/skicka" method="post" enctype="multipart/form-data">
  <label>Hyresgastnummer</label>
  <input type="text" name="hyresgast" required>
  <label>Fastighet/lagenhet</label>
  <input type="text" name="fastighet" required>
  <label>Rubrik</label>
  <input type="text" name="rubrik" required>
  <label>Kategori</label>
  <select name="kategori">
    <option value="ovrigt">Ovrigt</option>
    <option value="varme">Varme</option>
    <option value="vatten">Vatten</option>
    <option value="las">Las</option>
  </select>
  <label>Beskrivning</label>
  <textarea name="beskrivning" rows="4" required></textarea>
  <label>Bild (frivilligt)</label>
  <input type="file" name="bild" accept="image/*">
  <button type="submit">Skicka anmalan</button>
</form>
""" + SIDFOT
    return func.HttpResponse(html, mimetype="text/html")


@app.route(route="skicka", methods=["POST"])
def skicka(req: func.HttpRequest) -> func.HttpResponse:
    arenden_url = os.environ["ARENDEN_URL"]

    data = {
        "rubrik": req.form.get("rubrik", ""),
        "beskrivning": req.form.get("beskrivning", ""),
        "kategori": req.form.get("kategori", "ovrigt"),
        "fastighet": req.form.get("fastighet", ""),
        "hyresgast": req.form.get("hyresgast", ""),
    }

    files = None
    bild = req.files.get("bild")
    if bild is not None and bild.filename:
        files = {"bild": (bild.filename, bild.stream.read())}

    try:
        svar = requests.post(arenden_url, data=data, files=files, timeout=20)
    except requests.RequestException:
        return func.HttpResponse(
            SIDHUVUD + "<h2>Kunde inte skicka anmalan just nu</h2><p>Forsok igen om en liten stund.</p>" + SIDFOT,
            mimetype="text/html",
            status_code=502,
        )

    return func.HttpResponse(SIDHUVUD + svar.text.split("<body>")[-1].split("</body>")[0] + SIDFOT, mimetype="text/html")


@app.route(route="mina-arenden", methods=["GET"])
def mina_arenden(req: func.HttpRequest) -> func.HttpResponse:
    hyresgast = req.params.get("hyresgast", "").strip()

    sok_formular = """
<h2>Mina anmalningar</h2>
<form method="get">
  <label>Ange ditt hyresgastnummer</label>
  <input type="text" name="hyresgast" value="%s" required>
  <button type="submit">Visa</button>
</form>
""" % hyresgast

    if not hyresgast:
        return func.HttpResponse(SIDHUVUD + sok_formular + SIDFOT, mimetype="text/html")

    storage_account = os.environ["STORAGE_ACCOUNT"]
    credential = DefaultAzureCredential()
    blob_service = BlobServiceClient(
        account_url=f"https://{storage_account}.blob.core.windows.net",
        credential=credential,
    )
    container = blob_service.get_container_client("anmalningar")

    traffar = []
    for blob in container.list_blobs():
        if not blob.name.endswith("anmalan.json"):
            continue
        innehall = container.download_blob(blob.name).readall()
        anmalan = json.loads(innehall)
        if anmalan.get("hyresgast") == hyresgast:
            traffar.append(anmalan)

    traffar.sort(key=lambda a: a.get("tidpunkt", ""), reverse=True)

    if traffar:
        rader = ""
        for a in traffar:
            akut_tagg = ' <span class="akut">AKUT</span>' if a.get("akut") else ""
            rader += (
                f'<div class="post"><strong>{a["rubrik"]}</strong>{akut_tagg}<br>'
                f'{a["beskrivning"]}<br>'
                f'<small>{a["fastighet"]} &middot; {a["tidpunkt"]} &middot; status: {a["status"]}</small></div>'
            )
    else:
        rader = "<p>Inga anmalningar hittades for det hyresgastnumret.</p>"

    return func.HttpResponse(SIDHUVUD + sok_formular + rader + SIDFOT, mimetype="text/html")
