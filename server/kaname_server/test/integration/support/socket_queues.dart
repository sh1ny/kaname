import 'dart:io';

/// Whether [receiveQueueBytes] can read the kernel's socket tables here.
bool get canReadSocketQueues =>
    Platform.isLinux && File('/proc/net/tcp').existsSync();

/// The bytes that arrived, and that the process has not read yet, in the
/// established sockets connected to the server on [serverPort] (Linux: the
/// `rx_queue` column of `/proc/net/tcp` and `/proc/net/tcp6`).
///
/// A peer that reads drains its queue at once; a queue that stays above zero
/// is a peer whose reads are held, with a full receive buffer, so the
/// server's sends cannot go on.
int receiveQueueBytes(int serverPort) {
  var total = 0;
  for (final table in const ['/proc/net/tcp', '/proc/net/tcp6']) {
    final file = File(table);
    if (!file.existsSync()) continue;
    for (final line in file.readAsLinesSync().skip(1)) {
      final fields = line.trim().split(RegExp(r'\s+'));
      // sl local_address rem_address st tx_queue:rx_queue ...
      if (fields.length < 5 || fields[3] != '01') continue;
      final localPort = int.parse(fields[1].split(':').last, radix: 16);
      final remotePort = int.parse(fields[2].split(':').last, radix: 16);
      if (remotePort != serverPort || localPort == serverPort) continue;
      total += int.parse(fields[4].split(':').last, radix: 16);
    }
  }
  return total;
}
