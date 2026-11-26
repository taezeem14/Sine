import 'package:flutter/foundation.dart';
import 'song.dart';

@immutable
class Playlist {
  final String id;
  final String title;
  final String description;
  final List<Song> songs;
  final DateTime createdAt;
  final String? coverUrl;
  final String? continuationToken;
  final String? nextVideoId;
  final String? nextParams;

  const Playlist({
    required this.id,
    required this.title,
    this.description = '',
    required this.songs,
    required this.createdAt,
    this.coverUrl,
    this.continuationToken,
    this.nextVideoId,
    this.nextParams,
  });

  static const Object _unset = Object();

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    List<Song>? songs,
    DateTime? createdAt,
    String? coverUrl,
    Object? continuationToken = _unset,
    Object? nextVideoId = _unset,
    Object? nextParams = _unset,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      coverUrl: coverUrl ?? this.coverUrl,
      continuationToken: identical(continuationToken, _unset)
          ? this.continuationToken
          : continuationToken as String?,
      nextVideoId: identical(nextVideoId, _unset)
          ? this.nextVideoId
          : nextVideoId as String?,
      nextParams: identical(nextParams, _unset)
          ? this.nextParams
          : nextParams as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'songs': songs.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'coverUrl': coverUrl,
      'cover_url': coverUrl,
      'continuationToken': continuationToken,
      'continuation_token': continuationToken,
      if (nextVideoId != null) 'nextVideoId': nextVideoId,
      if (nextParams != null) 'nextParams': nextParams,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    final rawSongs = map['songs'] ?? map['tracks'] ?? map['items'];
    final List<Song> songList = rawSongs is List
        ? rawSongs
            .whereType<Map>()
            .map((item) => Song.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : [];

    final rawCover = (map['coverUrl'] ?? map['cover_url'])?.toString();
    final rawToken = (map['continuationToken'] ?? map['continuation_token'])?.toString();
    final rawNextVid = (map['nextVideoId'] ?? map['next_video_id'])?.toString();
    final rawNextParams = (map['nextParams'] ?? map['next_params'])?.toString();
    final rawTitle = (map['title'] ?? map['name'])?.toString();

    return Playlist(
      id: map['id']?.toString() ?? '',
      title: (rawTitle != null && rawTitle.trim().isNotEmpty) ? rawTitle.trim() : 'Untitled Playlist',
      description: map['description']?.toString() ?? '',
      songs: songList,
      createdAt: DateTime.tryParse((map['createdAt'] ?? map['created_at'])?.toString() ?? '') ??
          DateTime.now(),
      coverUrl: (rawCover != null && rawCover.isNotEmpty && rawCover != 'null') ? rawCover : null,
      continuationToken: (rawToken != null && rawToken.isNotEmpty && rawToken != 'null') ? rawToken : null,
      nextVideoId: (rawNextVid != null && rawNextVid.isNotEmpty && rawNextVid != 'null') ? rawNextVid : null,
      nextParams: (rawNextParams != null && rawNextParams.isNotEmpty && rawNextParams != 'null') ? rawNextParams : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          coverUrl == other.coverUrl &&
          continuationToken == other.continuationToken &&
          listEquals(songs, other.songs);

  @override
  int get hashCode => Object.hash(id, title, description, coverUrl, continuationToken);

  @override
  String toString() => 'Playlist(id: $id, title: $title, ${songs.length} tracks)';
}
