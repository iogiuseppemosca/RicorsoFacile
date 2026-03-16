import os
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, Form, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from fastapi.responses import FileResponse

load_dotenv()

from pdf_extract import extract_text_from_pdf
from openai_client import validate_document, extract_envelope_dates, analyze_ticket, generate_draft, extract_text_from_images

app = FastAPI(title="RicorsoFacile API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi import Request
from fastapi.responses import JSONResponse
import logging

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logging.error(f"Unhandled error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "status": "ERRORE_INTERNO",
            "reason": "Si è verificato un errore inaspettato durante l'elaborazione del documento.",
            "details": str(exc)
        }
    )

POC_PAYMENT_TOKEN = os.getenv("POC_PAYMENT_TOKEN", "letmein-ricorso")

class DraftRequest(BaseModel):
    device_today: str
    route: str
    analysis_payload: dict
    person_placeholders: dict

@app.post("/api/analyze")
async def analyze_document(
    device_today: str = Form(...),
    pdf_file: Optional[UploadFile] = File(None),
    ticket_images: Optional[List[UploadFile]] = File(None),
    manual_infraction_date: Optional[str] = Form(None),
    manual_notification_date: Optional[str] = Form(None),
    comune_provincia: Optional[str] = Form(None),
    user_notes: Optional[str] = Form(None),
    envelope_images: Optional[List[UploadFile]] = File(None)
):
    extracted_text = ""
    
    if pdf_file and pdf_file.filename:
        pdf_bytes = await pdf_file.read()
        extracted_text = extract_text_from_pdf(pdf_bytes)
        
    if len(extracted_text.strip()) < 100:
        if ticket_images and len(ticket_images) > 0 and ticket_images[0].filename:
            # Utente ha caricato foto del verbale
            images_bytes = [await img.read() for img in ticket_images if img.filename]
            if images_bytes:
                extracted_text = await extract_text_from_images(images_bytes)
    
    if len(extracted_text.strip()) < 100:
        if not envelope_images:
            return {
                "status": "SERVE_BUSTA",
                "reason": "Documento poco leggibile o assente, caricare PDF o Foto chiare del verbale.",
                "device_today": device_today
            }
    
    lower_text = extracted_text.lower()
    invalid_keywords = ['fattura', 'curriculum', 'privacy policy']
    for kw in invalid_keywords:
        if kw in lower_text:
            return {
                "status": "DOCUMENTO_NON_VALIDO",
                "reason": f"Trovata parola incompatibile ({kw})",
                "device_today": device_today
            }
            
    validation_res = await validate_document(extracted_text)
    if not validation_res.get("is_valid_italian_cds_ticket", False) or validation_res.get("confidence", 0) < 0.70:
        return {
            "status": "DOCUMENTO_NON_VALIDO",
            "reason": validation_res.get("reason", "Il documento non sembra un verbale valido"),
            "device_today": device_today
        }
    
    envelope_data = {}
    if envelope_images:
        images_bytes = [await img.read() for img in envelope_images if img.filename]
        if images_bytes:
            envelope_data = await extract_envelope_dates(images_bytes)
    
    context = {
        "device_today": device_today,
        "manual_infraction_date": manual_infraction_date,
        "manual_notification_date": manual_notification_date,
        "comune_provincia": comune_provincia,
        "user_notes": user_notes,
        "envelope_data": envelope_data
    }
    
    analysis_json = await analyze_ticket(extracted_text, context)
    
    rec = analysis_json.get('recommendation', {})
    
    md_summary = f"## Stato Documentale: {rec.get('stato_documentale', 'N/A')}\n\n"
    md_summary += f"**Sintesi:** {rec.get('sintesi_tecnica', '')}\n\n"
    md_summary += f"**Elementi rilevanti per ricorso:** {rec.get('elementi_rilevanti', '')}\n\n"
    
    grounds = analysis_json.get('grounds', [])
    if grounds:
        md_summary += "### Elementi da approfondire:\n"
        for g in grounds:
            desc = g.get('descrizione', g) if isinstance(g, dict) else g
            md_summary += f"- {desc}\n"
            
    md_summary += f"\n*{rec.get('precisazione', '')}*"
    
    return {
        "status": "OK",
        "device_today": device_today,
        "analysis_payload": analysis_json,
        "analysis_markdown": md_summary
    }

@app.post("/api/draft")
async def draft_appeal(
    request: DraftRequest,
    x_poc_payment_token: str = Header(None)
):
    if x_poc_payment_token != POC_PAYMENT_TOKEN:
        raise HTTPException(status_code=402, detail="Pagamento necessario per generare il ricorso.")
        
    draft_md = await generate_draft(request.model_dump())
    
    return {
        "status": "OK",
        "ricorso_text": draft_md
    }

from fastapi.responses import FileResponse

@app.get("/")
async def serve_index():
    return FileResponse("static/index.html")

@app.get("/style.css")
async def serve_css():
    return FileResponse("static/style.css")

@app.get("/script.js")
async def serve_js():
    return FileResponse("static/script.js")
