import 'result.dart';

extension ResultX<T> on Result<T> {
  T getOrThrow() {
    final value = this;
    if (value is Success<T>) {
      return value.value;
    }
    throw Exception((value as Error<T>).failure.message);
  }
}
