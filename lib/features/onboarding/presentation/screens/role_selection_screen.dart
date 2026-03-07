import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/chamba_widgets.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String selectedRole = 'client';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChambaBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 26),
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.colorSurfaceSoft,
                        border: Border.all(color: const Color(0xFFCBD4E9)),
                      ),
                      child: const Icon(Icons.handshake, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'CHAMBA',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ENCUENTRA TRABAJO. ENCUENTRA TRABAJADORES.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.colorHighlight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        label: 'Necesito un\ntrabajador',
                        icon: Icons.person_search,
                        selected: selectedRole == 'client',
                        onTap: () => setState(() => selectedRole = 'client'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        label: 'Soy\ntrabajador',
                        icon: Icons.handyman,
                        selected: selectedRole == 'worker',
                        onTap: () => setState(() => selectedRole = 'worker'),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ChambaPrimaryButton(
                  label: 'Continuar',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LoginScreen(role: selectedRole),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
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
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 218,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppTheme.colorPrimary.withValues(alpha: 0.12) : AppTheme.colorSurfaceSoft,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppTheme.colorPrimary : const Color(0xFFCBD4E9),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x336B2BBE),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.colorPrimary.withValues(alpha: 0.18),
              child: Icon(icon, size: 34, color: AppTheme.colorPrimaryDark),
            ),
            const SizedBox(height: 18),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


