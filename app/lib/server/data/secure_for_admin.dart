/// Whether [address] may carry a Kaname admin session (ADR 0018).
///
/// Remote HTTP remains available for public reads only.
bool isSecureForAdmin(Uri address) {
  final host = address.host;
  if (!address.hasAuthority || host.isEmpty) return false;
  return switch ((address.scheme, host)) {
    ('https', _) || ('http', '127.0.0.1' || '::1' || 'localhost') => true,
    _ => false,
  };
}
