// State Management
let currentView = 'upload';
let analysisData = null;

const apiHost = 'https://api-ricorsofacile.azurewebsites.net/api';

// File state placeholders
let pdfFile = null;
let ticketImages = [];
let envelopeImages = [];

// DOM Elements
const views = {
    upload: document.getElementById('view-upload'),
    analysis: document.getElementById('view-analysis'),
    draft: document.getElementById('view-draft')
};

const loadingOverlay = document.getElementById('loading-overlay');
const loadingText = document.getElementById('loading-text');

// File Upload Event Listeners
document.getElementById('pdf_file').addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        pdfFile = e.target.files[0];
        document.getElementById('pdf-status').style.display = 'block';
        document.getElementById('pdf-status').innerText = `📄 PDF Caricato: ${pdfFile.name}`;
        ticketImages = []; // Reset images if PDF is chosen
        document.getElementById('ticket-images-status').style.display = 'none';
    }
});

document.getElementById('ticket_images').addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        ticketImages = Array.from(e.target.files);
        document.getElementById('ticket-images-status').style.display = 'block';
        document.getElementById('ticket-images-status').innerText = `📸 ${ticketImages.length} Foto Verbale Acquisite`;
        pdfFile = null; // Reset PDF if images are chosen
        document.getElementById('pdf-status').style.display = 'none';
    }
});

document.getElementById('envelope_images').addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        // Limit to 2 max
        envelopeImages = Array.from(e.target.files).slice(0, 2);
        document.getElementById('envelope-count').innerText = `${envelopeImages.length}/2 foto aggiungere`;
    }
});

function switchView(viewName) {
    Object.keys(views).forEach(key => {
        views[key].classList.toggle('active', key === viewName);
    });
    // Update Title bar based on view
    const title = document.getElementById('app_title');
    if (viewName === 'upload') title.innerText = 'RicorsoFacile POC';
    if (viewName === 'analysis') title.innerText = 'Esito Analisi';
    if (viewName === 'draft') title.innerText = 'Generazione Ricorso';
}

function switchTab(tabName) {
    document.querySelectorAll('.tab-item').forEach(item => {
        item.classList.toggle('active', item.innerText.toLowerCase() === tabName);
    });
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `tab-${tabName}`);
    });
}

// API CALLS
async function analyzeDocument() {
    if (!pdfFile && ticketImages.length === 0) {
        alert('Seleziona un PDF o una foto del verbale per procedere');
        return;
    }

    loadingOverlay.style.display = 'flex';
    loadingText.innerText = 'Analisi del verbale in corso...';

    const formData = new FormData();
    const today = new Date().toISOString().split('T')[0];
    formData.append('device_today', today);

    if (pdfFile) formData.append('pdf_file', pdfFile);
    
    ticketImages.forEach(img => {
        formData.append('ticket_images', img);
    });

    envelopeImages.forEach(img => {
        formData.append('envelope_images', img);
    });

    const infraction = document.getElementById('manual_infraction_date').value;
    const notification = document.getElementById('manual_notification_date').value;
    const comune = document.getElementById('comune_provincia').value;
    const notes = document.getElementById('user_notes').value;

    if (infraction) formData.append('manual_infraction_date', infraction);
    if (notification) formData.append('manual_notification_date', notification);
    if (comune) formData.append('comune_provincia', comune);
    if (notes) formData.append('user_notes', notes);

    try {
        const response = await fetch(`${apiHost}/analyze`, {
            method: 'POST',
            body: formData
        });

        const data = await response.json();
        
        if (data.status === 'OK') {
            analysisData = data;
            renderAnalysis(data);
            switchView('analysis');
        } else {
            alert(`Esito: ${data.status}\nMotivo: ${data.reason}`);
        }
    } catch (error) {
        alert(`Errore di connessione: ${error.message}`);
    } finally {
        loadingOverlay.style.display = 'none';
    }
}

function renderAnalysis(data) {
    const payload = data.analysis_payload;
    const recommendation = payload.recommendation || {};

    // Tab 1 Sintesi
    document.getElementById('res-should-appeal').innerText = recommendation.should_appeal || 'N/D';
    document.getElementById('res-risk').innerText = recommendation.risk || 'N/D';
    document.getElementById('res-preferred-route').innerText = recommendation.preferred_route || 'N/D';

    // Disable generate button if appeal is explicitly NO
    document.getElementById('draft-fab').style.display = recommendation.should_appeal === 'NO' ? 'none' : 'flex';

    // Tab 2 Markdown
    const markdown = data.analysis_markdown || 'Nessuna specifica di dettaglio disponibile.';
    document.getElementById('res-markdown').innerHTML = parseMarkdown(markdown);

    // Tab 3 Diagnostica
    renderDiagnostics(payload);
}

