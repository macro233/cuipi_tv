class VideoSourceModel {
  final String id;
  String name;
  String url;
  String type; // 'cms', 'tvbox', 'live', 'custom'
  String desc;
  int pingMs;
  bool isEnabled;
  bool isBuiltIn;

  VideoSourceModel({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.desc = '',
    this.pingMs = 28,
    this.isEnabled = true,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type,
        'desc': desc,
        'pingMs': pingMs,
        'isEnabled': isEnabled,
        'isBuiltIn': isBuiltIn,
      };

  factory VideoSourceModel.fromJson(Map<String, dynamic> json) =>
      VideoSourceModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        type: json['type']?.toString() ?? 'cms',
        desc: json['desc']?.toString() ?? '',
        pingMs: (json['pingMs'] as num?)?.toInt() ?? 30,
        isEnabled: json['isEnabled'] as bool? ?? true,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      );

  String get typeLabel {
    switch (type) {
      case 'cms':
        return 'CMS 采集';
      case 'tvbox':
        return 'TVBox 仓';
      case 'live':
        return 'IPTV 直播';
      default:
        return '自定义源';
    }
  }
}
