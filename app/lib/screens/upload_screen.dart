import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import 'analysis_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _pdfFile;
  final List<File> _ticketImages = [];
  final List<File> _envelopeImages = [];
  
  DateTime? _infractionDate;
  DateTime? _notificationDate;
  
  final _comuneController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
        _ticketImages.clear(); // Clear images if PDF is picked
      });
    }
  }

  Future<void> _pickTicketImage() async {
    if (_pdfFile != null) {
      setState(() => _pdfFile = null); // Clear PDF if images are used
    }
    
    final picker = ImagePicker();
    // Using approx 2 Megapixels dimension bounds (e.g. 1920x1080) and 80% quality
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera, // or gallery
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _ticketImages.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _pickImage() async {
    if (_envelopeImages.length >= 2) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _envelopeImages.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isInfraction) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isInfraction) {
          _infractionDate = picked;
        } else {
          _notificationDate = picked;
        }
      });
    }
  }

  void _analyze() async {
    if (_pdfFile == null && _ticketImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un PDF o una foto del verbale')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final deviceToday = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final result = await api.analyzeDocument(
        pdfFile: _pdfFile,
        ticketImages: _ticketImages.isNotEmpty ? _ticketImages : null,
        deviceToday: deviceToday,
        manualInfractionDate: _infractionDate != null ? DateFormat('yyyy-MM-dd').format(_infractionDate!) : null,
        manualNotificationDate: _notificationDate != null ? DateFormat('yyyy-MM-dd').format(_notificationDate!) : null,
        comuneProvincia: _comuneController.text,
        userNotes: _notesController.text,
        envelopeImages: _envelopeImages.isNotEmpty ? _envelopeImages : null,
      );

      if (!mounted) return;
      
      if (result['status'] == 'DOCUMENTO_NON_VALIDO') {
        _showErrorDialog('Documento non valido', result['reason']);
      } else if (result['status'] == 'SERVE_BUSTA') {
        _showErrorDialog('Richiesta Immagini', result['reason']);
      } else if (result['status'] == 'OK') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisScreen(
              analysisData: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Errore', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RicorsoFacile POC')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Aggiungi il verbale (PDF o Foto)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickPdf,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: Text(_pdfFile == null ? 'Carica PDF' : 'PDF Pronto'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('OPPURE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickTicketImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Scatta Foto'),
                            ),
                          ),
                        ],
                      ),
                      if (_ticketImages.isNotEmpty) 
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('${_ticketImages.length} foto acquisite del verbale', style: const TextStyle(color: Colors.green)),
                        ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('2. Foto Busta/Relata (Opzionale, max 2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _envelopeImages.length < 2 ? _pickImage : null,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Aggiungi Foto'),
                          ),
                          const SizedBox(width: 16),
                          Text('${_envelopeImages.length}/2 foto'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('3. Dati Manuali (Opzionali)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _selectDate(context, true),
                              child: Text(_infractionDate == null ? 'Data Infrazione' : DateFormat('dd/MM/yyyy').format(_infractionDate!)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _selectDate(context, false),
                              child: Text(_notificationDate == null ? 'Data Notifica' : DateFormat('dd/MM/yyyy').format(_notificationDate!)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _comuneController,
                        decoration: const InputDecoration(labelText: 'Comune / Provincia'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Note aggiuntive'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _analyze,
                child: const Text('Analizza Verbale', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
    );
  }
}
