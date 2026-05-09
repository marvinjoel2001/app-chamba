class WorkerAvailability {
  const WorkerAvailability({required this.available});

  final bool available;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerAvailability && other.available == available;
  }

  @override
  int get hashCode => available.hashCode;
}
