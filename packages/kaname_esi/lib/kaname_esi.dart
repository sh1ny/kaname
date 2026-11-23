/// Typed access to EVE Online's ESI at one pinned compatibility date.
///
/// The client builds typed requests and reads typed results; it sends
/// nothing itself. Every request leaves through an `EsiTransport` its caller
/// injects (constraint C1 of `esi-client-generator`, ADR 0007).
library;
