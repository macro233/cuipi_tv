import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/local_media_item.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  Directory? _cacheDir;
  File? _dbFile;
  bool _isInitialized = false;

  final Map<String, String> _memoryUrlToFilePath = {};

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${docsDir.path}/poster_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _dbFile = File('${docsDir.path}/scraped_local_media.json');
      _isInitialized = true;
    } catch (e) {
      debugPrint("MediaCacheService init error (fallback to local dir): $e");
      try {
        final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
        final appDir = Directory('$home/.cuipi_tv');
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        _cacheDir = Directory('${appDir.path}/poster_cache');
        if (!await _cacheDir!.exists()) {
          await _cacheDir!.create(recursive: true);
        }
        _dbFile = File('${appDir.path}/scraped_local_media.json');
        _isInitialized = true;
      } catch (e2) {
        debugPrint("MediaCacheService fallback init error: $e2");
      }
    }
  }

  /// 获取 URL 对应的本地缓存文件对象
  File? getCacheFile(String url) {
    if (_cacheDir == null || url.isEmpty) return null;
    final hash = md5.convert(utf8.encode(url)).toString();
    return File('${_cacheDir!.path}/$hash.jpg');
  }

  /// 检查某 URL 是否已经完整缓存到本地硬盘
  bool isUrlCached(String url) {
    if (url.isEmpty) return false;
    if (_memoryUrlToFilePath.containsKey(url)) {
      final f = File(_memoryUrlToFilePath[url]!);
      if (f.existsSync() && f.lengthSync() > 500) return true;
    }
    final file = getCacheFile(url);
    if (file != null && file.existsSync() && file.lengthSync() > 500) {
      _memoryUrlToFilePath[url] = file.path;
      return true;
    }
    return false;
  }

  /// 异步下载网络图片并持久化保存到本地硬盘
  Future<File?> downloadAndCache(String url) async {
    if (url.isEmpty || !url.startsWith('http')) return null;
    await init();
    if (_cacheDir == null) return null;

    final targetFile = getCacheFile(url);
    if (targetFile == null) return null;

    if (targetFile.existsSync() && targetFile.lengthSync() > 500) {
      _memoryUrlToFilePath[url] = targetFile.path;
      return targetFile;
    }

    // 1. 尝试直连下载（附带反盗链保护头）
    try {
      String cleanUrl = url;
      if (cleanUrl.startsWith('http://')) {
        cleanUrl = 'https://${cleanUrl.substring(7)}';
      }
      final isDouban = cleanUrl.contains('doubanio.com') || cleanUrl.contains('douban.com');

      final res = await http.get(
        Uri.parse(cleanUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
          'Accept': 'image/*,*/*;q=0.8',
          if (isDouban) 'Referer': 'https://movie.douban.com/',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && res.bodyBytes.length > 500) {
        await targetFile.writeAsBytes(res.bodyBytes);
        _memoryUrlToFilePath[url] = targetFile.path;
        return targetFile;
      }
    } catch (e) {
      debugPrint("Direct download failed for $url: $e");
    }

    // 2. 直连失败，通过 weserv 全球 CDN 镜像代理拉取
    try {
      final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&default=1';
      final res = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && res.bodyBytes.length > 500) {
        await targetFile.writeAsBytes(res.bodyBytes);
        _memoryUrlToFilePath[url] = targetFile.path;
        return targetFile;
      }
    } catch (e) {
      debugPrint("Proxy download failed for $url: $e");
    }

    return null;
  }

  /// 读取本地持久化存储的影视资源库元数据（启动零等待）
  Future<List<LocalMediaItem>> loadPersistedMediaList() async {
    await init();
    try {
      if (_dbFile != null && await _dbFile!.exists()) {
        final content = await _dbFile!.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          final items = jsonList.map((j) => LocalMediaItem.fromJson(j)).toList();
          if (items.isNotEmpty) {
            return items;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading persisted media list: $e");
    }

    // 默认内置经典片单
    final defaultList = getDefaultMediaList();
    await saveMediaList(defaultList);
    return defaultList;
  }

  /// 将影视列表保存至本地硬盘持久化文件
  Future<void> saveMediaList(List<LocalMediaItem> list) async {
    await init();
    try {
      if (_dbFile != null) {
        final jsonList = list.map((item) => item.toJson()).toList();
        await _dbFile!.writeAsString(jsonEncode(jsonList));
      }
    } catch (e) {
      debugPrint("Error saving media list: $e");
    }
  }

  /// 内置本地高清影视列表（均附带本地已打包的高清海报，零网络亦能秒出）
  List<LocalMediaItem> getDefaultMediaList() {
    return [
      LocalMediaItem(
        id: 'loc_1',
        title: '三体 第一季 全集',
        filename: 'Three.Body.2023.Complete.4K.HEVC-Crispy.mp4',
        path: '/Users/taxmacro/Movies/Three.Body.2023.4K.mp4',
        size: '28.4 GB',
        res: '4K 原画',
        year: '2023',
        score: '9.6',
        poster: 'assets/posters/santi.jpg',
        hasScrapedCover: true,
        cat: '科幻 / 剧集',
        desc: '地球基础科学出现异常扰动，纳米物理学家汪淼与刑警史强联手调查...',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      ),
      LocalMediaItem(
        id: 'loc_2',
        title: '流浪地球 2',
        filename: 'The.Wandering.Earth.II.2023.IMAX.2160p.TrueHD.mkv',
        path: '/Users/taxmacro/Movies/The.Wandering.Earth.II.2023.IMAX.mkv',
        size: '18.2 GB',
        res: 'IMAX 4K',
        year: '2023',
        score: '9.4',
        poster: 'assets/posters/liulangdiqiu2.png',
        hasScrapedCover: true,
        cat: '科幻 / 灾难',
        desc: '太阳即将毁灭，人类在地球表面建造出巨大的推进器寻找新家园...',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      ),
      LocalMediaItem(
        id: 'loc_3',
        title: '狂飙 全集',
        filename: 'The.Knockout.2023.E01-E39.1080p.WEB-DL.mp4',
        path: '/Users/taxmacro/Movies/The.Knockout.2023.mp4',
        size: '22.0 GB',
        res: '1080P 高清',
        year: '2023',
        score: '9.3',
        poster: 'assets/posters/kuangbiao.jpg',
        hasScrapedCover: true,
        cat: '剧情 / 犯罪',
        desc: '京海市一线刑警安欣在与黑恶势力的长达二十年的殊死搏斗...',
        url: 'https://hn.bfvvs.com/play/mbkq6MJe/index.m3u8',
      ),
      LocalMediaItem(
        id: 'loc_4',
        title: '奥本海默',
        filename: 'Oppenheimer.2023.IMAX.2160p.UHD.BluRay.x265.mkv',
        path: '/Users/taxmacro/Movies/Oppenheimer.2023.4K.mkv',
        size: '34.8 GB',
        res: 'IMAX 4K',
        year: '2023',
        score: '8.8',
        poster: 'assets/posters/fengshen1.jpg',
        hasScrapedCover: true,
        cat: '传记 / 历史',
        desc: '克里斯托弗·诺兰执导传记巨作，聚焦“原子弹之父”罗伯特·奥本海默的波澜人生...',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      ),
      LocalMediaItem(
        id: 'loc_5',
        title: '繁花 全集',
        filename: 'Blossoms.Shanghai.2023.4K.Dolby.mp4',
        path: '/Users/taxmacro/Movies/Blossoms.Shanghai.4K.mp4',
        size: '26.5 GB',
        res: '4K 杜比视界',
        year: '2023',
        score: '8.7',
        poster: 'assets/posters/fanhua.jpg',
        hasScrapedCover: true,
        cat: '爱情 / 年代',
        desc: '九十年代初的上海黄河路商海浮沉，阿宝跃升为宝总的传奇人生...',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      ),
      LocalMediaItem(
        id: 'loc_6',
        title: '庆余年 第二季',
        filename: 'Joy.of.Life.S02.2024.2160p.Complete.mp4',
        path: '/Users/taxmacro/Movies/Joy.of.Life.S02.mp4',
        size: '24.1 GB',
        res: '4K 原画',
        year: '2024',
        score: '8.2',
        poster: 'assets/posters/qingyunian2.jpg',
        hasScrapedCover: true,
        cat: '古装 / 权谋',
        desc: '身世神秘的少年范闲历经家族、江湖、庙堂的重重考验...',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      ),
      LocalMediaItem(
        id: 'loc_7',
        title: '抓娃娃',
        filename: 'Successor.2024.1080p.WEB-DL.H265.mp4',
        path: '/Users/taxmacro/Movies/Successor.2024.mp4',
        size: '8.6 GB',
        res: '1080P 高清',
        year: '2024',
        score: '8.1',
        poster: 'assets/posters/zhuawawa.jpg',
        hasScrapedCover: true,
        cat: '喜剧 / 家庭',
        desc: '困苦家庭背后的惊天秘密，望子成龙的爆笑啼笑皆非逆转...',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      ),
    ];
  }

  /// 智能名称匹配本地兜底海报资源
  static String getBundledAssetForTitle(String title) {
    if (title.contains('三体')) return 'assets/posters/santi.jpg';
    if (title.contains('地球')) return 'assets/posters/liulangdiqiu2.png';
    if (title.contains('狂飙')) return 'assets/posters/kuangbiao.jpg';
    if (title.contains('繁花')) return 'assets/posters/fanhua.jpg';
    if (title.contains('庆余年')) return 'assets/posters/qingyunian2.jpg';
    if (title.contains('封神')) return 'assets/posters/fengshen1.jpg';
    if (title.contains('默杀')) return 'assets/posters/moxie.jpg';
    if (title.contains('抓娃娃')) return 'assets/posters/zhuawawa.jpg';
    if (title.contains('歌手')) return 'assets/posters/geshou2024.jpg';
    if (title.contains('鬼灭')) return 'assets/posters/guimiezhiren.jpg';
    return '';
  }
}
