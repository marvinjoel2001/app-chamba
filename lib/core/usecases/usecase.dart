import '../errors/result.dart';

abstract class UseCase<ReturnType, Params> {
  Future<Result<ReturnType>> call(Params params);
}

class NoParams {
  const NoParams();
}
