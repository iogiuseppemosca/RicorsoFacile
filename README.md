# RicorsoFacile POC (Proof of Concept)

Prototipo per l'analisi automatizzata di verbali del Codice della Strada italiano e redazione automatica di ricorsi amministrativi (Prefetto/GdP) tramite Intelligenza Artificiale (OpenAI Vision & GPT).

---

## 🚀 Aggiornamento: Azure Cloud Deployment

Il Backend FastAPI è configurato e **attualmente ospitato su Azure App Service** (Linux Docker). 
Tutte le API rispondono all'URL di produzione:
`https://api-ricorsofacile.azurewebsites.net`

---

## 📂 Struttura del Progetto

- `backend/` 🐍 - Server FastAPI (Python 3.11). Analisi PDF, OCR immagini e orchestrazione con OpenAI.
- `app/` 📱 - Frontend Flutter. Layout moderno, form guidato multi-step e paywall simulato.

---

## ⚙️ Come Avviare in Locale

### 1. Backend (FastAPI)
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# ⚠️ Importante: Inserire la propria OPENAI_API_KEY nel file .env
uvicorn main:app --reload
```

### 2. Frontend (Flutter)
I canali di comunicazione dialogano di default con il server cloud su Azure per facilitare i test dell'App. Se si desidera testare modifiche locali al backend, aggiornare l'URL del client HTTP nell'App o configurare i DNS.
```bash
cd app
flutter pub get
flutter run
```

---

## 🛠️ Architettura e Note Tecniche

- **Ingegneria dei Prompt (`prompts.py`):** Struttura rigida di analisi JSON per supportare la validazione e la formattazione dei dati estratti (Assunzione di responsabilità, date, articoli violenti).
- **Paywall POC / Middleware:** 
  - La redazione del ricorso (`POST /api/draft`) richiede un token di bypass del pagamento.
  - Header: `X-POC-PAYMENT-TOKEN`
  - Valore standard accettato nel POC: `letmein-ricorso` (ottimizzabile da ENV var).
- **Gestione Errori Totale:** Ogni eccezione non gestita (crash) viene catturata da un Global Exception Handler che risponde in formato JSON `{ "status": "ERRORE_INTERNO" }` anziché in crash di sistema.

---

## 🐳 Docker & Azure Deploy (Guida Rapida)

Per ricaricare modifiche:
```bash
cd backend
# 1. Build & Push ACR
az acr build --registry ricorsofacilerego1234 --image ricorso-api:v1 .
# 2. Restart App Service
az webapp restart --name api-ricorsofacile --resource-group RicorsoFacile-RG
```
