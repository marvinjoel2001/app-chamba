import 'package:flutter/material.dart';

/// Ícono + color de una categoría de servicio, resueltos por palabras clave
/// del nombre (y opcionalmente del campo `icon` que guarda el backend).
///
/// Es la única fuente de íconos de categoría de la app: selector de
/// categoría, habilidades del trabajador, billetera, historial y solicitudes.
class CategoryVisual {
  const CategoryVisual(this.icon, this.color);

  final IconData icon;
  final Color color;

  static const _purple = Color(0xFF7C3AED);
  static const _blue = Color(0xFF2563EB);
  static const _sky = Color(0xFF0284C7);
  static const _teal = Color(0xFF0D9488);
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFD97706);
  static const _orange = Color(0xFFEA580C);
  static const _pink = Color(0xFFDB2777);
  static const _brown = Color(0xFF92400E);
  static const _slate = Color(0xFF475569);
  static const _indigo = Color(0xFF4F46E5);

  static const general = CategoryVisual(Icons.handyman_rounded, _purple);

  /// Reglas en orden de prioridad: la primera palabra clave que aparece gana.
  static const List<(List<String>, CategoryVisual)> _rules = [
    (['plom', 'gasfit', 'fontan', 'cañer', 'caner', 'tuberi', 'plumb'],
        CategoryVisual(Icons.plumbing_rounded, _sky)),
    (['electr', 'eléctr', 'luz', 'cablead', 'enchuf', 'bolt'],
        CategoryVisual(Icons.bolt_rounded, _amber)),
    // Antes que pintura: "carpintería" contiene "pint".
    (['carpint', 'mueble', 'madera', 'ebanist'],
        CategoryVisual(Icons.carpenter_rounded, _brown)),
    (['pint', 'paint'], CategoryVisual(Icons.format_paint_rounded, _pink)),
    (['limpi', 'aseo', 'clean', 'lavand', 'planch'],
        CategoryVisual(Icons.cleaning_services_rounded, _teal)),
    (['jardin', 'jardín', 'poda', 'césped', 'cesped', 'yard', 'plant'],
        CategoryVisual(Icons.yard_rounded, _green)),
    (['mudanz', 'flete', 'transport', 'carga', 'logist', 'shipping'],
        CategoryVisual(Icons.local_shipping_rounded, _orange)),
    (['entrega', 'delivery', 'mandado', 'encomiend', 'mensajer'],
        CategoryVisual(Icons.delivery_dining_rounded, _orange)),
    (['mecán', 'mecan', 'auto', 'vehic', 'vehíc', 'moto', 'llanter'],
        CategoryVisual(Icons.car_repair_rounded, _slate)),
    (['albañ', 'alban', 'construc', 'obra', 'cemento', 'ladrill'],
        CategoryVisual(Icons.construction_rounded, _amber)),
    (['techo', 'tejado', 'impermeab'], CategoryVisual(Icons.roofing_rounded, _brown)),
    (['cerraj', 'llave', 'candado', 'chapa'],
        CategoryVisual(Icons.key_rounded, _slate)),
    (['refriger', 'aire acond', 'climatiz', 'calefac', 'hvac'],
        CategoryVisual(Icons.ac_unit_rounded, _sky)),
    (['electrodom', 'lavadora', 'cocina a gas', 'heladera'],
        CategoryVisual(Icons.kitchen_rounded, _indigo)),
    (['comput', 'tecnolog', 'informát', 'informat', 'celular', 'redes', 'wifi', 'software', 'pc'],
        CategoryVisual(Icons.computer_rounded, _indigo)),
    (['soldad', 'herrer', 'metal'],
        CategoryVisual(Icons.hardware_rounded, _slate)),
    (['vidri', 'cristal', 'ventan'], CategoryVisual(Icons.window_rounded, _sky)),
    (['piso', 'cerámic', 'ceramic', 'azulej', 'porcelan'],
        CategoryVisual(Icons.grid_view_rounded, _brown)),
    (['belleza', 'peluq', 'estét', 'estet', 'uñas', 'manicur', 'maquill', 'barber'],
        CategoryVisual(Icons.content_cut_rounded, _pink)),
    (['cocin', 'chef', 'comida', 'catering', 'reposter', 'gastron'],
        CategoryVisual(Icons.restaurant_rounded, _orange)),
    (['niñer', 'niner', 'cuidado', 'adulto mayor', 'enfermer', 'salud'],
        CategoryVisual(Icons.child_friendly_rounded, _pink)),
    (['mascot', 'perro', 'gato', 'veterin', 'paseo'],
        CategoryVisual(Icons.pets_rounded, _amber)),
    (['clase', 'tutor', 'profes', 'enseñ', 'idioma', 'educa'],
        CategoryVisual(Icons.school_rounded, _blue)),
    (['foto', 'video', 'filmac'], CategoryVisual(Icons.photo_camera_rounded, _indigo)),
    (['evento', 'fiesta', 'decorac', 'música', 'musica', 'dj'],
        CategoryVisual(Icons.celebration_rounded, _pink)),
    (['costur', 'sastre', 'ropa', 'confecc'],
        CategoryVisual(Icons.checkroom_rounded, _purple)),
    (['segur', 'vigil', 'guardia', 'cámara', 'camara'],
        CategoryVisual(Icons.security_rounded, _slate)),
    (['fumig', 'plaga', 'desinfec'], CategoryVisual(Icons.pest_control_rounded, _green)),
    (['diseñ', 'disen', 'gráfic', 'grafic', 'arquitect'],
        CategoryVisual(Icons.design_services_rounded, _purple)),
    (['mantenim', 'reparac', 'arreglo', 'instalac'],
        CategoryVisual(Icons.build_rounded, _blue)),
    (['general', 'otro', 'varios'], general),
  ];

  /// Resuelve por [name]; si no hay coincidencia prueba con [iconHint].
  static CategoryVisual of(String? name, {String? iconHint}) {
    final value = (name ?? '').toLowerCase().trim();
    final hint = (iconHint ?? '').toLowerCase().trim();
    for (final source in [value, hint]) {
      if (source.isEmpty) continue;
      for (final (keywords, visual) in _rules) {
        if (keywords.any(source.contains)) return visual;
      }
    }
    return general;
  }
}

/// Cuadrado redondeado tintado con el ícono de la categoría.
class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile({
    required this.category,
    this.iconHint,
    this.size = 44,
    super.key,
  });

  final String? category;
  final String? iconHint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(category, iconHint: iconHint);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(visual.icon, color: visual.color, size: size * 0.52),
    );
  }
}
