enum TransferDirection { inbound, outbound }

enum TransferStatus { offering, transferring, done, rejected, failed }

class TransferProgress {
  const TransferProgress({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.fileName,
    required this.fileSize,
    required this.transferred,
    required this.direction,
    required this.status,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String fileName;
  final int fileSize;
  final int transferred;
  final TransferDirection direction;
  final TransferStatus status;

  double get ratio => fileSize == 0 ? 0 : transferred / fileSize;

  TransferProgress copyWith({
    int? transferred,
    TransferStatus? status,
    int? fileSize,
    String? fileName,
  }) {
    return TransferProgress(
      id: id,
      peerId: peerId,
      peerName: peerName,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      transferred: transferred ?? this.transferred,
      direction: direction,
      status: status ?? this.status,
    );
  }
}
