"""
Novatrix ärendemottagare (v37).

Så hänger det ihop:

    webbläsare  --POST /submit-->  nginx  --skickar vidare-->  den här appen  --skriver-->  Blob-containern "arenden"

Formuläret (index.html) är en vanlig statisk sida. När någon trycker
"Skicka ärende" skickas fälten hit som en POST. Appen tar emot dem och
lägger ärendet, plus en eventuell bild, som blobar i containern.

Inloggningen mot lagringen sker med VM:ens hanterade identitet
(id-novatrix-app). Det finns ingen nyckel och inget lösenord i koden.

Inställningarna nedan kommer från miljövariabler som systemd-tjänsten
sätter, så samma fil fungerar i vilken miljö som helst utan ändring.
"""

import json
import os
import uuid
from datetime import datetime, timezone

from flask import Flask, request, Response
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings

# --- Inställningar (sätts som miljövariabler av tjänsten) ------------------
STORAGE_ACCOUNT = os.environ["STORAGE_ACCOUNT"]     # t.ex. stnovatrixv37idr
CONTAINER = os.environ.get("CONTAINER", "arenden")
CLIENT_ID = os.environ.get("AZURE_CLIENT_ID")       # id-novatrix-app (user-assigned)
# -------------------------------------------------------------------------

ACCOUNT_URL = f"https://{STORAGE_ACCOUNT}.blob.core.windows.net"

# DefaultAzureCredential hämtar automatiskt en token via VM:ens identitet.
# client_id pekar ut just id-novatrix-app, identiteten som skapades i v35.
credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)
blob_service = BlobServiceClient(account_url=ACCOUNT_URL, credential=credential)
container = blob_service.get_container_client(CONTAINER)

app = Flask(__name__)


@app.post("/submit")
def submit():
    """Tar emot ett inskickat ärende och sparar det i containern."""

    # 1. Läs fälten från formuläret. Namnen måste matcha index.html.
    namn = request.form.get("name", "").strip()
    epost = request.form.get("email", "").strip()
    meddelande = request.form.get("message", "").strip()

    # 2. Ge ärendet ett läsbart och unikt id: "arende-" + datum + tid (UTC)
    #    + en kort slumpdel. Datum och tid först gör att mapparna sorterar
    #    sig i tidsordning. Slumpdelen ser till att två ärenden i samma
    #    sekund inte krockar. Exempel: arende-2026-09-10-111200-1c4d1e
    stampel = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H%M%S")
    arende_id = f"arende-{stampel}-{uuid.uuid4().hex[:6]}"

    # 3. Spara själva ärendet som en JSON-fil, i en egen mapp per ärende.
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
    bilaga = request.files.get("attachment")
    if bilaga and bilaga.filename:
        container.upload_blob(
            name=f"{arende_id}/{bilaga.filename}",
            data=bilaga.stream,
            overwrite=True,
        )

    # 5. Visa en enkel tack-sida med ärende-id:t.
    return Response(
        "<!DOCTYPE html><html lang='sv'><head><meta charset='UTF-8'>"
        "<title>Tack</title></head>"
        "<body style='font-family:Arial;max-width:640px;margin:40px auto'>"
        "<h1>Tack!</h1>"
        f"<p>Ditt ärende är sparat med id <code>{arende_id}</code>.</p>"
        "<p><a href='/'>Tillbaka till formuläret</a></p>"
        "</body></html>",
        mimetype="text/html",
    )


@app.get("/health")
def health():
    """Enkel koll: svarar tjänsten, och läser den sin konfiguration?"""
    return {"status": "ok", "konto": STORAGE_ACCOUNT, "container": CONTAINER}


if __name__ == "__main__":
    # Lyssnar bara på datorn själv (127.0.0.1). nginx står framför och
    # skickar /submit hit. Utifrån når man aldrig den här porten direkt.
    app.run(host="127.0.0.1", port=5000)
