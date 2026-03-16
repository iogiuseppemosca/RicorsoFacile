import base64
import json
import os
from openai import AsyncOpenAI
from prompts import VALIDATE_PROMPT, ENVELOPE_EXTRACT_PROMPT, ANALYZE_PROMPT, DRAFT_PROMPT, OCR_TRANSCRIPTION_PROMPT

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

VALIDATION_MODEL = os.getenv("VALIDATION_MODEL", "gpt-4o-mini")
BACKEND_MODEL = os.getenv("BACKEND_MODEL", "gpt-4o-mini")

async def validate_document(text: str) -> dict:
    if len(text) > 4000:
        text = text[:4000]
    
    response = await client.chat.completions.create(
        model=VALIDATION_MODEL,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": VALIDATE_PROMPT},
            {"role": "user", "content": f"Analizza questo estratto:\n\n{text}"}
        ]
    )
    return json.loads(response.choices[0].message.content)

async def extract_text_from_images(images_bytes: list[bytes]) -> str:
    content = [{"type": "text", "text": "Trascrivi il testo di questo verbale."}]
    for img_bytes in images_bytes:
        b64_img = base64.b64encode(img_bytes).decode('utf-8')
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{b64_img}"
            }
        })

    response = await client.chat.completions.create(
        model=VALIDATION_MODEL, # We use the cheaper model for OCR
        messages=[
            {"role": "system", "content": OCR_TRANSCRIPTION_PROMPT},
            {"role": "user", "content": content}
        ]
    )
    return response.choices[0].message.content or ""

async def extract_envelope_dates(images_bytes: list[bytes]) -> dict:
    content = [{"type": "text", "text": "Analizza la busta."}]
    for img_bytes in images_bytes:
        b64_img = base64.b64encode(img_bytes).decode('utf-8')
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{b64_img}"
            }
        })

    response = await client.chat.completions.create(
        model=VALIDATION_MODEL,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": ENVELOPE_EXTRACT_PROMPT},
            {"role": "user", "content": content}
        ]
    )
    return json.loads(response.choices[0].message.content)

async def analyze_ticket(text: str, context: dict) -> dict:
    context_str = json.dumps(context, indent=2)
    response = await client.chat.completions.create(
        model=BACKEND_MODEL,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": ANALYZE_PROMPT},
            {"role": "user", "content": f"Testo verbale:\n{text}\n\nContesto date inserite:\n{context_str}"}
        ]
    )
    return json.loads(response.choices[0].message.content)

async def generate_draft(payload: dict) -> str:
    payload_str = json.dumps(payload, indent=2)
    response = await client.chat.completions.create(
        model=BACKEND_MODEL,
        messages=[
            {"role": "system", "content": DRAFT_PROMPT},
            {"role": "user", "content": f"Genera il ricorso usando i seguenti dati:\n{payload_str}"}
        ]
    )
    return response.choices[0].message.content
