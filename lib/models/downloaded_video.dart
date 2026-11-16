class DownloadedVideo {
  final String id;
  final String title;
  final String artist;
  final String filePath;
  final String artworkUrl;
  final int sizeBytes;
  final Duration duration;
  final DateTime downloadedAt;

  const DownloadedVideo({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.artworkUrl = '',
    this.sizeBytes = 0,
    this.duration = Duration.zero,
    required this.downloadedAt,
  });

  String get sizeFormatted {
    if (sizeBytes <= 0) return '0 MB';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'filePath': filePath,
      'artworkUrl': artworkUrl,
      'sizeBytes': sizeBytes,
      'durationMs': duration.inMilliseconds,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory DownloadedVideo.fromMap(Map<String, dynamic> map) {
    return DownloadedVideo(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Video',
      artist: map['artist']?.toString() ?? 'Sine Video',
      filePath: map['filePath']?.toString() ?? '',
      artworkUrl: map['artworkUrl']?.toString() ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      downloadedAt: DateTime.tryParse(map['downloadedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
