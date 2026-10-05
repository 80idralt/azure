import azure.functions as func
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import requests
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

AKUTA_KATEGORIER = {"varme", "vatten", "las"}


@app.route(route="arenden", methods=["POST"])
def arenden(req: func.HttpRequest) -> func.HttpResponse:
    rubrik = req.form.get("rubrik", "").strip()
    beskrivning = req.form.get("beskrivning", "").strip()
    kategori = req.form.get("kategori", "ovrigt").strip().lower()
    fastighet = req.form.get("fastighet", "").strip()
    hyresgast = req.form.get("hyresgast", "").strip()
    bild = req.files.get("bild")

    if not rubrik or not beskrivning or not hyresgast:
        return func.HttpResponse("Rubrik, beskrivning och hyresgästnummer måste fyllas i.", status_code=400)

    nu = datetime.now(timezone.utc)
    tidpunkt = nu.strftime("%Y-%m-%d:%H:%M")
    unikt_id = f"fa-{nu.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:6]}"
    akut = kategori in AKUTA_KATEGORIER

    anmalan = {
        "id": unikt_id,
        "rubrik": rubrik,
        "beskrivning": beskrivning,
        "kategori": kategori,
        "akut": akut,
        "fastighet": fastighet,
        "hyresgast": hyresgast,
        "tidpunkt": tidpunkt,
        "status": "ny",
    }

    storage_account = os.environ["STORAGE_ACCOUNT"]
    credential = DefaultAzureCredential()
    blob_service = BlobServiceClient(
        account_url=f"https://{storage_account}.blob.core.windows.net",
        credential=credential,
    )
    container = blob_service.get_container_client("anmalningar")

    container.upload_blob(f"{unikt_id}/anmalan.json", json.dumps(anmalan, ensure_ascii=False, indent=2))

    if bild is not None and bild.filename:
        anmalan["bild"] = bild.filename
        container.upload_blob(f"{unikt_id}/{bild.filename}", bild.stream.read())

    flow_url = os.environ.get("FLOW_URL")
    if flow_url:
        try:
            requests.post(flow_url, json=anmalan, timeout=10)
        except requests.RequestException as fel:
            logging.warning("Kunde inte nå Power Automate-flödet: %s", fel)

    return func.HttpResponse(
        f"<!DOCTYPE html><html lang='sv'><body>"
        f"<h1>Tack för din anmälan</h1>"
        f"<p>Ditt ärende är sparat med id <code>{unikt_id}</code>, mottaget {tidpunkt}.</p>"
        f"</body></html>",
        mimetype="text/html",
    )
