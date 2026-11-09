import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';

/// Video que grabó el cliente con la guía, más lo que dijo mientras grababa.
class RecordedJobVideo {
  const RecordedJobVideo({
    required this.path,
    required this.transcript,
    required this.duration,
  });

  final String path;
  final String transcript;
  final Duration duration;
}

/// Un consejo de la guía: lo que el cliente debería mostrar en ese momento.
class _GuideTip {
  const _GuideTip(this.icon, this.text);
  final IconData icon;
  final String text;
}

/// Graba el lugar del trabajo con una guía encima tipo chat: mensajes que le
/// dicen al cliente qué mostrar y, abajo, lo que va diciendo escrito en vivo.
/// Al terminar puede revisar el video, corregir el texto y usarlo.
///
/// La guía es texto (no voz): una voz de la app se grabaría en el video y se
/// mezclaría con lo que dice el cliente en la transcripción.
class GuidedVideoScreen extends StatefulWidget {
  const GuidedVideoScreen({this.initialTranscript = '', super.key});

  /// Texto que el cliente ya había escrito: la transcripción se suma a él.
  final String initialTranscript;

  static const Duration maxDuration = Duration(seconds: 45);

  /// Abre la grabación y devuelve el video, o null si el cliente salió.
  static Future<RecordedJobVideo?> open(
    BuildContext context, {
    String initialTranscript = '',
  }) {
    return Navigator.of(context, rootNavigator: true).push<RecordedJobVideo>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GuidedVideoScreen(initialTranscript: initialTranscript),
      ),
    );
  }

  @override
  State<GuidedVideoScreen> createState() => _GuidedVideoScreenState();
}

enum _Phase { loading, ready, recording, review, error }

