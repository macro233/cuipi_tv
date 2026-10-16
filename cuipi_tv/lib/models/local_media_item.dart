class LocalMediaItem {
  final String id;
  String title;
  final String filename;
  final String path;
  final String size;
  final String res;
  String year;
  String score;
  String poster;
  String? localPosterPath;
  final bool isLocal;
  bool hasScrapedCover;
  String cat;
  String desc;
  final String url;

  LocalMediaItem({
    required this.id,
    required this.title,
    required this.filename,
    required this.path,
    required this.size,
    required this.res,
    required this.year,
    required this.score,
    required this.poster,
    this.localPosterPath,
    this.isLocal = true,
    this.hasScrapedCover = false,
    required this.cat,
    required this.desc,
    required this.url,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filename': filename,
      'path': path,
      'size': size,
      'res': res,
      'year': year,
      'score': score,
      'poster': poster,
      'localPosterPath': localPosterPath,
      'isLocal': isLocal,
      'hasScrapedCover': hasScrapedCover,
      'cat': cat,
      'desc': desc,
      'url': url,
    };
  }

  factory LocalMediaItem.fromJson(Map<String, dynamic> json) {
    return LocalMediaItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      filename: json['filename'] ?? '',
      path: json['path'] ?? '',
      size: json['size'] ?? '',
      res: json['res'] ?? '4K 原画',
      year: json['year'] ?? '',
      score: json['score'] ?? '',
      poster: json['poster'] ?? '',
      localPosterPath: json['localPosterPath'],
      isLocal: json['isLocal'] ?? true,
      hasScrapedCover: json['hasScrapedCover'] ?? false,
      cat: json['cat'] ?? '',
      desc: json['desc'] ?? '',
      url: json['url'] ?? '',
    );
  }
}
