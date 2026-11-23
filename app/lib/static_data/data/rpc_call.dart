/// A generated call's public answer, without transport or exception text.
sealed class RpcResult<T> {
  const RpcResult();
}

/// A decoded server answer. A server refusal is still an answer.
final class RpcAnswered<T> extends RpcResult<T> {
  /// Carries the generated answer.
  const RpcAnswered(this.value);

  /// The typed wire value.
  final T value;
}

/// No server answer was available at the applicable deadline.
final class RpcUnanswered<T> extends RpcResult<T> {
  /// Represents a timeout, transport failure, or undecodable reply.
  const RpcUnanswered();
}

/// The answer the caller may show and the underlying call it still owns (D8).
///
/// Releasing a single-flight slot depends on [settled], not on the shorter
/// [answer] deadline. A late transport result is available for the caller
/// to fence against the current read, action or setting write.
typedef RpcCall<T> = ({
  Future<RpcResult<T>> answer,
  Future<RpcResult<T>> settled,
});

/// Starts one generated call, optionally shortening the UX answer deadline.
RpcCall<T> startRpc<T>(Future<T> Function() send, {Duration? answerTimeout}) {
  final settled = Future<T>.sync(send).then<RpcResult<T>>(
    RpcAnswered<T>.new,
    onError: (Object _, StackTrace _) => RpcUnanswered<T>(),
  );
  final answer = answerTimeout == null
      ? settled
      : settled.timeout(answerTimeout, onTimeout: RpcUnanswered<T>.new);
  return (answer: answer, settled: settled);
}
