import json
import logging
import os
import urllib.request
from datetime import datetime, timezone

import azure.functions as func
from azure.communication.email import EmailClient
from azure.core.exceptions import ResourceNotFoundError
from azure.data.tables import TableClient
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential

app = func.FunctionApp()

TABELL = "arendelogg"
PARTITION = "arende"
TEAMS_URL = "https://smba.trafficmanager.net/teams/v3/conversations"


def tabellklient() -> TableClient:
    return TableClient(
        endpoint=os.environ["TABLE_ENDPOINT"],
        table_name=TABELL,
        credential=DefaultAzureCredential(),
    )


def hamta_status(tabell: TableClient, arende_id: str) -> str | None:
    try:
        rad = tabell.get_entity(partition_key=PARTITION, row_key=arende_id)
    except ResourceNotFoundError:
        return None
    return rad.get("Status")


def logga(tabell: TableClient, arende: dict, status: str) -> None:
    tabell.upsert_entity({
        "PartitionKey": PARTITION,
        "RowKey": arende["id"],
        "Namn": arende.get("namn", ""),
        "Epost": arende.get("epost", ""),
        "Meddelande": arende.get("meddelande", ""),
        "Skapat": arende.get("skapat", ""),
        "Status": status,
        "Uppdaterad": datetime.now(timezone.utc).isoformat(),
    })


def skicka(till: str, amne: str, text: str) -> None:
    klient = EmailClient.from_connection_string(os.environ["ACS_CONNECTION_STRING"])
    klient.begin_send({
        "senderAddress": os.environ["MEJL_FRAN"],
        "recipients": {"to": [{"address": till}]},
        "content": {"subject": amne, "plainText": text},
    }).result()


def skicka_mejl(arende: dict) -> None:
    skicka(
        os.environ["MEJL_TILL"],
        f"Nytt ärende: {arende['id']}",
        f"Hej {arende.get('namn', '')}!\n\n"
        f"Ärendet har tagits emot.\n\n"
        f"Ärende-id: {arende['id']}\n"
        f"Skapat: {arende.get('skapat', '')}\n\n"
        f"{arende.get('meddelande', '')}\n",
    )


def teams_kort(arende: dict) -> dict:
    return {
        "type": "AdaptiveCard",
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "version": "1.4",
        "body": [
            {
                "type": "TextBlock",
                "size": "Medium",
                "weight": "Bolder",
                "text": "Nytt kundtjänstärende inkommet",
                "color": "Accent",
            },
            {
                "type": "FactSet",
                "facts": [
                    {"title": "ID:", "value": arende["id"]},
                    {"title": "Namn:", "value": arende.get("namn", "")},
                    {"title": "E-post:", "value": arende.get("epost", "")},
                ],
            },
            {"type": "TextBlock", "text": "Meddelande:", "weight": "Bolder", "spacing": "Medium"},
            {"type": "TextBlock", "text": arende.get("meddelande", ""), "wrap": True},
        ],
    }


def skicka_teams(arende: dict) -> None:
    biljett = ManagedIdentityCredential(client_id=os.environ["BOT_CLIENT_ID"]).get_token(
        "https://api.botframework.com/.default"
    )
    inlagg = {
        "isGroup": True,
        "channelData": {
            "channel": {"id": os.environ["TEAMS_KANAL_ID"]},
            "tenant": {"id": os.environ["TENANT_ID"]},
        },
        "activity": {
            "type": "message",
            "attachments": [{
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": teams_kort(arende),
            }],
        },
    }
    anrop = urllib.request.Request(
        TEAMS_URL,
        data=json.dumps(inlagg).encode("utf-8"),
        headers={"Authorization": f"Bearer {biljett.token}", "Content-Type": "application/json"},
        method="POST",
    )
    urllib.request.urlopen(anrop, timeout=10)


# Sökvägen gör att bara arende.json triggar, inte en bifogad bild i samma mapp.
@app.function_name(name="NotifyOnTicket")
@app.blob_trigger(
    arg_name="blob",
    path="arenden/{arendeId}/arende.json",
    connection="NovatrixStorage",
    source=func.BlobSource.EVENT_GRID,
)
def notify_on_ticket(blob: func.InputStream):
    arende = json.loads(blob.read())
    tabell = tabellklient()
    status = hamta_status(tabell, arende["id"])

    if status == "Notifierad":
        logging.info("Ärende %s redan notifierat, hoppar över", arende["id"])
        return

    # Vid ett nytt försök efter ett Teams-fel ska kunden inte få mejlet en gång till.
    if status != "Mejlad":
        logga(tabell, arende, "Mottaget")
        skicka_mejl(arende)
        logga(tabell, arende, "Mejlad")

    skicka_teams(arende)
    logga(tabell, arende, "Notifierad")
    logging.info("Ärende %s loggat, mejlat och postat i Teams", arende["id"])


# Teams hälsar på boten när den installeras. Boten är bara avsändare, så hälsningen kvitteras utan åtgärd.
@app.function_name(name="BotMessages")
@app.route(route="messages", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def bot_messages(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse(status_code=200)