function renderDiagnostics(payload) {
    const container = document.getElementById('res-diagnostics');
    container.innerHTML = ''; // Clear previous

    const extracted = payload.extracted || {};
    
    // Mappa per tradurre chiavi in etichette utente
    const keyLabels = {
        'doc_type': 'Tipo Documento',
        'verbale_number': 'Numero Verbale',
        'infraction_date': 'Data Infrazione',
        'notification_date': 'Data Notifica',
        'comune': 'Comune / Autorità',
        'luogo': 'Luogo Infrazione',
        'descrizione_infrazione': 'Descrizione Infrazione',
        'violazione_articolo': 'Articolo Violato',
        'importo_sanzione': 'Importo Sanzione',
        'punti_decurtati': 'Punti Decurtati',
        'veicolo': 'Veicolo / Targa'
    };

    // Sezione Principale: Dati Estratti
    for (const [key, value] of Object.entries(extracted)) {
        // Ignora liste o oggetti annidati per ora
        if (typeof value === 'object' && value !== null) continue;
        if (value === null || value === undefined || value === '') continue;

        const label = keyLabels[key] || key.replace(/_/g, ' ').toUpperCase();
        
        const card = document.createElement('div');
        card.className = 'diagnostic-card';
        card.innerHTML = `
            <div class="diagnostic-title">${label}</div>
            <div class="diagnostic-box">${value}</div>
        `;
        container.appendChild(card);
    }

    // Sezione Dati Mancanti (se presenti)
    const recommendation = payload.recommendation || {};
    if (recommendation.missing_data && recommendation.missing_data.length > 0) {
        const card = document.createElement('div');
        card.className = 'diagnostic-card';
        card.innerHTML = `
            <div class="diagnostic-title" style="color: #ef4444;">Dati Mancanti / Richiesti</div>
            <div class="diagnostic-box">${recommendation.missing_data.join(', ')}</div>
        `;
        container.appendChild(card);
    }
}

function showDraftView() {
    switchView('draft');
}

async function generateAppeal() {
    const token = document.getElementById('payment_token').value;
    if (!token) {
        alert('Inserisci il Token POC per simulare il pagamento.');
        return;
    }

    loadingOverlay.style.display = 'flex';
    loadingText.innerText = 'Generazione della bozza di ricorso...';

    const payload = analysisData.analysis_payload;
    const rec = payload.recommendation || {};

    const body = {
        device_today: new Date().toISOString().split('T')[0],
        route: rec.preferred_route === 'PREFETTO' || rec.preferred_route === 'GDP' ? rec.preferred_route : 'PREFETTO',
        analysis_payload: payload,
        person_placeholders: {
            nome: document.getElementById('draft-nome').value || 'Dato Mancante',
            cf: document.getElementById('draft-cf').value || 'Dato Mancante',
            indirizzo: document.getElementById('draft-indirizzo').value || 'Dato Mancante',
            pec: document.getElementById('draft-pec').value || 'Dato Mancante'
        }
    };

    try {
        const response = await fetch(`${apiHost}/draft`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-POC-PAYMENT-TOKEN': token
            },
            body: JSON.stringify(body)
        });

        if (response.status === 402) {
            alert('Errore 402: Il Token inserito non è valido o simulazione pagamento fallita.');
            return;
        }

        const data = await response.json();
        
        if (data.status === 'OK') {
            document.getElementById('draft-result').style.display = 'block';
            document.getElementById('res-draft-text').innerText = data.ricorso_text;
            document.getElementById('generate-btn').scrollIntoView({ behavior: 'smooth' });
        } else {
            alert(`Errore: ${data.message || 'Generazione Fallita'}`);
        }

    } catch (error) {
        alert(`Errore di connessione: ${error.message}`);
    } finally {
        loadingOverlay.style.display = 'none';
    }
}

// Simple Markdown Formatter for visual enhancement
function parseMarkdown(text) {
    if (!text) return "";
    return text
        .replace(/## (.*?)\n/g, '<h4 style="margin: 16px 0 8px 0; color: #004C8C;">$1</h4>')
        .replace(/### (.*?)\n/g, '<h5 style="margin: 12px 0 6px 0;">$1</h5>')
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/^- (.*?)$/gm, '<li>$1</li>')
        .replace(/<li>(.*?)<\/li>/g, '<ul style="margin-left: 16px; margin-bottom: 8px;"><li>$1</li></ul>');
}
