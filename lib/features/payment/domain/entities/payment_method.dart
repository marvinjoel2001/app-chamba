class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.icon,
    this.color = '#4CAF50',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String code;
  final String? description;
  final String? icon;
  final String color;
  final bool isActive;
  final int sortOrder;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String? ?? '#4CAF50',
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'icon': icon,
      'color': color,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }
}
