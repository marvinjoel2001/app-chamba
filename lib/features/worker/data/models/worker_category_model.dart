import '../../domain/entities/worker_category.dart';

class WorkerCategoryModel extends WorkerCategory {
  const WorkerCategoryModel({
    required super.name,
    super.id,
    super.description,
    super.icon,
    super.parentId,
    super.active,
  });

  factory WorkerCategoryModel.fromJson(Map<String, dynamic> json) {
    return WorkerCategoryModel(
      id: json['id']?.toString(),
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      parentId: json['parentId']?.toString(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'parentId': parentId,
      'active': active,
    };
  }
}
