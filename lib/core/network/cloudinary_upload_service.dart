import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
  });

  final String secureUrl;
  final String publicId;
}

class CloudinaryUploadService {
  CloudinaryUploadService._();

  static final http.Client _client = http.Client();

  static Future<CloudinaryUploadResult> uploadImageBytes({
    required List<int> bytes,
    required String fileName,
    required String folder,
  }) async {
    final cloudName = AppConfig.cloudinaryCloudName.trim();
    final uploadPreset = AppConfig.cloudinaryUploadPreset.trim();
    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw Exception(
        'Configura CLOUDINARY_CLOUD_NAME y CLOUDINARY_UPLOAD_PRESET en env/dart_define.local.json',
      );
    }

    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = payload['secure_url'] as String?;
    final publicId = payload['public_id'] as String?;

    if (response.statusCode >= 400 || secureUrl == null || publicId == null) {
      final detail =
          (payload['error'] as Map<String, dynamic>?)?['message'] as String? ??
          'No se pudo subir la imagen a Cloudinary';
      throw Exception(detail);
    }

    return CloudinaryUploadResult(secureUrl: secureUrl, publicId: publicId);
  }
}
