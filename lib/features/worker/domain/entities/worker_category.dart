class WorkerCategory {
  const WorkerCategory({
    required this.name,
    this.id,
    this.description,
    this.icon,
    this.parentId,
    this.active = true,
  });

  final String name;
  final String? id;
  final String? description;
  final String? icon;
  final String? parentId;
  final bool active;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerCategory &&
        other.name == name &&
        other.id == id &&
        other.description == description &&
        other.icon == icon &&
        other.parentId == parentId &&
        other.active == active;
  }

  @override
  int get hashCode =>
      Object.hash(name, id, description, icon, parentId, active);
}
