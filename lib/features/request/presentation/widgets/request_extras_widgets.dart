import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../screens/guided_video_screen.dart';
import 'request_form_widgets.dart';

/// Qué cotiza el trabajador: solo su mano de obra, o también los materiales.
/// Los códigos son los que guarda el backend (`materialsMode`).
enum MaterialsMode {
  client('client', 'Solo mano de obra', Icons.handyman_outlined,
      'Ya tienes los materiales. Te ofertan solo por el trabajo.'),
  worker('worker', 'Mano de obra + materiales', Icons.local_shipping_outlined,
      'El trabajador los trae y te cotiza los materiales aparte.');

  const MaterialsMode(this.code, this.label, this.icon, this.help);
  final String code;
  final String label;
  final IconData icon;
  final String help;

  static MaterialsMode? fromCode(String? code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}

/// Pregunta "¿Qué quieres que te coticen?" con 2 respuestas. Si pide
/// materiales, puede anotar cuáles.
class RequestMaterialsPicker extends StatelessWidget {
  const RequestMaterialsPicker({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.noteController,
    this.enabled = true,
  });

  final MaterialsMode? mode;
  final ValueChanged<MaterialsMode> onChanged;
  final TextEditingController noteController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in MaterialsMode.values) ...[
          _MaterialsOption(
            option: option,
            selected: mode == option,
            onTap: enabled ? () => onChanged(option) : null,
          ),
          const SizedBox(height: 6),
        ],
        if (mode == MaterialsMode.worker) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5F0)),
            ),
            child: TextField(
              controller: noteController,
              enabled: enabled,
              minLines: 1,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: requestInk, fontSize: 13.5, height: 1.25),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
                hintText:
                    '¿Qué materiales necesitas? Ej.: pintura látex blanca, 2 manos',
                hintStyle:
                    const TextStyle(color: requestMuted, height: 1.25),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MaterialsOption extends StatelessWidget {
  const _MaterialsOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MaterialsMode option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF6F0FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? requestPurple : const Color(0xFFE5E5F0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(option.icon,
                  color: selected ? requestPurple : requestMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label,
                        style: TextStyle(
                            height: 1.2,
                            color: selected ? const Color(0xFF4C1D95) : requestInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    if (selected) ...[
                      const SizedBox(height: 2),
                      Text(option.help,
                          style: const TextStyle(
                              height: 1.25,
                              color: Color(0xFF6D28D9),
                              fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? requestPurple : const Color(0xFFCBC8D8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Video del lugar en el formulario: grabarlo con la guía, elegirlo de la
/// galería, verlo o quitarlo.
class RequestVideoPicker extends StatelessWidget {
  const RequestVideoPicker({
    super.key,
    required this.video,
    required this.onRecord,
    required this.onPickFromGallery,
    required this.onRemove,
    this.enabled = true,
  });

  final RecordedJobVideo? video;
  final VoidCallback onRecord;
  final VoidCallback onPickFromGallery;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Video del trabajo',
            style: TextStyle(
                height: 1.2,
                color: requestInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        const Text(
            'Un video corto muestra el tamaño y el estado mejor que una foto.',
            style: TextStyle(height: 1.3, color: requestMuted, fontSize: 11)),
        const SizedBox(height: 8),
        if (current == null) ...[
          Semantics(
            button: true,
            label: 'Grabar video guiado',
            child: InkWell(
              onTap: enabled ? onRecord : null,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F0FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: requestPurple.withValues(alpha: .45), width: 1.4),
                ),
                child: const Row(children: [
                  Icon(Icons.videocam_rounded, color: requestPurple, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grabar video guiado',
                            style: TextStyle(
                                height: 1.2,
                                color: requestPurple,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Te digo qué mostrar · hasta 45 s',
                            style: TextStyle(
                                height: 1.2,
                                color: Color(0xFF6D28D9),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: requestPurple),
                ]),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled ? onPickFromGallery : null,
              style: TextButton.styleFrom(
                foregroundColor: requestPurple,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.video_library_outlined, size: 18),
              label: const Text('O elige un video de tu galería',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ] else
          _VideoAttachedTile(
            video: current,
            onRemove: enabled ? onRemove : null,
          ),
      ],
    );
  }
}

class _VideoAttachedTile extends StatelessWidget {
  const _VideoAttachedTile({required this.video, required this.onRemove});

  final RecordedJobVideo video;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final seconds = video.duration.inSeconds;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5F0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => showVideoPreview(context, File(video.path)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2445),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30),
                  if (seconds > 0)
                    Positioned(
                      right: 5,
                      bottom: 4,
                      child: Text(
                        '0:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: requestGreen, size: 16),
                  SizedBox(width: 5),
                  Text('Video listo',
                      style: TextStyle(
                          height: 1.2,
                          color: requestInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 3),
                Text(
                  video.transcript.isNotEmpty
                      ? '"${video.transcript}"'
                      : 'Toca la miniatura para verlo.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      height: 1.25, color: requestMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar video',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFE5484D)),
          ),
        ],
      ),
    );
  }
}

/// Chip corto para las tarjetas de solicitudes: "Llevar materiales" o
/// "Tiene video".
class RequestTagChip extends StatelessWidget {
  const RequestTagChip({
    super.key,
    required this.icon,
    required this.label,
    this.background = const Color(0xFFFAEEDA),
    this.foreground = const Color(0xFF633806),
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Chips de una solicitud según sus datos (materiales y video).
List<Widget> requestTagChips(Map<String, dynamic> request) {
  final chips = <Widget>[];
  final mode = MaterialsMode.fromCode(request['materialsMode']?.toString());
  if (mode == MaterialsMode.worker) {
    chips.add(const RequestTagChip(
        icon: Icons.local_shipping_outlined,
        label: 'Mano de obra + materiales'));
  } else if (mode == MaterialsMode.client) {
    chips.add(const RequestTagChip(
      icon: Icons.handyman_outlined,
      label: 'Solo mano de obra',
      background: Color(0xFFE1F5EE),
      foreground: Color(0xFF085041),
    ));
  }
  if (request['video'] is Map) {
    chips.add(const RequestTagChip(
      icon: Icons.videocam_outlined,
      label: 'Tiene video',
      background: Color(0xFFF1EBFF),
      foreground: Color(0xFF4C1D95),
    ));
  }
  return chips;
}

/// Video del lugar y quién pone los materiales, para los detalles del
/// trabajo que ve el trabajador.
class JobExtrasSection extends StatelessWidget {
  const JobExtrasSection({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final video = request['video'] is Map
        ? Map<String, dynamic>.from(request['video'] as Map)
        : null;
    final mode = MaterialsMode.fromCode(request['materialsMode']?.toString());
    final note = request['materialsNote']?.toString().trim() ?? '';
    if (video == null && mode == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (video != null && (video['url']?.toString() ?? '').isNotEmpty) ...[
          const Text('Video del lugar',
              style: TextStyle(
                  color: Color(0xFF6B6584),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => showVideoPreview(context, video['url'].toString()),
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if ((video['thumbnailUrl']?.toString() ?? '').isNotEmpty)
                      Image.network(video['thumbnailUrl'].toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF2A2445)))
                    else
                      const ColoredBox(color: Color(0xFF2A2445)),
                    const ColoredBox(color: Color(0x33000000)),
                    const Center(
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.play_arrow_rounded,
                            color: requestPurple, size: 34),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      bottom: 10,
                      child: Text('Ver video del trabajo',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (mode != null) ...[
          const Text('Materiales',
              style: TextStyle(
                  color: Color(0xFF6B6584),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: mode == MaterialsMode.worker
                  ? const Color(0xFFFAEEDA)
                  : const Color(0xFFF2EFF8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(mode.icon,
                    size: 20,
                    color: mode == MaterialsMode.worker
                        ? const Color(0xFF854F0B)
                        : requestPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (mode) {
                          MaterialsMode.worker =>
                            'Mano de obra + materiales: tú los llevas',
                          MaterialsMode.client =>
                            'Solo mano de obra: el cliente tiene los materiales',
                        },
                        style: const TextStyle(
                            color: requestInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(note,
                            style: const TextStyle(
                                color: Color(0xFF6B6584),
                                fontSize: 13,
                                height: 1.3)),
                      ],
                      if (mode == MaterialsMode.worker) ...[
                        const SizedBox(height: 4),
                        const Text(
                            'Al ofertar, pon el costo de los materiales aparte de tu mano de obra.',
                            style: TextStyle(
                                color: Color(0xFF854F0B),
                                fontSize: 12,
                                height: 1.3)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// Reproduce un video (archivo local o URL) en una pantalla negra.
Future<void> showVideoPreview(BuildContext context, Object source) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _VideoPreviewScreen(source: source),
    ),
  );
}

class _VideoPreviewScreen extends StatefulWidget {
  const _VideoPreviewScreen({required this.source});

  /// `File` o `String` (URL).
  final Object source;

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  late final VideoPlayerController _controller = widget.source is File
      ? VideoPlayerController.file(widget.source as File)
      : VideoPlayerController.networkUrl(Uri.parse(widget.source.toString()));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller
        ..setLooping(true)
        ..play();
      setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _failed
                  ? const Text('No se pudo reproducir el video.',
                      style: TextStyle(color: Colors.white70))
                  : ready
                      ? GestureDetector(
                          onTap: () => _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play(),
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
            ),
            if (ready)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: requestPurple,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
