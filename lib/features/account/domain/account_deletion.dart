import '../../../core/services/mobile_backend_service.dart';

/// Estado de la eliminación de cuenta programada (espera de 30 días).
class AccountDeletionStatus {
  const AccountDeletionStatus({required this.pending, this.scheduledFor});

  const AccountDeletionStatus.none() : this(pending: false);

  factory AccountDeletionStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['scheduledFor']?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    return AccountDeletionStatus(
      pending: json['pending'] == true && date != null,
      scheduledFor: date,
    );
  }

  final bool pending;
  final DateTime? scheduledFor;

  /// Días que faltan para el borrado definitivo (mínimo 0).
  int daysLeft({DateTime? now}) {
    final date = scheduledFor;
    if (date == null) return 0;
    final diff = date.difference(now ?? DateTime.now());
    return diff.isNegative ? 0 : (diff.inHours / 24).ceil();
  }
}

/// Acceso al backend; se puede reemplazar en pruebas.
class AccountDeletionApi {
  const AccountDeletionApi();

  Future<AccountDeletionStatus> status() async =>
      AccountDeletionStatus.fromJson(
          await MobileBackendService.instance.accountDeletionStatus());

  Future<AccountDeletionStatus> request(String email) async =>
      AccountDeletionStatus.fromJson(await MobileBackendService.instance
          .requestAccountDeletion(email: email));

  Future<AccountDeletionStatus> cancel() async =>
      AccountDeletionStatus.fromJson(
          await MobileBackendService.instance.cancelAccountDeletion());
}

/// El correo escrito confirma la eliminación solo si coincide con el de la
/// cuenta (sin distinguir mayúsculas ni espacios al borde).
bool deletionEmailMatches(String typed, String accountEmail) {
  final a = typed.trim().toLowerCase();
  return a.isNotEmpty && a == accountEmail.trim().toLowerCase();
}

/// "marvin@gmail.com" → "m•••n@gmail.com": pista sin revelar el correo entero
/// a quien tome el teléfono prestado.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final name = email.substring(0, at);
  final domain = email.substring(at);
  if (name.length <= 2) return '${name[0]}•••$domain';
  return '${name[0]}•••${name[name.length - 1]}$domain';
}