class _GuidedVideoScreenState extends State<GuidedVideoScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const List<_GuideTip> _tips = [
    _GuideTip(Icons.panorama_wide_angle_outlined,
        'Muestra el lugar completo, desde lejos.'),
    _GuideTip(Icons.zoom_in_rounded,
        'Ahora acércate a lo que hay que arreglar o hacer.'),
    _GuideTip(Icons.record_voice_over_outlined,
        'Cuenta en voz alta qué necesitas. Por ejemplo: "quiero que pinten esta pared".'),
    _GuideTip(Icons.straighten_rounded,
        'Muestra el tamaño: cuántas paredes, metros o piezas son.'),
    _GuideTip(Icons.inventory_2_outlined,
        'Di si ya tienes los materiales o si el trabajador debe traerlos.'),
    _GuideTip(Icons.check_circle_outline_rounded,
        'Muy bien. Ya puedes terminar cuando quieras.'),
  ];
  static const Duration _tipEvery = Duration(seconds: 7);

  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  _Phase _phase = _Phase.loading;
  String? _errorMessage;

  // Grabación
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  int _tipIndex = -1;
  DateTime _lastTipAt = DateTime.now();

  // Transcripción en vivo
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _speechFailed = false;
  bool _restartScheduled = false;
  String _finalText = '';
  String _partialText = '';

  // Revisión
  XFile? _file;
  VideoPlayerController? _player;
  final TextEditingController _transcriptCtrl = TextEditingController();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _ticker?.cancel();
    _speech.cancel();
    _camera?.dispose();
    _player?.dispose();
    _transcriptCtrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      if (_phase == _Phase.recording) _stopRecording();
    }
  }

  Future<void> _initCamera({int? index}) async {
    setState(() => _phase = _Phase.loading);
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('noCamera', 'No encontramos una cámara.');
      }
      if (index == null) {
        final back = _cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.back);
        _cameraIndex = back >= 0 ? back : 0;
      } else {
        _cameraIndex = index % _cameras.length;
      }
      final previous = _camera;
      _camera = null;
      await previous?.dispose();
      final controller = CameraController(
        _cameras[_cameraIndex],
        // 480p: se ve bien y sube rápido con datos móviles.
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _phase = _Phase.ready;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = e.code == 'CameraAccessDenied' ||
                e.code == 'AudioAccessDenied' ||
                e.code.contains('Permission')
            ? 'Necesitamos permiso de cámara y micrófono para grabar el video.'
            : 'No pudimos abrir la cámara. Intenta de nuevo.';
      });
    }
  }

  // ── Grabación ────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null || camera.value.isRecordingVideo) return;
    HapticFeedback.mediumImpact();
    try {
      await camera.startVideoRecording();
    } on CameraException {
      _showSnack('No pudimos empezar a grabar. Intenta de nuevo.');
      return;
    }
    _finalText = '';
    _partialText = '';
    _stopwatch
      ..reset()
      ..start();
    _tipIndex = 0;
    _lastTipAt = DateTime.now();
    setState(() {
      _phase = _Phase.recording;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    _startListening();
  }

  void _tick() {
    if (!mounted || _phase != _Phase.recording) return;
    final elapsed = _stopwatch.elapsed;
    if (elapsed >= GuidedVideoScreen.maxDuration) {
      _stopRecording();
      return;
    }
    var tipIndex = _tipIndex;
    if (DateTime.now().difference(_lastTipAt) >= _tipEvery &&
        tipIndex < _tips.length - 1) {
      tipIndex++;
      _lastTipAt = DateTime.now();
      HapticFeedback.selectionClick();
    }
    setState(() {
      _elapsed = elapsed;
      _tipIndex = tipIndex;
    });
  }

  void _nextTip() {
    if (_tipIndex >= _tips.length - 1) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tipIndex++;
      _lastTipAt = DateTime.now();
    });
  }

  Future<void> _stopRecording() async {
    final camera = _camera;
    if (camera == null || !camera.value.isRecordingVideo) return;
    _ticker?.cancel();
    _stopwatch.stop();
    HapticFeedback.lightImpact();
    await _stopListening();
    XFile file;
    try {
      file = await camera.stopVideoRecording();
    } on CameraException {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      _showSnack('No se pudo guardar el video. Graba de nuevo.');
      return;
    }
    if (_stopwatch.elapsed < const Duration(seconds: 2)) {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      _showSnack('El video quedó muy corto. Mantén grabando unos segundos.');
      return;
    }
    final spoken = _spokenText;
    final initial = widget.initialTranscript.trim();
    _transcriptCtrl.text = [
      if (initial.isNotEmpty) initial,
      if (spoken.isNotEmpty) spoken,
    ].join(initial.isNotEmpty && spoken.isNotEmpty ? '. ' : '');
    final player = VideoPlayerController.file(File(file.path));
    try {
      await player.initialize();
      await player.setLooping(true);
      await player.play();
    } catch (_) {
      // Sin vista previa igual se puede usar el video.
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _file = file;
      _player = player;
      _phase = _Phase.review;
    });
  }

  Future<void> _recordAgain() async {
    final player = _player;
    _player = null;
    await player?.dispose();
    final file = _file;
    _file = null;
    if (file != null) {
      try {
        await File(file.path).delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _tipIndex = -1;
      _phase = _Phase.ready;
    });
  }

  void _useVideo() {
    final file = _file;
    if (file == null) return;
    _player?.pause();
    Navigator.of(context).pop(RecordedJobVideo(
      path: file.path,
      transcript: _transcriptCtrl.text.trim(),
      duration: _stopwatch.elapsed,
    ));
  }

  // ── Transcripción ────────────────────────────────────────────────────────

  String get _spokenText {
    final text = [_finalText.trim(), _partialText.trim()]
        .where((t) => t.isNotEmpty)
        .join(' ');
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _startListening() async {
    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: (status) {
            // El reconocedor se apaga tras un silencio: mientras se graba se
            // vuelve a encender y se conserva lo ya dicho.
            if ((status == 'done' || status == 'notListening') &&
                _phase == _Phase.recording &&
                !_restartScheduled) {
              _commitPartial();
              // 'notListening' y 'done' llegan juntos: un solo reinicio.
              _restartScheduled = true;
              Future<void>.delayed(const Duration(milliseconds: 400), () {
                _restartScheduled = false;
                if (mounted &&
                    _phase == _Phase.recording &&
                    !_speech.isListening) {
                  _listenOnce();
                }
              });
            }
          },
          onError: (error) {
            // Un silencio ("no te escuché") no es una falla: se sigue
            // escuchando. Solo avisamos si el micrófono o el permiso fallan.
            final msg = error.errorMsg;
            final silence = msg == 'error_no_match' ||
                msg == 'error_speech_timeout' ||
                msg == 'error_busy' ||
                msg == 'error_client';
            if (!silence && error.permanent && mounted) {
              setState(() => _speechFailed = true);
            }
          },
        );
      }
      if (!_speechReady) {
        if (mounted) setState(() => _speechFailed = true);
        return;
      }
      await _listenOnce();
    } catch (_) {
      if (mounted) setState(() => _speechFailed = true);
    }
  }

  Future<void> _listenOnce() async {
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            if (result.finalResult) {
              _finalText = '$_finalText ${result.recognizedWords}'.trim();
              _partialText = '';
            } else {
              _partialText = result.recognizedWords;
            }
          });
        },
        localeId: 'es_ES',
        listenFor: GuidedVideoScreen.maxDuration,
        pauseFor: const Duration(seconds: 6),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _speechFailed = true);
    }
  }

  void _commitPartial() {
    if (_partialText.trim().isEmpty) return;
    _finalText = '$_finalText ${_partialText.trim()}'.trim();
    _partialText = '';
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _commitPartial();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Vista ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: switch (_phase) {
          _Phase.review => _buildReview(),
          _Phase.error => _buildError(),
          _ => _buildCamera(),
        },
      ),
    );
  }

  Widget _buildCamera() {
    final camera = _camera;
    final recording = _phase == _Phase.recording;
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized)
          _CoverPreview(controller: camera)
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        // Oscurece arriba y abajo para que se lean los mensajes.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.32, 0.62, 1],
                colors: [
                  Color(0xB3000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
        ),
        // Barra superior: cerrar, tiempo y voltear cámara.
        Positioned(
          top: padding.top + 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Salir',
                onTap: () async {
                  if (recording) await _stopRecording();
                  if (mounted) Navigator.of(context).maybePop();
                },
              ),
              const Spacer(),
              _TimerPill(elapsed: _elapsed, recording: recording),
              const Spacer(),
              _RoundIconButton(
                icon: Icons.cameraswitch_outlined,
                tooltip: 'Cambiar cámara',
                onTap: recording || _cameras.length < 2
                    ? null
                    : () => _initCamera(index: _cameraIndex + 1),
              ),
            ],
          ),
        ),
        // Mensajes de la guía.
        Positioned(
          top: padding.top + 66,
          left: 14,
          right: 56,
          child: _buildGuide(recording),
        ),
        // Lo que va diciendo el cliente.
        Positioned(
          left: 14,
          right: 14,
          bottom: padding.bottom + 132,
          child: _buildTranscriptBubble(recording),
        ),
        // Controles.
        Positioned(
          left: 0,
          right: 0,
          bottom: padding.bottom + 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: recording && _tipIndex < _tips.length - 1
                    ? TextButton(
                        onPressed: _nextTip,
                        child: const Text(
                          'Siguiente\nconsejo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      )
                    : null,
              ),
              _RecordButton(
                recording: recording,
                progress: _elapsed.inMilliseconds /
                    GuidedVideoScreen.maxDuration.inMilliseconds,
                enabled: _phase == _Phase.ready || recording,
                onTap: recording ? _stopRecording : _startRecording,
              ),
              const SizedBox(width: 96),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuide(bool recording) {
    final bubbles = <Widget>[];
    if (!recording) {
      bubbles
        ..add(const _GuideBubble(
          key: ValueKey('intro-1'),
          icon: Icons.videocam_outlined,
          text:
              'Graba el trabajo para que el trabajador vea cómo es antes de cotizar.',
        ))
        ..add(const _GuideBubble(
          key: ValueKey('intro-2'),
          icon: Icons.mic_none_rounded,
          text:
              'Habla mientras grabas: lo que digas se escribe solo. Te voy diciendo qué mostrar.',
        ))
        ..add(const _GuideBubble(
          key: ValueKey('intro-3'),
          icon: Icons.fiber_manual_record_rounded,
          text: 'Toca el botón rojo para empezar. Máximo 45 segundos.',
          highlight: true,
        ));
    } else {
      // El consejo anterior queda tenue arriba y el actual resalta.
      if (_tipIndex > 0) {
        final prev = _tips[_tipIndex - 1];
        bubbles.add(_GuideBubble(
          key: ValueKey('tip-${_tipIndex - 1}'),
          icon: prev.icon,
          text: prev.text,
          dimmed: true,
        ));
      }
      final tip = _tips[_tipIndex.clamp(0, _tips.length - 1)];
      bubbles.add(_GuideBubble(
        key: ValueKey('tip-$_tipIndex'),
        icon: tip.icon,
        text: tip.text,
        highlight: true,
        step: '${_tipIndex + 1} de ${_tips.length}',
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bubble in bubbles)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: bubble),
      ],
    );
  }

  Widget _buildTranscriptBubble(bool recording) {
    if (!recording) return const SizedBox.shrink();
    final text = _spokenText;
    final String shown;
    if (_speechFailed && text.isEmpty) {
      shown = 'No pudimos escuchar aquí. Al terminar podrás escribir la descripción.';
    } else if (text.isEmpty) {
      shown = 'Te escucho… lo que digas aparece aquí.';
    } else {
      shown = text;
    }
    final placeholder = text.isEmpty;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              color: AppTheme.colorPrimary.withValues(alpha: 0.72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _pulse,
                        child: const Icon(Icons.graphic_eq_rounded,
                            color: Colors.white, size: 15),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Tú',
                        style: TextStyle(
                          color: Color(0xFFE9DDFF),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shown,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: placeholder
                          ? Colors.white.withValues(alpha: 0.78)
                          : Colors.white,
                      fontSize: 15,
                      height: 1.3,
                      fontStyle:
                          placeholder ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReview() {
    final player = _player;
    final padding = MediaQuery.paddingOf(context);
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (player != null && player.value.isInitialized)
                GestureDetector(
                  onTap: () => setState(() {
                    player.value.isPlaying ? player.pause() : player.play();
                  }),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: player.value.size.width,
                      height: player.value.size.height,
                      child: VideoPlayer(player),
                    ),
                  ),
                )
              else
                const Center(
                  child: Icon(Icons.movie_outlined,
                      color: Colors.white54, size: 64),
                ),
              Positioned(
                top: padding.top + 8,
                left: 8,
                child: _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Grabar de nuevo',
                  onTap: _recordAgain,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(18, 16, 18, padding.bottom + 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Así se entiende el trabajo?',
                style: TextStyle(
                  color: AppTheme.colorText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Revisa lo que dijiste. Puedes corregirlo antes de seguir.',
                style: TextStyle(color: AppTheme.colorMuted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _transcriptCtrl,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe el trabajo que necesitas',
                  filled: true,
                  fillColor: AppTheme.colorGlassInputSoft,
                  counterStyle: const TextStyle(fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppTheme.colorGlassBorderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppTheme.colorGlassBorderSoft),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recordAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Grabar de nuevo'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: AppTheme.colorText,
                        side: const BorderSide(
                            color: AppTheme.colorGlassBorderSoft),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _useVideo,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Usar video'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppTheme.colorPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No pudimos abrir la cámara.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _initCamera(),
              style:
                  FilledButton.styleFrom(backgroundColor: AppTheme.colorPrimary),
              child: const Text('Intentar de nuevo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Salir',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista de la cámara llenando la pantalla sin deformarse.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    // previewSize viene en horizontal; en vertical se invierte.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// Mensaje de la guía, como un chat transparente sobre el video.
class _GuideBubble extends StatelessWidget {
  const _GuideBubble({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.dimmed = false,
    this.step,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool highlight;
  final bool dimmed;
  final String? step;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: (dimmed ? 0.55 : 1) * t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.colorPrimary,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 11),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: highlight ? 0.24 : 0.14),
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: highlight ? 0.38 : 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(icon,
                            color: highlight
                                ? AppTheme.colorHighlight
                                : Colors.white,
                            size: 18),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (step != null)
                              Text(
                                'Paso $step',
                                style: const TextStyle(
                                  color: Color(0xFFFFE08A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            Text(
                              text,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: highlight ? 15.5 : 14,
                                fontWeight: highlight
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                height: 1.3,
                                shadows: const [
                                  Shadow(color: Colors.black38, blurRadius: 6),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.progress,
    required this.enabled,
    required this.onTap,
  });

  final bool recording;
  final double progress;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Terminar video' : 'Empezar a grabar',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: recording ? progress.clamp(0.0, 1.0) : 0,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.45),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.colorHighlight),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: recording ? 32 : 64,
                height: recording ? 32 : 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D),
                  borderRadius: BorderRadius.circular(recording ? 8 : 32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.elapsed, required this.recording});
  final Duration elapsed;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    String fmt(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: recording
            ? const Color(0xFFE5484D)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        recording
            ? '${fmt(elapsed)} / ${fmt(GuidedVideoScreen.maxDuration)}'
            : 'Hasta ${GuidedVideoScreen.maxDuration.inSeconds} s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: onTap == null ? Colors.white38 : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
