import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PhoneVerificationResult {
  const PhoneVerificationResult(this.phone, this.idToken);
  final String phone;
  final String idToken;
}

Future<PhoneVerificationResult?> verifyRegistrationPhone(BuildContext context,
        {String? phone}) =>
    Navigator.of(context).push<PhoneVerificationResult>(MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(phone: phone)));

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key, this.phone});
  final String? phone;
  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  late final TextEditingController _phone;
  final _code = TextEditingController();
  String? _verificationId, _error, _sentPhone;
  ConfirmationResult? _webConfirmation;
  bool _busy = false, _finished = false, _finishing = false;
  DateTime? _retryAt;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.phone ?? '+591');
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String _number() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final result =
        RegExp(r'^[67]\d{7}$').hasMatch(digits) ? '+591$digits' : '+$digits';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(result)) {
      throw const FormatException(
          'Escribe un celular válido con código de país.');
    }
    return result;
  }

  String _message(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-verification-code' =>
          'El código no es correcto. Revisa el SMS.',
        'session-expired' => 'El código venció. Solicita uno nuevo.',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
        'invalid-phone-number' => 'Revisa el número y el código de país.',
        'operation-not-allowed' ||
        'billing-not-enabled' =>
          'La verificación por SMS aún no está habilitada. Intenta más tarde.',
        _ => 'No se pudo verificar el número. Intenta de nuevo.',
      };
    }
    return error is FormatException
        ? error.message.toString()
        : 'No se pudo verificar el número. Intenta de nuevo.';
  }

  Future<void> _finish(PhoneAuthCredential credential) async {
    if (_finished || _finishing || !mounted) return;
    _finishing = true;
    try {
      final user =
          (await FirebaseAuth.instance.signInWithCredential(credential)).user;
      await _result(user);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    } finally {
      _finishing = false;
    }
  }

  Future<void> _result(User? user) async {
    final token = await user?.getIdToken(true);
    if (!mounted) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    if (_finished) return;
    if (token == null || user?.phoneNumber != _sentPhone) {
      throw StateError('Número no verificado');
    }
    _finished = true;
    final result = PhoneVerificationResult(_sentPhone!, token);
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _send() async {
    if (_busy || (_retryAt?.isAfter(DateTime.now()) ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final phone = _number();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      _sentPhone = phone;
      _retryAt = DateTime.now().add(const Duration(seconds: 60));
      if (kIsWeb) {
        _webConfirmation =
            await FirebaseAuth.instance.signInWithPhoneNumber(phone);
        if (mounted) setState(() => _busy = false);
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: phone,
            verificationCompleted: (credential) {
              unawaited(_finish(credential));
            },
            verificationFailed: (error) {
              if (mounted) {
                setState(() {
                  _busy = false;
                  _error = _message(error);
                });
              }
            },
            codeSent: (id, _) {
              if (mounted) {
                setState(() {
                  _verificationId = id;
                  _busy = false;
                });
              }
            },
            codeAutoRetrievalTimeout: (id) {
              if (mounted) {
                setState(() {
                  _verificationId = id;
                  _busy = false;
                });
              }
            });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _confirm() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_webConfirmation != null) {
        await _result((await _webConfirmation!.confirm(_code.text)).user);
      } else {
        await _finish(PhoneAuthProvider.credential(
            verificationId: _verificationId!, smsCode: _code.text));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _verificationId != null || _webConfirmation != null;
    return Scaffold(
        appBar: AppBar(title: const Text('Verifica tu celular')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                      'Solo necesitas verificar el número al crear tu cuenta. Después entrarás normalmente con tu contraseña.',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  TextField(
                      controller: _phone,
                      enabled: !_busy && !sent,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                          labelText: 'Celular con código de país',
                          hintText: '+591 7XXXXXXX')),
                  const SizedBox(height: 16),
                  if (sent) ...[
                    TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration:
                            const InputDecoration(labelText: 'Código del SMS'),
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 12)
                  ],
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _busy
                          ? null
                          : sent
                              ? (_code.text.length == 6 ? _confirm : null)
                              : _send,
                      child: Text(_busy
                          ? 'Procesando…'
                          : sent
                              ? 'Verificar código'
                              : 'Enviar código SMS')),
                  if (sent)
                    TextButton(
                        onPressed: _busy ? null : _send,
                        child: const Text('Reenviar SMS (espera 60 segundos)')),
                  const SizedBox(height: 16),
                  const Text(
                      'Al solicitar el código, aceptas que Google procese tu número para verificarlo y prevenir abuso.',
                      style: TextStyle(fontSize: 12)),
                ])));
  }
}
