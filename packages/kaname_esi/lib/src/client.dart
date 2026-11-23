/// The client the generated operations extend (design D12 of
/// `esi-client-generator`).
library;

import 'transport.dart';

/// Calls ESI at the pinned compatibility date through one [transport].
///
/// The generated per-tag extensions add one method per operation. The
/// client holds no caller identity: whoever supplies the transport binds
/// which character's token and budget a call uses, and its priority
/// (design D13). Build one cheap client per transport.
final class EsiClient {
  /// Creates a client that sends every request through [transport].
  const EsiClient(this.transport);

  /// The transport every request leaves through.
  final EsiTransport transport;
}
