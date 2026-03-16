import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import 'output_screen.dart';

class DraftScreen extends StatefulWidget {
  final Map<String, dynamic> analysisData;

  const DraftScreen({super.key, required this.analysisData});

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  final _nomeController = TextEditingController();
  final _cfController = TextEditingController();
  final _indirizzoController = TextEditingController();
  final _pecController = TextEditingController();
  final _tokenController = TextEditingController();

  String _selectedRoute = 'PREFETTO';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final payload = widget.analysisData['analysis_payload'] as Map<String, dynamic>? ?? {};
    final rec = payload['recommendation'] as Map<String, dynamic>? ?? {};
    final preferred = rec['preferred_route'];
    if (preferred == 'PREFETTO' || preferred == 'GDP') {
      _selectedRoute = preferred as String;
    }
  }

  void _generateDraft() async {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il codice di sblocco (Token d\'acquisto)')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = context.read<ApiService>();
      final deviceToday = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final result = await api.draftAppeal(
        deviceToday: deviceToday,
        route: _selectedRoute,
        analysisPayload: widget.analysisData['analysis_payload'],
        personPlaceholders: {
          'nome': _nomeController.text,
          'cf': _cfController.text,
          'indirizzo': _indirizzoController.text,
          'pec': _pecController.text,
        },
        paymentToken: _tokenController.text,
      );

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OutputScreen(ricorsoText: result['ricorso_text'])),
      );
      
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Errore'),
            content: Text(e.toString()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generazione Ricorso')),
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
                      const Text('Autorità Competente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      DropdownButtonFormField<String>(
                        value: _selectedRoute,
                        items: const [
                          DropdownMenuItem(value: 'PREFETTO', child: Text('Prefetto')),
                          DropdownMenuItem(value: 'GDP', child: Text('Giudice di Pace')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRoute = val);
                        },
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
                      const Text('Dati Ricorrente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome e Cognome')),
                      const SizedBox(height: 8),
                      TextField(controller: _cfController, decoration: const InputDecoration(labelText: 'Codice Fiscale')),
                      const SizedBox(height: 8),
                      TextField(controller: _indirizzoController, decoration: const InputDecoration(labelText: 'Indirizzo Completo')),
                      const SizedBox(height: 8),
                      TextField(controller: _pecController, decoration: const InputDecoration(labelText: 'Email PEC / Email')),
                    ],
                  ),
                ),
              ),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sblocco (Paywall POC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Inserisci il token di pagamento per sbloccare la stesura AI.'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tokenController, 
                        decoration: const InputDecoration(
                          labelText: 'Codice Acquisto Token',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generateDraft,
                icon: const Icon(Icons.lock_open),
                label: const Text('Sblocca e Genera', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }
}
