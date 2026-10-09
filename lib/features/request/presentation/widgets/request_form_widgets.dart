import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const requestInk = Color(0xFF0B1033);
const requestMuted = Color(0xFF858AA5);
const requestPurple = Color(0xFF7B35FF);
const requestBlue = Color(0xFF288AFF);
const requestGreen = Color(0xFF09A447);
const requestOrange = Color(0xFFFFA000);

class RequestStepCard extends StatelessWidget {
  const RequestStepCard(
      {super.key,
      required this.number,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.child,
      this.illustration});
  final int number;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: .065),
                color.withValues(alpha: .02)
              ]),
          border: Border.all(color: color.withValues(alpha: .12)),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: .035),
                blurRadius: 22,
                offset: const Offset(0, 9))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(children: [
            if (illustration != null &&
                MediaQuery.sizeOf(context).width >= 360 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.15)
              Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: ExcludeSemantics(
                      child: IgnorePointer(child: illustration!))),
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                child: Row(children: [
                  Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [color.withValues(alpha: .8), color])),
                      child: Text('$number',
                          style: const TextStyle(
                              height: 1.2,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                height: 1.2,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: requestInk)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                height: 1.2,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: requestMuted)),
                      ])),
                ])),
          ]),
          Container(
              margin: const EdgeInsets.fromLTRB(5, 0, 5, 5),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(17)),
              child: child),
        ]),
      );
}

class RequestIconTile extends StatelessWidget {
  const RequestIconTile(
      {super.key, required this.icon, required this.color, this.size = 30});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(size * .28)),
      child: Icon(icon, color: color, size: size * .55));
}

class RequestFieldLabel extends StatelessWidget {
  const RequestFieldLabel(
      {super.key, required this.text, required this.icon, required this.color});
  final String text;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        RequestIconTile(icon: icon, color: color, size: 23),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    height: 1.2,
                    color: requestInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
      ]);
}

class RequestChoiceTile extends StatelessWidget {
  const RequestChoiceTile(
      {super.key,
      required this.title,
      this.subtitle,
      required this.leading,
      required this.onTap,
      this.color = requestPurple,
      this.background = Colors.white,
      this.borderColor,
      this.extra,
      this.showArrow = true});
  final String title;
  final String? subtitle;
  final Widget leading;
  final VoidCallback? onTap;
  final Color color;
  final Color background;
  final Color? borderColor;
  final Widget? extra;
  final bool showArrow;
  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor ?? const Color(0xFFE8E8F2))),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.all(7),
                child: Row(children: [
                  leading,
                  const SizedBox(width: 11),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                height: 1.2,
                                color: requestInk,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle!,
                              style: const TextStyle(
                                  height: 1.2,
                                  color: requestMuted,
                                  fontSize: 11))
                        ],
                        if (extra != null) ...[
                          const SizedBox(height: 6),
                          extra!
                        ],
                      ])),
                  if (showArrow) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 21, color: color)
                  ],
                ]))),
      );
}

class RequestDateTile extends StatelessWidget {
  const RequestDateTile(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE7E8F2))),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                child: Row(children: [
                  RequestIconTile(icon: icon, color: requestBlue, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: const TextStyle(
                                height: 1.2,
                                fontSize: 10,
                                color: requestMuted)),
                        const SizedBox(height: 2),
                        Text(value,
                            style: const TextStyle(
                                height: 1.2,
                                fontSize: 12.5,
                                color: requestInk,
                                fontWeight: FontWeight.w600)),
                      ])),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: requestMuted),
                ]))),
      );
}

/// The stepper and manual entry both write to the existing request controller.
class RequestQuantityField extends StatelessWidget {
  const RequestQuantityField(
      {super.key,
      required this.label,
      required this.controller,
      this.enabled = true});
  final String label;
  final TextEditingController controller;
  final bool enabled;
  void _change(int delta) {
    final current = int.tryParse(controller.text) ?? 1;
    final next = current + delta < 1 ? 1 : current + delta;
    controller.value = TextEditingValue(
        text: '$next',
        selection: TextSelection.collapsed(offset: '$next'.length));
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFFF8F3FF),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  height: 1.2,
                  fontSize: 10,
                  color: Color(0xFF606581),
                  fontWeight: FontWeight.w500)),
          Row(children: [
            IconButton(
                tooltip: 'Reducir $label',
                onPressed: enabled ? () => _change(-1) : null,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF0E7FF)),
                icon: const Icon(Icons.remove_rounded,
                    color: requestPurple, size: 20)),
            Expanded(
                child: TextField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        height: 1.2,
                        color: requestInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.only(top: 3),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        semanticCounterText: label))),
            IconButton(
                tooltip: 'Aumentar $label',
                onPressed: enabled ? () => _change(1) : null,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFECE0FF)),
                icon: const Icon(Icons.add_rounded,
                    color: requestPurple, size: 20)),
          ]),
        ]),
      );
}

class RequestAmountField extends StatelessWidget {
  const RequestAmountField(
      {super.key,
      required this.label,
      required this.controller,
      this.enabled = true});
  final String label;
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFEFFCF3),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              if (constraints.maxWidth >= 150) ...[
                const RequestIconTile(
                    icon: Icons.savings_rounded, color: requestGreen, size: 34),
                const SizedBox(width: 10),
              ],
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: const TextStyle(
                            height: 1.2,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF575C70))),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Text('Bs ',
                          style: TextStyle(
                              height: 1.2,
                              color: requestGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Expanded(
                          child: TextField(
                              controller: controller,
                              enabled: enabled,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'))
                              ],
                              style: const TextStyle(
                                  height: 1.2,
                                  color: requestGreen,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  semanticCounterText: label))),
                    ]),
                  ])),
            ]),
          ));
}
