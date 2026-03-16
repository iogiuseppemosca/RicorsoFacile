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
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Sintesi'),
              Tab(text: 'Dettagli'),
              Tab(text: 'JSON Debug'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSintesi(context, recommendation),
            Markdown(data: markdownText),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(const JsonEncoder.withIndent('  ').convert(payload)),
            ),
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
}
