import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../state/auth_dependencies.dart';
import '../../../shell/presentation/screens/main_shell_screen.dart';

class GoogleAccountTypeScreen extends StatefulWidget {
  const GoogleAccountTypeScreen({
    super.key,
    required this.googleData,
  });

  final Map<String, dynamic> googleData;

  @override
  State<GoogleAccountTypeScreen> createState() => _GoogleAccountTypeScreenState();
}

class _GoogleAccountTypeScreenState extends State<GoogleAccountTypeScreen> {
  bool _isLoading = false;

  Future<void> _selectType(String type) async {
    setState(() => _isLoading = true);
    try {
      final result = await MobileBackendService.instance.registerWithGoogle(
        email: widget.googleData['email'] ?? '',
        firstName: widget.googleData['firstName'] ?? 'Usuario',
        lastName: widget.googleData['lastName'],
        googleId: widget.googleData['googleId'] ?? '',
        type: type,
      );

      final userData = result['user'] as Map<String, dynamic>;

      await SessionStore.setCurrentUser(SessionUser.fromJson(userData));

      if (!mounted) return;
      
      if (type == 'worker') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShellScreen(role: 'worker')),
          (r) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShellScreen(role: 'client')),
          (r) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colorBackground,
      appBar: AppBar(
        title: const Text('Completar Registro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '¡Hola!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.colorText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Qué buscas en Chamba?',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppTheme.colorMuted,
                  ),
                ),
                const SizedBox(height: 48),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _RoleCard(
                    title: 'Quiero Ofrecer Servicios',
                    subtitle: 'Gana dinero ofreciendo tus habilidades',
                    icon: Icons.handyman,
                    onTap: () => _selectType('worker'),
                  ),
                  const SizedBox(height: 24),
                  _RoleCard(
                    title: 'Quiero Contratar',
                    subtitle: 'Encuentra profesionales para tus necesidades',
                    icon: Icons.search,
                    onTap: () => _selectType('client'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.colorPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.colorPrimary, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.colorText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.colorMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.colorMuted),
            ],
          ),
        ),
      ),
    );
  }
}
