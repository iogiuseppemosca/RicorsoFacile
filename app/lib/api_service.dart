import 'dart:io';
import 'package:dio/dio.dart';

class ApiService {
  static String get _baseUrl {
    return 'https://api-ricorsofacile.azurewebsites.net/api';
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    validateStatus: (status) => true, // To handle 402 manually
  ));

  Future<Map<String, dynamic>> analyzeDocument({
    File? pdfFile,
    List<File>? ticketImages,
    required String deviceToday,
    String? manualInfractionDate,
    String? manualNotificationDate,
    String? comuneProvincia,
    String? userNotes,
    List<File>? envelopeImages,
  }) async {
    final formData = FormData.fromMap({
      'device_today': deviceToday,
      if (manualInfractionDate != null && manualInfractionDate.isNotEmpty)
        'manual_infraction_date': manualInfractionDate,
      if (manualNotificationDate != null && manualNotificationDate.isNotEmpty)
        'manual_notification_date': manualNotificationDate,
      if (comuneProvincia != null && comuneProvincia.isNotEmpty)
        'comune_provincia': comuneProvincia,
      if (userNotes != null && userNotes.isNotEmpty)
        'user_notes': userNotes,
    });
    
    if (pdfFile != null) {
      formData.files.add(MapEntry('pdf_file', await MultipartFile.fromFile(pdfFile.path, filename: 'ticket.pdf')));
    }

    if (ticketImages != null && ticketImages.isNotEmpty) {
      for (var img in ticketImages) {
        formData.files.add(MapEntry(
            'ticket_images',
            await MultipartFile.fromFile(img.path, filename: img.path.split('/').last)));
      }
    }

    if (envelopeImages != null && envelopeImages.isNotEmpty) {
      for (var img in envelopeImages) {
        formData.files.add(MapEntry(
            'envelope_images',
            await MultipartFile.fromFile(img.path, filename: img.path.split('/').last)));
      }
    }

    try {
      final response = await _dio.post('/analyze', data: formData);
      if (response.statusCode != 200) {
        throw Exception('Analisi fallita: ${response.statusCode} ${response.data}');
      }
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Il server impiega troppo tempo a rispondere. Riprova più tardi.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Impossibile connettersi al server. Verifica la tua connessione e riprova.');
      }
      throw Exception('Rete o server non disponibili. Errore generico: ${e.message}');
    } catch (e) {
      throw Exception('Errore imprevisto durante l\'analisi: $e');
    }
  }

  Future<Map<String, dynamic>> draftAppeal({
    required String deviceToday,
    required String route,
    required Map<String, dynamic> analysisPayload,
    required Map<String, dynamic> personPlaceholders,
    required String paymentToken,
  }) async {
    try {
      final response = await _dio.post(
        '/draft',
        options: Options(headers: {'X-POC-PAYMENT-TOKEN': paymentToken}),
        data: {
          'device_today': deviceToday,
          'route': route,
          'analysis_payload': analysisPayload,
          'person_placeholders': personPlaceholders,
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Generazione bozza fallita: ${response.statusCode}');
      }
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        throw Exception('Payment Required');
      }
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Il server impiega troppo tempo a rispondere. Riprova più tardi.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Impossibile connettersi al server. Verifica la tua connessione e riprova.');
      }
      throw Exception('Rete o server non disponibili. Errore generico: ${e.message}');
    } catch (e) {
      throw Exception('Errore imprevisto durante la generazione: $e');
    }
  }
}
