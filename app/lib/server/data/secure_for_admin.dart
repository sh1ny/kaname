/// Whether [address] is safe for sending the install admin key (D24).
///
/// Public reads may still use HTTP to another host. Only the three explicit
/// loopback addresses are allowed to carry a key over HTTP.
bool isSecureForAdmin(Uri address) {
  final host = address.host;
  if (!address.hasAuthority || host.isEmpty) return false;
  return switch ((address.scheme, host)) {
    ('https', _) || ('http', '127.0.0.1' || '::1' || 'localhost') => true,
    _ => false,
  };
}
