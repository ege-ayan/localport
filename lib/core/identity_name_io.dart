import 'dart:io';

String defaultDeviceName() {
  try {
    final host = Platform.localHostname.trim();
    return host.isEmpty ? 'LocalPort' : host;
  } on Object {
    return 'LocalPort';
  }
}
