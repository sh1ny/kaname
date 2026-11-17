/// A small xorshift32 generator that gives the same stream on the VM, dart2js
/// and dart2wasm.
///
/// Every shift-left step is masked to 32 bits, so no intermediate value leaves
/// the range that all three compilers compute identically.
library;

const int _mask = 0xFFFFFFFF;

/// The xorshift32 generator of Marsaglia (shifts 13, 17 and 5).
final class Xorshift32 {
  /// Creates a generator from a nonzero 32-bit [seed].
  ///
  /// Throws an [ArgumentError] if [seed] is zero once masked to 32 bits, since
  /// zero is the generator's fixed point.
  Xorshift32(int seed) : _state = seed & _mask {
    if (_state == 0) throw ArgumentError.value(seed, 'seed', 'must be nonzero');
  }

  int _state;

  /// Returns the next unsigned 32-bit value.
  int next() {
    var state = _state;
    state ^= (state << 13) & _mask;
    state ^= state >> 17;
    state ^= (state << 5) & _mask;
    return _state = state;
  }

  /// Returns a value in `0..bound-1`.
  ///
  /// The modulo bias is irrelevant at the spike's bounds. [bound] must be
  /// positive.
  int nextInt(int bound) => next() % bound;
}
