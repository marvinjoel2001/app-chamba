import 'failure.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    final value = this;
    if (value is Success<T>) {
      return onSuccess(value.value);
    }
    return onFailure((value as Error<T>).failure);
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

class Error<T> extends Result<T> {
  const Error(this.failure);

  final Failure failure;
}
