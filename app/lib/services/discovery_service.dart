import 'dart:async';
import 'dart:io';

class DiscoveryResult {
  final String host;
  final int port;
  DiscoveryResult(this.host, this.port);
}

class DiscoveryService {
  static const int _port = 8765;
  static const Duration _timeout = Duration(milliseconds: 400);

  /// Scan current subnet for open port 8765
  static Future<List<DiscoveryResult>> scan({
    void Function(int done, int total)? onProgress,
  }) async {
    final localIp = await _getLocalIp();
    if (localIp == null) return [];

    final parts = localIp.split('.');
    if (parts.length != 4) return [];
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    final results = <DiscoveryResult>[];
    final total = 254;
    int done = 0;

    // Scan in batches of 30 parallel
    for (int batch = 1; batch <= 254; batch += 30) {
      final futures = <Future>[];
      for (int i = batch; i < batch + 30 && i <= 254; i++) {
        final ip = '$subnet.$i';
        futures.add(
          _checkPort(ip, _port).then((ok) {
            if (ok) results.add(DiscoveryResult(ip, _port));
            done++;
            onProgress?.call(done, total);
          }),
        );
      }
      await Future.wait(futures);
    }

    return results;
  }

  static Future<bool> _checkPort(String host, int port) async {
    try {
      final sock = await Socket.connect(host, port, timeout: _timeout);
      await sock.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }
}
