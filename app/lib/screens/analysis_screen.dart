import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'draft_screen.dart';

class AnalysisScreen extends StatelessWidget {
  final Map<String, dynamic> analysisData;

  const AnalysisScreen({super.key, required this.analysisData});

  @override
  Widget build(BuildContext context) {
    final payload = analysisData['analysis_payload'] as Map<String, dynamic>;
    final markdownText = analysisData['analysis_markdown'] as String? ?? 'Nessuna analisi dettagliata';
    final recommendation = payload['recommendation'] as Map<String, dynamic>? ?? {};

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Esito Analisi'),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.75),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Sintesi'),
              Tab(text: 'Dettagli'),
              Tab(text: 'Diagnostica'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSintesi(context, recommendation),
            Markdown(data: markdownText),
            _buildDiagnostica(context, payload),
          ],
        ),
        floatingActionButton: recommendation['should_appeal'] != 'NO' 
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DraftScreen(analysisData: analysisData)),
                );
              },
              label: const Text('Genera Ricorso'),
              icon: const Icon(Icons.edit_document),
            )
          : null,
      ),
    );
  }

  Widget _buildSintesi(BuildContext context, Map<String, dynamic> recommendation) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('Conviene ricorrere?'),
            subtitle: Text(
              '${recommendation['should_appeal']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Livello di Rischio'),
            subtitle: Text('${recommendation['risk']}'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Via Consigliata'),
            subtitle: Text('${recommendation['preferred_route']}'),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnostica(BuildContext context, Map<String, dynamic> payload) {
    final extracted = payload['extracted'] as Map<String, dynamic>? ?? {};
    final checks = payload['checks'] as List<dynamic>? ?? [];
    final grounds = payload['grounds'] as List<dynamic>? ?? [];

    final keyLabels = {
      'doc_type': 'Tipo Documento',
      'numero_verbale': 'Numero Verbale',
      'ente_accertatore': 'Ente Accertatore',
      'tipo_infrazione': 'Tipo Infrazione',
      'data_infrazione': 'Data Infrazione',
      'data_notifica': 'Data Notifica',
      'luogo': 'Luogo Infrazione',
      'importo_sanzione': 'Importo Sanzione',
      'punti_decurtati': 'Punti Decurtati',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...extracted.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .map((e) {
          final label = keyLabels[e.key] ?? e.key.replaceAll('_', ' ').toUpperCase();
          return _buildDiagnosticCard(label, e.value.toString());
        }),
        if (checks.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          const Text('VERIFICHE TECNICHE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          ...checks.map((check) {
            Color badgeColor = Colors.grey;
            final esito = check['esito'] ?? 'N/D';
            
            if (esito == 'OK') badgeColor = Colors.green;
            if (esito == 'DA VERIFICARE') badgeColor = Colors.orange;
            if (esito == 'POSSIBILE CRITICITÀ') badgeColor = Colors.red;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(check['nome'] ?? 'Verifica'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(check['spiegazione'] ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      'Evidenza: ${check['evidenza'] ?? 'Nessuna'}', 
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    esito, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)
                  ),
                ),
              ),
            );
          }),
        ],
        if (grounds.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          const Text('ELEMENTI DA APPROFONDIRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          ...grounds.map((ground) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(ground['descrizione'] ?? 'Motivo'),
              subtitle: Text(ground['motivo_verifica'] ?? ''),
            ),
          )),
        ]
      ],
    );
  }

  Widget _buildDiagnosticCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100], 
                borderRadius: BorderRadius.circular(8), 
                border: Border.all(color: Colors.grey[300]!)
              ),
              child: Text(value, style: const TextStyle(fontSize: 15)),
            )
          ],
        ),
      ),
    );
  }
}
