import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class OutputScreen extends StatelessWidget {
  final String ricorsoText;

  const OutputScreen({super.key, required this.ricorsoText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il Tuo Ricorso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ricorsoText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Testo copiato negli appunti!')),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.yellow.shade100,
            width: double.infinity,
            child: const Text(
              'ATTENZIONE: Il ricorso è stato redatto da un\'Intelligenza Artificiale. Verifica sempre i contenuti prima dell\'invio.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Markdown(
              data: ricorsoText,
              selectable: true,
            ),
          ),
        ],
      ),
    );
  }
}
