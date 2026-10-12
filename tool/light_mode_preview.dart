// Vista de QA visual del modo claro. Usa datos de ejemplo en memoria: no
// inicia sesión, no llama a la API para mensajes/avisos/billetera y no crea
// nada. La app real sigue usando lib/main.dart.
//
//   flutter run -t tool/light_mode_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/category_visuals.dart';
import 'package:mobile/core/widgets/chamba_widgets.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/explore/presentation/screens/explore_screen.dart';
import 'package:mobile/features/messages/domain/entities/chat_thread.dart';
import 'package:mobile/features/messages/presentation/screens/messages_screen.dart';
import 'package:mobile/features/notifications/domain/models/app_notification.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/worker/data/models/worker_job_model.dart';
import 'package:mobile/features/worker/domain/entities/worker_job.dart';
import 'package:mobile/features/worker/domain/repositories/worker_repository.dart';
import 'package:mobile/features/worker/domain/usecases/worker_usecases.dart';
import 'package:mobile/features/worker/presentation/screens/wallet_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _PreviewMenu(),
    ),
  ));
}

DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
    DateTime.now().subtract(Duration(days: days, hours: hours, minutes: minutes));

final _notifications = <AppNotification>[
  AppNotification(id: '1', title: 'Nueva oferta de Carlos M.', body: 'Ofrece hacer el trabajo por Bs 180.', type: 'offer_new', isRead: false, createdAt: _ago(minutes: 4)),
  AppNotification(id: '2', title: 'El trabajador llegó', body: 'Ana P. está en la dirección indicada. Confirma el inicio.', type: 'worker_arrived', isRead: false, createdAt: _ago(hours: 3)),
  AppNotification(id: '3', title: '¡Oferta aceptada!', body: 'Tu trabajo de plomería quedó confirmado.', type: 'offer_accepted', isRead: true, createdAt: _ago(days: 1, hours: 2)),
  AppNotification(id: '4', title: 'Trabajo finalizado', body: 'Califica a Luis R. por la instalación eléctrica.', type: 'job_finished', isRead: true, createdAt: _ago(days: 3)),
  AppNotification(id: '5', title: 'Solicitud cancelada', body: 'El cliente canceló la solicitud de limpieza.', type: 'job_cancelled', isRead: true, createdAt: _ago(days: 12)),
  AppNotification(id: '6', title: 'Nueva reseña', body: 'Recibiste 5 estrellas: “Muy puntual y prolijo”.', type: 'new_review', isRead: true, createdAt: _ago(days: 40)),
];

final _threads = <ChatThread>[
  ChatThread(id: 't1', jobId: 'j1', jobTitle: 'Arreglar fuga en el baño', jobDescription: '', jobStatus: ChatThreadStatus.active, agreedPrice: 150, counterpartName: 'Carlos M.', category: 'Plomería', chatEnabled: true, unreadCount: 2, lastMessage: 'Llego en 10 minutos', lastMessageAt: _ago(minutes: 8)),
  ChatThread(id: 't2', jobId: 'j2', jobTitle: 'Pintar dormitorio', jobDescription: '', jobStatus: ChatThreadStatus.active, agreedPrice: 400, counterpartName: 'Ana P.', category: 'Pintura', chatEnabled: true, lastMessage: '¿Qué color prefieres?', lastMessageAt: _ago(days: 1, hours: 4)),
  ChatThread(id: 't3', jobId: 'j3', jobTitle: 'Instalar tomacorrientes', jobDescription: '', jobStatus: ChatThreadStatus.completed, agreedPrice: 90, counterpartName: 'Luis R.', category: 'Electricidad', chatEnabled: true, lastMessage: 'Gracias por todo', lastMessageAt: _ago(days: 9)),
];

class _FakeWorkerRepo implements WorkerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<List<WorkerJob>>> workerHistory({required String workerUserId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    WorkerJobModel job(String id, String title, String category, double amount, DateTime at) =>
        WorkerJobModel.fromJson({
          'requestId': id,
          'title': title,
          'category': category,
          'offerStatus': 'accepted',
          'requestStatus': 'completed',
          'amount': amount,
          'completedAt': at.toUtc().toIso8601String(),
          'paymentMethod': 'Efectivo',
        });
    return Success([
      job('1', 'Cambio de grifería', 'Plomería', 180, _ago(hours: 2)),
      job('2', 'Limpieza profunda', 'Limpieza', 250, _ago(days: 1)),
      job('3', 'Mudanza pequeña', 'Mudanzas', 320, _ago(days: 4)),
      job('4', 'Instalar lámparas', 'Electricidad', 120, _ago(days: 15)),
    ]);
  }
}

