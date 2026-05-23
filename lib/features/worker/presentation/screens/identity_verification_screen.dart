import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _idPhoto;
  File? _facePhoto;
  bool _isLoading = false;
  int _currentStep = 1; // 1: Carnet, 2: Rostro

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      'Verificación de Identidad',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                const SizedBox(height: 20),
                // Progress indicator
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentStep >= 1
                              ? AppTheme.colorPrimary
                              : AppTheme.colorMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentStep >= 2
                              ? AppTheme.colorPrimary
                              : AppTheme.colorMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Paso $_currentStep de 2',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.colorMuted),
                ),
                const SizedBox(height: 40),
                if (_currentStep == 1) _buildIdCardStep(),
                if (_currentStep == 2) _buildFacePhotoStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdCardStep() {
    return Expanded(
      child: Column(
        children: [
          const Icon(Icons.credit_card, size: 80, color: AppTheme.colorPrimary),
          const SizedBox(height: 24),
          Text(
            'Foto de tu Carnet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Encuadra tu carnet de identidad en el rectángulo',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.colorPrimary, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.3),
              ),
              child: _idPhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_idPhoto!, fit: BoxFit.contain),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 60,
                          color: AppTheme.colorMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Toca para tomar foto',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.colorMuted),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
          ChambaPrimaryButton(
            label: _idPhoto != null ? 'Continuar' : 'Tomar foto',
            onPressed: _isLoading
                ? null
                : () async {
                    if (_idPhoto != null) {
                      setState(() => _currentStep = 2);
                    } else {
                      await _captureIdPhoto();
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildFacePhotoStep() {
    return Expanded(
      child: Column(
        children: [
          const Icon(Icons.face, size: 80, color: AppTheme.colorPrimary),
          const SizedBox(height: 24),
          Text(
            'Foto de tu Rostro',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Toma una selfie clara de tu rostro',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.colorPrimary, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.1),
              ),
              child: _facePhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_facePhoto!, fit: BoxFit.contain),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 60,
                          color: AppTheme.colorMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Toca para tomar selfie',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.colorMuted),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _currentStep = 1);
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white),
                  ),
                  child: Text(
                    'Atrás',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ChambaPrimaryButton(
                  label: _facePhoto != null ? 'Finalizar' : 'Tomar selfie',
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_facePhoto != null) {
                            await _submitVerification();
                          } else {
                            await _captureFacePhoto();
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _captureIdPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _idPhoto = File(photo.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al tomar foto del carnet')),
        );
      }
    }
  }

  Future<void> _captureFacePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _facePhoto = File(photo.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al tomar selfie')));
      }
    }
  }

  Future<void> _submitVerification() async {
    if (_idPhoto == null || _facePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor toma ambas fotos')),
      );
      return;
    }

    final currentUser = SessionStore.currentUser;
    if (currentUser == null || currentUser.type != 'worker') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontro sesion de trabajador')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final idBytes = await _idPhoto!.readAsBytes();
      final faceBytes = await _facePhoto!.readAsBytes();
      final idPhotoDataUri = 'data:image/jpeg;base64,${base64Encode(idBytes)}';
      final facePhotoDataUri =
          'data:image/jpeg;base64,${base64Encode(faceBytes)}';

      final response = await MobileBackendService.instance
          .submitWorkerVerification(
            workerUserId: currentUser.id,
            idPhotoBase64: idPhotoDataUri,
            facePhotoBase64: facePhotoDataUri,
          );

      final userJson = response['user'];
      if (userJson is Map<String, dynamic>) {
        await SessionStore.setCurrentUser(SessionUser.fromJson(userJson));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verificacion enviada correctamente')),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const MainShellScreen(role: 'worker'),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar verificacion: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

