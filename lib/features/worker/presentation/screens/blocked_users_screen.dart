import 'package:flutter/material.dart';

import '../../../../core/services/mobile_backend_service.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

/// Clientes que el trabajador bloqueó. Sus solicitudes no le llegan; desde
/// aquí puede ver a quién bloqueó y desbloquearlo.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUser {
  const _BlockedUser({
    required this.userId,
    required this.fullName,
    required this.photoUrl,
    required this.blockedAt,
  });

  factory _BlockedUser.fromJson(Map<String, dynamic> json) => _BlockedUser(
        userId: json['userId'].toString(),
        fullName: json['fullName']?.toString() ?? 'Usuario',
        photoUrl: json['profilePhotoUrl']?.toString(),
        blockedAt: DateTime.tryParse(json['blockedAt']?.toString() ?? '')
            ?.toLocal(),
      );

  final String userId;
  final String fullName;
  final String? photoUrl;
  final DateTime? blockedAt;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<_BlockedUser> _users = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await MobileBackendService.instance.blockedUsers(userId: userId);
      final rows = response['data'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _users = [
          for (final row in rows)
            if (row is Map) _BlockedUser.fromJson(Map<String, dynamic>.from(row))
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar tu lista. Revisa tu conexión.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmUnblock(_BlockedUser user) async {
    final firstName = user.fullName.split(' ').first;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ChambaNetworkAvatar(
                url: user.photoUrl, radius: 32, fallbackText: user.initials),
            const SizedBox(height: 14),
            Text('¿Desbloquear a $firstName?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.colorText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Volverás a recibir sus solicitudes de trabajo cuando estés disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.colorMuted, fontSize: 14, height: 1.45)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ChambaPrimaryButton(
                label: 'Desbloquear',
                icon: Icons.lock_open_rounded,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.colorMuted)),
            ),
          ]),
        ),
      ),
    );
    if (confirmed == true) await _unblock(user);
  }

  Future<void> _unblock(_BlockedUser user) async {
    final userId = SessionStore.currentUser?.id;
    if (userId == null) return;
    setState(() => _unblocking.add(user.userId));
    try {
      await MobileBackendService.instance
          .unblockUser(userId: userId, blockedUserId: user.userId);
      if (!mounted) return;
      setState(() {
        _users = _users.where((u) => u.userId != user.userId).toList();
        _unblocking.remove(user.userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${user.fullName.split(' ').first} fue desbloqueado')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _unblocking.remove(user.userId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos desbloquearlo. Inténtalo de nuevo.'),
          backgroundColor: AppTheme.colorError));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FF),
        centerTitle: false,
        title: const Text('Clientes bloqueados',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 4, lines: 2, trailing: true);
    }
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 80),
        ChambaEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Algo salió mal',
          message: _error,
          actionLabel: 'Reintentar',
          actionIcon: Icons.refresh_rounded,
          onAction: _load,
        ),
      ]);
    }
    if (_users.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        ChambaEmptyState(
          icon: Icons.verified_user_outlined,
          title: 'No bloqueaste a nadie',
          message:
              'Si bloqueas a un cliente desde una solicitud, aparecerá aquí y podrás desbloquearlo cuando quieras.',
        ),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.colorPrimaryTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded,
                color: AppTheme.colorPrimaryDark, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                  'No recibes solicitudes de estos clientes. Desbloquéalos para volver a verlas.',
                  style: TextStyle(
                      color: AppTheme.colorPrimaryDark,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        for (final user in _users) ...[
          _BlockedUserTile(
            user: user,
            busy: _unblocking.contains(user.userId),
            onUnblock: () => _confirmUnblock(user),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.busy,
    required this.onUnblock,
  });

  final _BlockedUser user;
  final bool busy;
  final VoidCallback onUnblock;

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String get _since {
    final at = user.blockedAt;
    if (at == null) return 'Bloqueado';
    return 'Bloqueado el ${at.day} ${_months[at.month - 1]} ${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEAF5)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          ChambaNetworkAvatar(
              url: user.photoUrl, radius: 24, fallbackText: user.initials),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.colorError,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.block_rounded, size: 10, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.colorText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(_since,
                style:
                    const TextStyle(color: AppTheme.colorMuted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        busy
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2)),
              )
            : OutlinedButton.icon(
                onPressed: onUnblock,
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('Desbloquear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.colorPrimaryDark,
                  side: const BorderSide(color: Color(0xFFD9CCFB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
      ]),
    );
  }
}