class _PreviewMenu extends StatelessWidget {
  const _PreviewMenu();

  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    final entries = <(String, IconData, VoidCallback)>[
      ('Componentes', Icons.widgets_rounded, () => open(const _ComponentsPage())),
      ('Mensajes + actividad', Icons.chat_rounded, () => open(_MessagesPreview())),
      ('Notificaciones', Icons.notifications_rounded, () => open(NotificationsScreen(previewItems: _notifications))),
      ('Notificaciones (cargando)', Icons.hourglass_top_rounded, () => open(const _LoadingPreview())),
      ('Billetera (worker)', Icons.account_balance_wallet_rounded, () {
        SessionStore.currentUser = const SessionUser(id: 'qa-worker', type: 'worker', firstName: 'QA', email: 'qa@example.invalid');
        open(WalletScreen(getWorkerHistoryUseCase: GetWorkerHistoryUseCase(_FakeWorkerRepo())));
      }),
      ('Inicio cliente', Icons.home_rounded, () => open(const ExploreScreen(role: 'client'))),
      ('Login', Icons.login_rounded, () => open(const LoginScreen())),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlay,
      child: Scaffold(
        appBar: AppBar(title: const Text('Modo claro · QA')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (label, icon, onTap) in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ChambaSecondaryButton(label: label, icon: icon, onPressed: onTap),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessagesPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: MessagesInbox(
          threads: _threads,
          notifications: _notifications.take(4).toList(),
          unreadNotifications: 2,
          onRefresh: () async {},
          onNotifications: () {},
          onNotification: (_) {},
          onThread: (_) {},
        ),
        bottomNavigationBar: ChambaBottomNavWithBadge(
          role: 'client',
          currentIndex: 1,
          unreadCount: 3,
          messagesTabIndex: 1,
          onTap: (_) {},
        ),
      );
}

class _LoadingPreview extends StatelessWidget {
  const _LoadingPreview();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cargando…')),
        body: const SkeletonList(count: 7, lines: 3, circleLeading: false),
      );
}

class _ComponentsPage extends StatefulWidget {
  const _ComponentsPage();

  @override
  State<_ComponentsPage> createState() => _ComponentsPageState();
}

class _ComponentsPageState extends State<_ComponentsPage> {
  bool _chip = true;
  int _tab = 0;

  static const _categories = [
    'Plomería', 'Electricidad', 'Pintura', 'Limpieza', 'Carpintería',
    'Jardinería', 'Mudanzas', 'Mecánica', 'Albañilería', 'Cerrajería',
    'Refrigeración', 'Computación', 'Belleza', 'Cocina', 'Niñera',
    'Mascotas', 'Clases', 'Fotografía', 'Eventos', 'General',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Componentes')),
      bottomNavigationBar: ChambaBottomNavWithBadge(
        role: 'worker',
        currentIndex: _tab,
        unreadCount: 5,
        messagesTabIndex: 2,
        onTap: (i) => setState(() => _tab = i),
      ),
      body: ChambaBackground(
        showGrid: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ChambaPrimaryButton(label: 'Solicitar', icon: Icons.send_rounded, onPressed: () {}),
            const SizedBox(height: 10),
            ChambaPrimaryButton(label: 'Proponer precio', isYellow: true, onPressed: () {}),
            const SizedBox(height: 10),
            ChambaSecondaryButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: () {}),
            const SizedBox(height: 10),
            const ChambaPrimaryButton(label: 'Deshabilitado', onPressed: null),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChambaChip(label: 'Seleccionado', selected: _chip, icon: Icons.check_rounded, onTap: () => setState(() => _chip = !_chip)),
              ChambaChip(label: 'Normal', selected: !_chip, onTap: () => setState(() => _chip = !_chip)),
              ChambaChip(label: 'Éxito', selected: false, color: AppTheme.colorSuccess, onTap: () {}),
            ]),
            const SizedBox(height: 16),
            GlassCard(
              child: Row(children: [
                const CategoryIconTile(category: 'Plomería'),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tarjeta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('Superficie blanca, borde suave y sombra lavanda.', style: TextStyle(color: AppTheme.colorMuted, fontSize: 13, fontWeight: FontWeight.w400)),
                  ]),
                ),
                TextButton(onPressed: () {}, child: const Text('Ver')),
              ]),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(hintText: 'Campo de texto', prefixIcon: Icon(Icons.search_rounded))),
            const SizedBox(height: 16),
            const Text('Categorías', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in _categories)
                  SizedBox(
                    width: 72,
                    child: Column(children: [
                      CategoryIconTile(category: c, size: 50),
                      const SizedBox(height: 6),
                      Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.colorMuted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonListTile(margin: EdgeInsets.zero),
            const SizedBox(height: 16),
            const ChambaEmptyState(
              icon: Icons.inbox_rounded,
              title: 'Sin solicitudes',
              message: 'Cuando haya trabajos cerca de ti aparecerán aquí.',
            ),
            Builder(
              builder: (context) => ChambaSecondaryButton(
                label: 'Mostrar snackbar',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guardado correctamente')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
