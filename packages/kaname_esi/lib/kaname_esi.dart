/// Typed access to EVE Online's ESI at one pinned compatibility date.
///
/// The client builds typed requests and reads typed results; it sends
/// nothing itself. Every request leaves through an `EsiTransport` its caller
/// injects (constraint C1 of `esi-client-generator`, ADR 0007).
///
/// ESI's int64 values are Dart [int]s. On the web an [int] is exact only up
/// to 2^53, so this client is not meant for web builds: the web app is
/// connected-only and the server holds the tokens and makes ESI calls
/// (ADR 0005; constraint C3 of `esi-client-generator`).
library;

export 'src/call.dart';
export 'src/catalogue_types.dart';
export 'src/client.dart';
export 'src/json.dart';
export 'src/result.dart';
export 'src/transport.dart';
export 'src/values.dart';
