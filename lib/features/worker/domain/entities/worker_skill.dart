class WorkerSkill {
  const WorkerSkill({required this.name});

  final String name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerSkill && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
