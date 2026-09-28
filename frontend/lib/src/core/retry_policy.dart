/// Ambiguous transport failure must never repeat a command that may have committed.
bool mayRetryTransport(String method) => const {'GET', 'HEAD'}.contains(method.toUpperCase());
