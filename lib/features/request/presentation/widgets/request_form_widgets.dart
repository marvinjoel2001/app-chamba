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

/// Monto que pone el cliente. Se ve como un campo para escribir (borde,
/// lápiz y "Toca para cambiar") y todo el recuadro abre el teclado.
class RequestAmountField extends StatefulWidget {
  const RequestAmountField(
      {super.key,
      required this.label,
      required this.controller,
      this.enabled = true});
  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  State<RequestAmountField> createState() => _RequestAmountFieldState();
}

class _RequestAmountFieldState extends State<RequestAmountField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
    // Al entrar se selecciona todo: escribir reemplaza el monto sugerido.
    if (_focus.hasFocus) {
      widget.controller.selection = TextSelection(
          baseOffset: 0, extentOffset: widget.controller.text.length);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? _focus.requestFocus : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                decoration: BoxDecoration(
                    color: focused ? Colors.white : const Color(0xFFEFFCF3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: focused
                            ? requestGreen
                            : requestGreen.withValues(alpha: .35),
                        width: focused ? 1.6 : 1.1)),
                child: Row(children: [
                  if (constraints.maxWidth >= 190) ...[
                    const RequestIconTile(
                        icon: Icons.savings_rounded,
                        color: requestGreen,
                        size: 34),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                                  controller: widget.controller,
                                  focusNode: _focus,
                                  enabled: widget.enabled,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'))
                                  ],
                                  cursorColor: requestGreen,
                                  style: const TextStyle(
                                      height: 1.2,
                                      color: requestGreen,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800),
                                  decoration: InputDecoration(
                                      isDense: true,
                                      filled: false,
                                      hintText: '0',
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      semanticCounterText: widget.label))),
                        ]),
                        if (!focused) ...[
                          const SizedBox(height: 2),
                          const Text('Toca para cambiar',
                              style: TextStyle(
                                  height: 1.2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: requestGreen)),
                        ],
                      ])),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: focused
                            ? requestGreen
                            : requestGreen.withValues(alpha: .12),
                        shape: BoxShape.circle),
                    child: Icon(
                        focused ? Icons.check_rounded : Icons.edit_rounded,
                        size: 16,
                        color: focused ? Colors.white : requestGreen),
                  ),
                ]),
              ),
            ));
  }
}

/// Fotos del trabajo: un recuadro grande para agregar y las miniaturas al
/// lado. Las fotos ayudan al trabajador a entender el trabajo y ofertar mejor.
class RequestPhotoPicker extends StatelessWidget {
  const RequestPhotoPicker({
    super.key,
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
  });

  final List<Uint8List> images;
  final int maxImages;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool enabled;

  static const double _tile = 76;

  @override
  Widget build(BuildContext context) {
    final canAdd = enabled && images.length < maxImages;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
            child: Text('Fotos del trabajo',
                style: TextStyle(
                    height: 1.2,
                    color: requestInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700))),
        Text('${images.length}/$maxImages',
            style: const TextStyle(
                height: 1.2,
                color: requestMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 3),
      const Text('Con una foto los trabajadores entienden mejor y te ofertan más rápido.',
          style: TextStyle(height: 1.3, color: requestMuted, fontSize: 11)),
      const SizedBox(height: 8),
      SizedBox(
        height: _tile,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (images.length < maxImages)
              Semantics(
                button: true,
                label: 'Agregar foto del trabajo',
                child: InkWell(
                  onTap: canAdd ? onAdd : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    width: images.isEmpty ? 150 : _tile,
                    height: _tile,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F0FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: requestPurple.withValues(alpha: .45),
                          width: 1.4),
                    ),
                    child: images.isEmpty
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.add_a_photo_rounded,
                                    color: requestPurple, size: 24),
                                SizedBox(width: 8),
                                Text('Agregar\nfoto',
                                    style: TextStyle(
                                        height: 1.15,
                                        color: requestPurple,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                              ])
                        : const Icon(Icons.add_rounded,
                            color: requestPurple, size: 28),
                  ),
                ),
              ),
            for (var index = 0; index < images.length; index++) ...[
              const SizedBox(width: 8),
              Stack(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(images[index],
                        width: _tile, height: _tile, fit: BoxFit.cover)),
                Positioned(
                    top: 3,
                    right: 3,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: enabled ? () => onRemove(index) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                              semanticLabel: 'Quitar foto ${index + 1}'),
                        ),
                      ),
                    )),
              ]),
            ],
          ],
        ),
      ),
    ]);
  }
}
