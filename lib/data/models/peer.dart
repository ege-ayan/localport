class Peer {
  const Peer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.trusted = false,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final bool trusted;

  Peer copyWith({bool? trusted, String? name, String? host, int? port}) {
    return Peer(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      trusted: trusted ?? this.trusted,
    );
  }

  String get endpoint => '$host:$port';
}
