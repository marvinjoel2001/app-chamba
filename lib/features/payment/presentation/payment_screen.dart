import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/payment_checkout.dart';

/// Pantalla genérica para pagos que se completan fuera de la app (QR del
/// banco o página de una pasarela). Muestra lo que manda el backend, consulta
/// el estado cada `pollSeconds` y devuelve `true` cuando el pago quedó hecho
/// (o reportado con "Ya pagué").
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    required this.offerId,
    required this.initial,
    this.api = const PaymentApi(),
    super.key,
  });

  final String offerId;
  final PaymentCheckout initial;
  final PaymentApi api;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late PaymentCheckout _payment = widget.initial;
  Timer? _poll;
  Timer? _clock;
  bool _busy = false;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimers();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _poll?.cancel();
    _clock?.cancel();
    if (_payment.pollSeconds > 0 && _payment.id != null) {
      _poll = Timer.periodic(
          Duration(seconds: _payment.pollSeconds), (_) => _refresh());
    }
    if (_payment.expiresAt != null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_expired) _clock?.cancel();
      });
    }
  }

  bool get _expired =>
      _payment.status == PaymentStatus.expired ||
      (_payment.expiresAt != null &&
          !_payment.expiresAt!.isAfter(DateTime.now()) &&
          _payment.status == PaymentStatus.pending);

  void _apply(PaymentCheckout next) {
    if (!mounted) return;
    setState(() => _payment = next);
    if (next.isSettled) {
      _poll?.cancel();
      Navigator.of(context).pop(true);
    } else if (next.isDead) {
      _poll?.cancel();
    }
  }

  Future<void> _refresh() async {
    final id = _payment.id;
    if (id == null || _busy) return;
    try {
      _apply(await widget.api.status(id));
    } catch (_) {
      // Sin red: se reintenta en el siguiente ciclo.
    }
  }

  Future<void> _run(Future<PaymentCheckout> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await task();
      if (!mounted) return;
      _busy = false;
      _apply(next);
      if (!next.isSettled && !next.isDead) _startTimers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is ApiException || error is NetworkException
          ? error.toString().replaceFirst('Exception: ', '')
          : 'No pudimos completar la acción. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportPaid() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Ya hiciste el pago?'),
        content: Text(
          'Confirma que pagaste ${_payment.amountLabel} desde tu banco. '
          'Lo revisaremos y avisaremos si hay algún problema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Todavía no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, ya pagué'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => widget.api.reportPaid(_payment.id!));
  }

  Future<void> _openUrl() async {
    final url = Uri.tryParse(_payment.url ?? '');
    if (url == null) return;
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!opened && mounted) {
      setState(() => _error = 'No pudimos abrir la página de pago.');
    }
  }

  Future<Uint8List?> _qrBytes() async {
    final base64 = _payment.qrImageBase64;
    if (base64 != null) {
      return base64Decode(
          base64.replaceFirst(RegExp(r'^data:image/\w+;base64,'), ''));
    }
    final url = Uri.tryParse(_payment.qrImageUrl ?? '');
    if (url == null) return null;
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  /// Para pagar desde el mismo teléfono: se guarda o comparte la imagen y se
  /// sube en la app del banco.
  Future<void> _shareQr() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _qrBytes();
      if (bytes == null) throw Exception();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chamba-qr-pago.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'QR de pago Chamba · ${_payment.amountLabel}',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No pudimos preparar el QR. Haz una captura de pantalla.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String get _countdown {
    final left = _payment.expiresAt!.difference(DateTime.now());
    if (left.isNegative) return '00:00';
    final m = left.inMinutes.toString().padLeft(2, '0');
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dead = _expired || _payment.isDead;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppTheme.colorBackground,
        appBar: AppBar(title: const Text('Pagar')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _payment.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.colorMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _payment.amountLabel,
                  key: const Key('payment-amount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.colorText,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_payment.methodName.isNotEmpty)
                  Text(
                    _payment.methodName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.colorMuted),
                  ),
                const SizedBox(height: 20),
                if (dead)
                  _DeadNotice(
                    expired: _expired,
                    busy: _busy,
                    onRetry: () =>
                        _run(() => widget.api.checkout(widget.offerId)),
                  )
                else ...[
                  if (_payment.action == PaymentAction.qr) _buildQr(),
                  if (_payment.action == PaymentAction.openUrl)
                    FilledButton.icon(
                      key: const Key('payment-open-url'),
                      onPressed: _openUrl,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir página de pago'),
                    ),
                  if (_payment.instructions != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _payment.instructions!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.colorText, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _WaitingRow(
                    countdown: _payment.expiresAt == null ? null : _countdown,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.colorError,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 22),
                if (!dead && _payment.canReportPaid)
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const Key('payment-report'),
                      onPressed: _busy ? null : _reportPaid,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Ya pagué'),
                    ),
                  ),
                TextButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Pagar después'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQr() {
    final base64 = _payment.qrImageBase64;
    final Widget image = base64 != null
        ? Image.memory(
            base64Decode(
                base64.replaceFirst(RegExp(r'^data:image/\w+;base64,'), '')),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const _QrError(),
          )
        : Image.network(
            _payment.qrImageUrl ?? '',
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => const _QrError(),
          );
    return Column(
      children: [
        Container(
          key: const Key('payment-qr'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.colorGlassBorder),
            boxShadow: AppTheme.shadowMd,
          ),
          child: AspectRatio(aspectRatio: 1, child: image),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _sharing ? null : _shareQr,
          icon: _sharing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.ios_share_rounded),
          label: const Text('Guardar o compartir QR'),
        ),
      ],
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({this.countdown});

  final String? countdown;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.colorPrimary),
          ),
          const SizedBox(width: 8),
          Text(
            countdown == null
                ? 'Esperando tu pago…'
                : 'Esperando tu pago · vence en $countdown',
            style: const TextStyle(
                color: AppTheme.colorMuted, fontWeight: FontWeight.w600),
          ),
        ],
      );
}

class _DeadNotice extends StatelessWidget {
  const _DeadNotice(
      {required this.expired, required this.busy, required this.onRetry});

  final bool expired;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.colorWarningSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              expired ? 'Este cobro venció.' : 'Este pago no se completó.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.colorText, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Si ya pagaste, no pagues de nuevo: escríbenos a soporte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.colorMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('payment-retry'),
              onPressed: busy ? null : onRetry,
              child: const Text('Generar un cobro nuevo'),
            ),
          ],
        ),
      );
}

class _QrError extends StatelessWidget {
  const _QrError();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'No pudimos cargar el QR.\nRevisa tu conexión.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.colorMuted),
        ),
      );
}
