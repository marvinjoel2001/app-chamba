import '../../domain/entities/worker_skill.dart';

class WorkerSkillModel extends WorkerSkill {
  const WorkerSkillModel({required super.name});

  factory WorkerSkillModel.fromJson(Map<String, dynamic> json) {
    return WorkerSkillModel(name: json['name']?.toString() ?? '');
  }

  factory WorkerSkillModel.fromDynamic(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return WorkerSkillModel.fromJson(raw);
    }
    return WorkerSkillModel(name: raw?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'name': name};
}
