class Song {
  final String title;
  final String artist;
  final String videoId;
  final String cover;
  final String duration;
  final String album;
  final String albumId;
  final String artistId;
  final String ytUrl;

  const Song({
    required this.title,
    required this.artist,
    required this.videoId,
    required this.cover,
    this.duration = '',
    this.album = '',
    this.albumId = '',
    this.artistId = '',
    this.ytUrl = '',
  });

  String get url => ytUrl.isNotEmpty ? ytUrl : 'https://www.youtube.com/watch?v=$videoId';

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'videoId': videoId,
        'cover': cover,
        'duration': duration,
        'album': album,
        'albumId': albumId,
        'artistId': artistId,
        'ytUrl': ytUrl,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        title: '${json['title'] ?? ''}',
        artist: '${json['artist'] ?? ''}',
        videoId: '${json['videoId'] ?? json['id'] ?? ''}',
        cover: '${json['cover'] ?? json['thumbnail'] ?? ''}',
        duration: '${json['duration'] ?? ''}',
        album: '${json['album'] ?? ''}',
        albumId: '${json['albumId'] ?? json['album_id'] ?? ''}',
        artistId: '${json['artistId'] ?? json['artist_id'] ?? ''}',
        ytUrl: '${json['ytUrl'] ?? json['yt_url'] ?? json['url'] ?? ''}',
      );
}

class LyricLine {
  final double time;
  final String text;
  final String translation;

  const LyricLine(this.time, this.text, {this.translation = ''});
}
