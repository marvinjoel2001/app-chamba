import 'package:flutter/material.dart';

import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';
import '../../../messages/presentation/screens/chat_screen.dart';
import '../../../mobile_data/data/services/mobile_backend_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _tracking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requestId = SessionStore.activeRequestId;
    if (requestId == null) {
      setState(() {
        _error = 'No hay solicitud activa para rastrear.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await MobileBackendService.tracking(requestId: requestId);
      setState(() {
        _tracking = response;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = _tracking?['worker'] as Map<String, dynamic>?;

    return Scaffold(
      body: Stack(
        children: [
          const ChambaBackground(showGrid: true, child: SizedBox.expand()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          Text(
                            'Rastreo de Servicio',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            _tracking == null
                                ? 'Sin servicio activo'
                                : 'Llegada estimada: ${_tracking!['etaMinutes'] ?? '--'} min',
                            style: const TextStyle(color: AppTheme.colorPrimary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GlassCard(
                  borderRadius: 26,
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        )
                      : _error != null
                          ? Text(_error!)
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundImage: worker?['profilePhotoUrl'] == null
                                          ? null
                                          : NetworkImage(worker!['profilePhotoUrl'] as String),
                                      child: worker?['profilePhotoUrl'] == null
                                          ? Text((worker?['firstName'] ?? 'W')
                                              .toString()
                                              .substring(0, 1))
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'.trim(),
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Text(
                                            'En camino',
                                            style: TextStyle(color: AppTheme.colorPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${_tracking?['etaMinutes'] ?? '--'} min',
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Text(
                                          'LLEGADA\nESTIMADA',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(color: AppTheme.colorMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.colorSurfaceSoft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Distancia actual ${( _tracking?['distanceKm'] ?? 0 ).toString()} km',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChambaPrimaryButton(
                                        label: 'Llamar',
                                        icon: Icons.call,
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Llamada iniciada (demo)'),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ChambaPrimaryButton(
                                        label: 'Chatear',
                                        icon: Icons.chat,
                                        onPressed: () {
                                          final threadId = SessionStore.activeThreadId;
                                          if (threadId == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('No hay chat activo.'),
                                              ),
                                            );
                                            return;
                                          }
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => ChatScreen(
                                                threadId: threadId,
                                                title: '${worker?['firstName'] ?? ''} ${worker?['lastName'] ?? ''}'.trim(),
                                                avatarUrl: worker?['profilePhotoUrl'] as String?,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
