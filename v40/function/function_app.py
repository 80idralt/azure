"""
Novatrix ärendemottagning (v40), serverless.

Samma jobb som submit() i v39/app/app.py, men utan VM, nginx och systemd.
Azure startar funktionen när formuläret postar till /api/submit och
stänger ner den igen när det är tyst.
"""

import html
import json
import os
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings

STORAGE_ACCOUNT = os.environ["STORAGE_ACCOUNT"]
CONTAINER = os.environ.get("CONTAINER", "arenden")

# Function Appens egen identitet (system-assigned). Ingen nyckel i koden.
credential = DefaultAzureCredential()
blob_service = BlobServiceClient(
    account_url=f"https://{STORAGE_ACCOUNT}.blob.core.windows.net",
    credential=credential,
)
container = blob_service.get_container_client(CONTAINER)

# ANONYMOUS: formuläret är en publik webbsida och kan inte bära en
# hemlig funktionsnyckel, då skulle nyckeln synas i sidans källkod.
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="submit", methods=["POST"])
def submit(req: func.HttpRequest) -> func.HttpResponse:
    """Tar emot ett inskickat ärende och sparar det i containern."""

    # 1. Läs fälten. Namnen måste matcha index.html.
    namn = req.form.get("name", "").strip()
    epost = req.form.get("email", "").strip()
    meddelande = req.form.get("message", "").strip()

    # 2. Samma id-format som v39: arende-2026-09-30-141200-1c4d1e
    stampel = datetime.now(ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M%S")
    arende_id = f"arende-{stampel}-{uuid.uuid4().hex[:6]}"

    # 3. Spara ärendet som JSON i en egen mapp per ärende.
    arende = {
        "id": arende_id,
        "namn": namn,
        "epost": epost,
        "meddelande": meddelande,
        "skapat": stampel,
    }
    container.upload_blob(
        name=f"{arende_id}/arende.json",
        data=json.dumps(arende, ensure_ascii=False).encode("utf-8"),
        overwrite=True,
        content_settings=ContentSettings(content_type="application/json"),
    )

    # 4. Om en bild bifogades, spara den bredvid i samma mapp.
    bilaga = req.files.get("attachment")
    if bilaga and bilaga.filename:
        container.upload_blob(
            name=f"{arende_id}/{bilaga.filename}",
            data=bilaga.read(),
            overwrite=True,
        )

    # 5. Tack-sida. Tillbaka-länken pekar på sidan besökaren kom ifrån,
    #    alltså containern, så funktionen behöver inte känna till dess adress.
    tillbaka = html.escape(req.headers.get("referer", ""), quote=True)
    sida = (
        "<!DOCTYPE html><html lang='sv'><head><meta charset='UTF-8'>"
        "<title>Tack</title></head>"
        "<body style='font-family:Arial;max-width:640px;margin:40px auto'>"
        "<h1>Tack!</h1>"
        f"<p>Ditt ärende är sparat med id <code>{arende_id}</code>.</p>"
        f"<p><a href='{tillbaka}'>Tillbaka till formuläret</a></p>"
        "</body></html>"
    )
    return func.HttpResponse(sida, mimetype="text/html")
