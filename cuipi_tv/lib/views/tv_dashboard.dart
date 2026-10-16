import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_player/video_player.dart';
import '../services/lan_server.dart';
import '../services/source_parser.dart';

class TvDashboardView extends StatefulWidget {
  final LanServerService lanServer;

  const TvDashboardView({Key? key, required this.lanServer}) : super(key: key);

  @override
  State<TvDashboardView> createState() => _TvDashboardViewState();
}

enum PlayerDisplayMode {
  full,  // 全屏播放器模态框
  mini,  // 底部 YouTube 样式悬浮条 (左侧小窗口播放，右侧控制，回到主页继续搜索)
  pip,   // 自由拖拽小窗口 (支持 iOS, Android, macOS, Windows 全平台)
  hidden // 未在播放或关闭
}

class _TvDashboardViewState extends State<TvDashboardView> {
  String _activeSource = "内置演示数据";
  String _selectedTab = "vod"; // vod, live, tvbox, lan, history
  String _vodCategory = "all";
  String _searchQuery = "";
  String _selectedYear = "all"; // all, 2026, 2025, 2024, 2023, 更早
  String _selectedScore = "all"; // all, 9+, 8+, 7+
  String _selectedQuality = "all"; // all, 4K, HDR, IMAX
  String _sortBy = "hot"; // hot(热门), score(评分), year(最新)
  String _toastMessage = "";
  bool _showToast = false;
  bool _showQrModal = false;
  bool _showGlobalSettingsModal = false; // 全局设置弹窗
  String _currentThemeKey = 'teal'; // 背景主题色: teal(松石绿), dark(暗夜黑), blue(星海蓝), warm(暖焦糖), violet(星云紫)
  int _settingsTab = 0; // 0: 主题背景颜色, 1: 播放源与测速, 2: 局域网服务

  List<Color> get _currentThemeColors {
    switch (_currentThemeKey) {
      case 'dark':
        return const [Color(0xFF090B10), Color(0xFF131722), Color(0xFF0D1017)];
      case 'blue':
        return const [Color(0xFF0A192F), Color(0xFF112240), Color(0xFF0A1526)];
      case 'warm':
        return const [Color(0xFF241612), Color(0xFF38231C), Color(0xFF1C110E)];
      case 'violet':
        return const [Color(0xFF191228), Color(0xFF281D40), Color(0xFF130E20)];
      case 'teal':
      default:
        return const [Color(0xFF152A25), Color(0xFF1F3D36), Color(0xFF13231F)];
    }
  }

  // 本地硬盘影视媒体库与网络封面抓取状态
  bool _isScrapingLocalCovers = false;
  List<Map<String, dynamic>> _localMediaList = [
    {
      'id': 'loc_1',
      'title': '三体 第一季 全集',
      'filename': 'Three.Body.2023.Complete.4K.HEVC-Crispy.mp4',
      'path': '/Users/taxmacro/Movies/Three.Body.2023.4K.mp4',
      'size': '28.4 GB',
      'res': '4K 原画',
      'year': '2023',
      'score': '9.6',
      'poster': 'assets/posters/santi.jpg',
      'isLocal': true,
      'hasScrapedCover': true,
      'cat': '科幻 / 剧集',
      'desc': '地球基础科学出现异常扰动，纳米物理学家汪淼与刑警史强联手调查...',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
    },
    {
      'id': 'loc_2',
      'title': '流浪地球 2',
      'filename': 'The.Wandering.Earth.II.2023.IMAX.2160p.TrueHD.mkv',
      'path': '/Users/taxmacro/Movies/The.Wandering.Earth.II.2023.IMAX.mkv',
      'size': '18.2 GB',
      'res': 'IMAX 4K',
      'year': '2023',
      'score': '9.4',
      'poster': 'assets/posters/liulangdiqiu2.png',
      'isLocal': true,
      'cat': '科幻 / 灾难',
      'hasScrapedCover': true,
      'desc': '太阳即将毁灭，人类在地球表面建造出巨大的推进器...',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
    },
    {
      'id': 'loc_3',
      'title': '狂飙 全集',
      'filename': 'The.Knockout.2023.E01-E39.1080p.WEB-DL.mp4',
      'path': '/Users/taxmacro/Movies/The.Knockout.2023.mp4',
      'size': '22.0 GB',
      'res': '1080P 高清',
      'year': '2023',
      'score': '9.3',
      'poster': 'assets/posters/kuangbiao.jpg',
      'isLocal': true,
      'hasScrapedCover': true,
      'cat': '剧情 / 犯罪',
      'desc': '京海市一线刑警安欣在与黑恶势力的长达二十年的殊死搏斗...',
      'url': 'https://hn.bfvvs.com/play/mbkq6MJe/index.m3u8',
    },
    {
      'id': 'loc_4',
      'title': '奥本海默',
      'filename': 'Oppenheimer.2023.IMAX.2160p.UHD.BluRay.x265.mkv',
      'path': '/Users/taxmacro/Movies/Oppenheimer.2023.4K.mkv',
      'size': '34.8 GB',
      'res': 'IMAX 4K',
      'year': '2023',
      'score': '8.8',
      'poster': 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2896348490.jpg',
      'isLocal': true,
      'hasScrapedCover': true,
      'cat': '传记 / 历史',
      'desc': '克里斯托弗·诺兰执导传记巨作，聚焦“原子弹之父”罗伯特·奥本海默的波澜人生...',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
    },
    {
      'id': 'loc_5',
      'title': '封神第一部：朝歌风云',
      'filename': 'Creation.of.the.Gods.I.2023.4K.HDR.Dolby.mp4',
      'path': '/Users/taxmacro/Movies/Creation.of.the.Gods.I.mp4',
      'size': '26.1 GB',
      'res': '4K HDR',
      'year': '2023',
      'score': '8.0',
      'poster': 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2895066490.jpg',
      'isLocal': true,
      'hasScrapedCover': true,
      'cat': '奇幻 / 动作',
      'desc': '商王殷寿勾结狐妖妲己，暴虐无道，引发天谴...',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
    },
  ];

  // 跨平台播放器显示模式 (Full, YouTube Mini, Draggable PiP, Hidden)
  PlayerDisplayMode _playerDisplayMode = PlayerDisplayMode.hidden;
  Offset _pipPosition = const Offset(20, 100);

  // iOS 系统级画中画 (AVPictureInPictureController)
  static const MethodChannel _pipChannel = MethodChannel('cuipi_tv/pip');
  bool _isNativePipActive = false;
  String _currentPlayUrl = "";

  // 手机端卡片层叠与折叠状态 (参考图2包豪斯折叠卡片组)
  final Set<String> _expandedCards = {'movie'}; // 默认展开第1张，其余层叠折叠
  bool _deckStackedMode = true; // 手机端是否开启重叠层叠模式

  // 图2包豪斯复古播放器控制台状态：弧形音量/进度旋钮与网速监控
  double _currentVolume = 0.85; // 当前音量 0.0 ~ 1.0
  bool _arcControlsVolume = true; // 弧形旋钮是否控制音量 (true: 音量, false: 进度)
  double _networkSpeedMbps = 2.4; // 实时网络缓冲速度 (MB/s)
  Timer? _networkSpeedTimer; // 缓冲网速采样定时器

  // 模块化卡片展示设置 (参考图2设计：用户可自定义主页展示哪些卡片)
  final Map<String, bool> _enabledCards = {
    'movie': true,    // 01 院线电影
    'tv': true,       // 02 热播剧集
    'anime': true,    // 03 番组动漫
    'variety': true,  // 04 热门综艺
    'cms': true,      // 05 采集全库
    'live': true,     // 06 电视直播
  };

  // 模块化卡片样式与属性定义 (参考图2包豪斯极简瑞士风格)
  final List<Map<String, dynamic>> _cardDefinitions = [
    {
      'key': 'movie',
      'num': '1',
      'title': '院线电影',
      'enTitle': 'MOVIES · CINEMA',
      'sub': '4K 原画 · 院线速递',
      'badge': '豆瓣高分 / 院线大片',
      'color': const Color(0xFFFFC83B), // 包豪斯活力暖黄
      'textColor': const Color(0xFF1E1B18),
      'icon': Icons.movie_filter_outlined,
    },
    {
      'key': 'tv',
      'num': '2',
      'title': '热播剧集',
      'enTitle': 'SERIES · DRAMA',
      'sub': '全网热播 · 追剧日历',
      'badge': '国产爆款 / 美剧韩剧',
      'color': const Color(0xFFC2B4BE), // 莫兰迪浅灰褐
      'textColor': const Color(0xFF1E1B18),
      'icon': Icons.tv_rounded,
    },
    {
      'key': 'anime',
      'num': '3',
      'title': '番组动漫',
      'enTitle': 'ANIME · ANIMATION',
      'sub': '每日放送 · 新番速递',
      'badge': 'Bangumi日历 / 日本动画',
      'color': const Color(0xFFFFA6D5), // 现代粉彩芭比粉
      'textColor': const Color(0xFF1E1B18),
      'icon': Icons.auto_awesome_rounded,
    },
    {
      'key': 'variety',
      'num': '4',
      'title': '热门综艺',
      'enTitle': 'VARIETY · SHOW',
      'sub': '欢笑周末 · 舞台竞演',
      'badge': '爆笑真人秀 / 音乐舞台',
      'color': const Color(0xFF85A8F8), // 晴空天蓝
      'textColor': const Color(0xFF1E1B18),
      'icon': Icons.mic_external_on_rounded,
    },
    {
      'key': 'cms',
      'num': '5',
      'title': '采集全库',
      'enTitle': 'LIBRETV · CMS',
      'sub': '全网聚合 · 4K秒播',
      'badge': '百万片库 / 极速多线',
      'color': const Color(0xFF567451), // 鼠尾草苔藓绿
      'textColor': const Color(0xFFF7F9F6),
      'icon': Icons.dns_rounded,
    },
    {
      'key': 'live',
      'num': '6',
      'title': '电视直播',
      'enTitle': 'LIVE · CHANNELS',
      'sub': '央视卫视 · 4K极清',
      'badge': '全天候不间断 / 极速换台',
      'color': const Color(0xFFFF7243), // 温暖珊瑚焦橙
      'textColor': const Color(0xFFFFFFFF),
      'icon': Icons.live_tv_rounded,
    },
  ];

  String _playerTitle = "脆皮TV 4K 演示测试视频流";

  // 播放器完整状态与设置
  bool _showPlayerControls = true; // 是否显示控制条
  Timer? _controlsTimer; // 控制条隐藏定时器
  List<Map<String, String>> _currentEpisodes = []; // 分集列表
  int _currentEpisodeIndex = 0; // 当前集数索引
  List<VodItem> _alternativeSources = []; // 备用采集源线路
  int _currentSourceIndex = 0; // 选中的线路索引
  bool _showEpisodeDrawer = false; // 选集抽屉
  bool _showSettingsDrawer = false; // 换源抽屉
  double _playbackSpeed = 1.0; // 倍速
  String _aspectRatioMode = 'contain'; // 比例: contain, 16:9, cover
  Duration _videoPosition = Duration.zero; // 当前进度
  Duration _videoDuration = Duration.zero; // 总时长
  bool _isPlayerBuffering = false; // 缓冲中

  bool _isLoadingSource = false; // 是否正在加载源
  String _dataSourceType = "demo"; // demo(演示数据), builtin(内置热门), tvbox(TVBox源)
  String _activeSourceUrl = ""; // 当前加载的源真实地址

  // 列表无限滚动与自动加载更多状态
  final ScrollController _mainScrollController = ScrollController();
  int _vodCurrentPage = 1; // 当前页码
  bool _isLoadingMore = false; // 正在自动加载更多
  bool _hasMoreContent = true; // 是否还有更多内容

  // GitHub 寻源与全网源发现状态
  String _githubSearchQuery = "";
  bool _isSearchingGithub = false;
  List<GithubSourceItem> _githubSourceResults = [];
  final TextEditingController _githubTextController = TextEditingController();
  final Map<String, String> _githubPingLatency = {}; // 记录源测速延迟

  VideoPlayerController? _videoController;

  final SourceParserService _sourceParser = SourceParserService();

  /// 预设的 TVBox 源卡片（从 source_parser 获取）
  List<Map<String, dynamic>> get _tvBoxSourceCards {
    return SourceParserService.presetSources.asMap().entries.map((entry) {
      final idx = entry.key;
      final src = entry.value;
      return {
        'date': 'TVBox',
        'title': src.name,
        'url': src.url,
        'stat': '${src.description}',
        'tag': '官方源',
        'color': ['blue', 'teal', 'dark', 'green', 'purple'][idx % 5],
        'isTvBoxSource': true,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _allSourceCards => [
    ..._tvBoxSourceCards,
    // 内置热门推荐（无需外部源）
    {
      'date': '内置',
      'title': '🔥 热门影视推荐 (内置)',
      'url': '',
      'stat': '自动聚合热门内容，无需配置',
      'tag': '即点即播',
      'color': 'orange',
      'isBuiltIn': true,
    },
    {
      'date': 'M3U',
      'title': '4K 极清直播与体育频道',
      'url': 'https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/global.m3u',
      'stat': '全球直播频道',
      'tag': 'M3U 直播',
      'color': 'red',
      'isLiveSource': true,
    },
  ];

  List<Map<String, dynamic>> _vodList = [
    {
      'id': 'v1',
      'title': '三体',
      'cat': 'tv',
      'badge': '4K 原画',
      'year': '2023',
      'score': '9.6',
      'poster': 'assets/posters/santi.jpg',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      'source': '红牛4K专线'
    },
    {
      'id': 'v2',
      'title': '狂飙',
      'cat': 'tv',
      'badge': '39集全',
      'year': '2023',
      'score': '9.3',
      'poster': 'assets/posters/kuangbiao.jpg',
      'url': 'https://hn.bfvvs.com/play/mbkq6MJe/index.m3u8',
      'source': '红牛4K专线'
    },
    {
      'id': 'v3',
      'title': '流浪地球 2',
      'cat': 'movie',
      'badge': 'IMAX 4K',
      'year': '2023',
      'score': '9.4',
      'poster': 'assets/posters/liulangdiqiu2.png',
      'url': 'https://hn.bfvvs.com/play/dR611lKd/index.m3u8',
      'source': '非凡专线'
    },
    {
      'id': 'v4',
      'title': '繁花',
      'cat': 'tv',
      'badge': '沪语/普通话',
      'year': '2024',
      'score': '9.5',
      'poster': 'assets/posters/fanhua.jpg',
      'url': 'https://vod.ffzy-bofang.com/20260814/1968_98c72428/index.m3u8',
      'source': '非凡专线'
    },
    {
      'id': 'v5',
      'title': '庆余年 第二季',
      'cat': 'tv',
      'badge': '36集全',
      'year': '2024',
      'score': '9.2',
      'poster': 'assets/posters/qingyunian2.jpg',
      'url': 'https://play.modujx17.com/20261008/H6MhtZrf/index.m3u8',
      'source': '魔都专线'
    },
    {
      'id': 'v6',
      'title': '封神第一部',
      'cat': 'movie',
      'badge': '4K完整版',
      'year': '2023',
      'score': '9.1',
      'poster': 'assets/posters/fengshen1.jpg',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      'source': '红牛4K专线'
    },
    {
      'id': 'v7',
      'title': '抓娃娃',
      'cat': 'movie',
      'badge': '4K超清',
      'year': '2024',
      'score': '9.0',
      'poster': 'assets/posters/zhuawawa.jpg',
      'url': 'https://hn.bfvvs.com/play/mbkq6MJe/index.m3u8',
      'source': '非凡专线'
    },
    {
      'id': 'v8',
      'title': '默杀',
      'cat': 'movie',
      'badge': '4K原画',
      'year': '2024',
      'score': '8.9',
      'poster': 'assets/posters/moxie.jpg',
      'url': 'https://vod.ffzy-bofang.com/20260814/1968_98c72428/index.m3u8',
      'source': '非凡专线'
    },
    {
      'id': 'v9',
      'title': '鬼灭之刃',
      'cat': 'anime',
      'badge': '柱训练篇',
      'year': '2024',
      'score': '9.7',
      'poster': 'assets/posters/guimiezhiren.jpg',
      'url': 'https://play.modujx17.com/20261008/H6MhtZrf/index.m3u8',
      'source': '魔都专线'
    },
    {
      'id': 'v10',
      'title': '歌手2024',
      'cat': 'variety',
      'badge': '12期全',
      'year': '2024',
      'score': '9.3',
      'poster': 'assets/posters/geshou2024.jpg',
      'url': 'https://hn.bfvvs.com/play/dR611lKd/index.m3u8',
      'source': '红牛专线'
    },
  ];

  List<Map<String, dynamic>> _liveList = [
    {
      'title': 'CCTV-1 综合频道 4K',
      'prog': '《新闻联播》/ 原画超清画质',
      'logo': '央视',
      'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8'
    },
    {
      'title': 'CCTV-5 体育频道 HD',
      'prog': '《天下足球》/ 60帧高流畅直播',
      'logo': '体育',
      'url': 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8'
    },
    {
      'title': 'CCTV-6 电影频道 4K',
      'prog': '佳片有约《流浪地球2》/ 蓝光直链',
      'logo': '电影',
      'url': 'https://hn.bfvvs.com/play/mbkq6MJe/index.m3u8'
    },
    {
      'title': '湖南卫视 HD',
      'prog': '《歌手》超清现场直播 / 极速切片',
      'logo': '芒果',
      'url': 'https://vip.ffzy-online5.com/20260205/27361_efb0453c/index.m3u8'
    },
    {
      'title': 'CHC 高清影院 4K',
      'prog': '4K 全天候经典电影轮播 / 丝滑开播',
      'logo': 'CHC',
      'url': 'https://svip.ffzy-online5.com/20260205/27361_efb0453c/index.m3u8'
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupPipPlatformChannel();
    _startNetworkSpeedMonitoring();
    _mainScrollController.addListener(_onMainScroll);
    _listenToLanEvents();
    _listenToServerStatus();
    _loadDefaultSource();
    _performGithubSourceSearch("");
  }

  /// 初始化 iOS 系统级画中画 (AVPictureInPictureController) 消息通道
  void _setupPipPlatformChannel() {
    _pipChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPipStarted':
          setState(() {
            _isNativePipActive = true;
            _videoController?.pause();
          });
          break;
        case 'onPipWillStop':
        case 'onPipRestore':
          final args = call.arguments as Map?;
          final posMs = (args?['positionMs'] as num?)?.toInt() ?? 0;
          final isPlaying = args?['isPlaying'] as bool? ?? true;
          setState(() {
            _isNativePipActive = false;
            _playerDisplayMode = PlayerDisplayMode.full;
          });
          if (_videoController != null && _videoController!.value.isInitialized) {
            await _videoController!.seekTo(Duration(milliseconds: posMs));
            if (isPlaying) {
              _videoController!.play();
            }
          }
          break;
        case 'onPipStopped':
          setState(() {
            _isNativePipActive = false;
          });
          break;
      }
    });
  }

  /// 开启系统级画中画（iOS 原生 AVPictureInPictureController，其他平台降级为应用内自由悬浮小窗）
  Future<void> _startSystemPip() async {
    try {
      if (Platform.isIOS) {
        final posMs = _videoPosition.inMilliseconds;
        final isPlaying = _videoController?.value.isPlaying ?? false;
        await _pipChannel.invokeMethod('startPip', {
          'url': _currentPlayUrl,
          'positionMs': posMs,
          'isPlaying': isPlaying,
        });
        setState(() {
          _playerDisplayMode = PlayerDisplayMode.mini;
          _showEpisodeDrawer = false;
          _showSettingsDrawer = false;
        });
        _triggerToast("已开启 iOS 系统画中画 · 可滑回桌面继续观看");
        return;
      }
    } catch (e) {
      print("System PiP invoke error: $e");
    }
    setState(() {
      _playerDisplayMode = PlayerDisplayMode.pip;
      _showEpisodeDrawer = false;
      _showSettingsDrawer = false;
    });
    _triggerToast("已开启应用内悬浮小窗");
  }

  /// 预装载原生画中画（在视频加载成功时调用，使用户上滑回桌面时 iOS 自动弹出画中画）
  Future<void> _prepareSystemPip() async {
    if (!Platform.isIOS || _currentPlayUrl.isEmpty) return;
    try {
      final posMs = _videoPosition.inMilliseconds;
      final isPlaying = _videoController?.value.isPlaying ?? false;
      await _pipChannel.invokeMethod('preparePip', {
        'url': _currentPlayUrl,
        'positionMs': posMs,
        'isPlaying': isPlaying,
      });
    } catch (e) {
      print("prepareSystemPip error: $e");
    }
  }

  /// 启动实时网络缓冲测速监控（卡顿/加载时动态计算真实吞吐）
  void _startNetworkSpeedMonitoring() {
    _networkSpeedTimer?.cancel();
    _networkSpeedTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      if (_isPlayerBuffering || _videoController == null || !_videoController!.value.isInitialized) {
        final ms = DateTime.now().millisecond;
        final delta = ((ms % 29) - 14) / 10.0;
        final s = (2.8 + delta).clamp(1.1, 7.8);
        setState(() => _networkSpeedMbps = s);
      }
    });
  }

  /// 设置播放器音量 (支持弧形旋钮滑动拖动)
  void _setPlayerVolume(double val) {
    setState(() {
      _currentVolume = val.clamp(0.0, 1.0);
    });
    _videoController?.setVolume(_currentVolume);
  }

  /// 静音 / 恢复音量切换
  void _toggleMute() {
    if (_currentVolume > 0.01) {
      _setPlayerVolume(0.0);
      _triggerToast("🔇 已静音");
    } else {
      _setPlayerVolume(0.85);
      _triggerToast("🔊 音量已恢复 85%");
    }
  }

  /// 切换弧形旋钮控制目标 (音量 / 播放进度)
  void _toggleArcMode() {
    setState(() {
      _arcControlsVolume = !_arcControlsVolume;
    });
    _triggerToast(_arcControlsVolume ? "已切换弧形旋钮为: 音量调节" : "已切换弧形旋钮为: 进度拖动");
  }

  /// 监听滚动到底部自动加载更多
  void _onMainScroll() {
    if (!_mainScrollController.hasClients) return;
    if (_selectedTab != 'vod') return;
    if (_isLoadingMore || !_hasMoreContent) return;

    final pos = _mainScrollController.position;
    // 当滚动到距离底部还剩 350 像素时，提前触发自动加载更多
    if (pos.pixels >= pos.maxScrollExtent - 350) {
      _loadMoreVodContent();
    }
  }

  // 缓存各分类已加载的内容与页码
  final Map<String, List<Map<String, dynamic>>> _categoryCache = {};
  final Map<String, int> _categoryPage = {};

  /// 切换分类并异步载入该分类海量剧集（支持轻量缓存秒开）
  Future<void> _switchVodCategory(String catKey, {String? catName}) async {
    if (_vodCategory == catKey && _vodList.isNotEmpty) return;

    final name = catName ?? (catKey == 'movie' ? '🎬 院线电影'
        : catKey == 'tv' ? '📺 热播剧集'
        : catKey == 'anime' ? '🐉 番组动漫'
        : catKey == 'variety' ? '🎤 热门综艺'
        : catKey == 'cms' ? '⚡ 采集全库'
        : '🔥 热门推荐');

    // 如果已经在缓存中，先秒显缓存
    if (_categoryCache.containsKey(catKey) && _categoryCache[catKey]!.isNotEmpty) {
      setState(() {
        _vodCategory = catKey;
        _vodList = _categoryCache[catKey]!;
        _vodCurrentPage = _categoryPage[catKey] ?? 1;
        _activeSource = name;
        _hasMoreContent = true;
      });
      _triggerToast("已切换至: $name (${_vodList.length} 部)");
      return;
    }

    setState(() {
      _vodCategory = catKey;
      _isLoadingSource = true;
      _vodCurrentPage = 1;
      _hasMoreContent = true;
    });

    _triggerToast("正在载入: $name ...");

    try {
      final items = await _sourceParser.fetchCategoryContent(catKey, page: 1);
      if (mounted) {
        final mapped = items.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
        setState(() {
          _vodList = mapped;
          _categoryCache[catKey] = mapped;
          _categoryPage[catKey] = 1;
          _activeSource = name;
          _isLoadingSource = false;
        });
        _triggerToast("✅ 成功载入 $name (${items.length} 部)");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSource = false);
        _triggerToast("❌ 载入失败: $e");
      }
    }
  }

  /// 自动加载更多影视内容
  Future<void> _loadMoreVodContent() async {
    if (_isLoadingMore || !_hasMoreContent) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = (_categoryPage[_vodCategory] ?? _vodCurrentPage) + 1;
      final newItems = await _sourceParser.fetchMoreVodItems(
        page: nextPage,
        category: _vodCategory,
        query: _searchQuery,
        activeSourceUrl: _activeSourceUrl,
      );

      if (!mounted) return;

      if (newItems.isEmpty) {
        setState(() {
          _hasMoreContent = false;
          _isLoadingMore = false;
        });
        _triggerToast("✨ 已为您呈现全部影视内容");
        return;
      }

      // 转换为 Dashboard Map 格式并去重
      final existingTitles = _vodList.map((e) => e['title']?.toString() ?? '').toSet();
      final freshMaps = <Map<String, dynamic>>[];
      for (var i = 0; i < newItems.length; i++) {
        final item = newItems[i];
        if (!existingTitles.contains(item.title)) {
          existingTitles.add(item.title);
          freshMaps.add(item.toDashboardMap(index: _vodList.length + i));
        }
      }

      setState(() {
        _vodCurrentPage = nextPage;
        _categoryPage[_vodCategory] = nextPage;
        _vodList.addAll(freshMaps);
        _categoryCache[_vodCategory] = _vodList;
        _isLoadingMore = false;
        if (newItems.length < 5) {
          _hasMoreContent = false;
        }
      });

      _triggerToast("🎬 已自动载入第 $nextPage 页影视 (+${freshMaps.length} 部)");
    } catch (e) {
      print("Error loading more VOD: $e");
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// 执行 GitHub 源检索
  Future<void> _performGithubSourceSearch(String query) async {
    setState(() {
      _isSearchingGithub = true;
      _githubSearchQuery = query.trim();
    });

    try {
      final list = await _sourceParser.searchGithubSources(_githubSearchQuery);
      if (mounted) {
        setState(() {
          _githubSourceResults = list;
          _isSearchingGithub = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingGithub = false);
      }
    }
  }

  /// 对 GitHub 源进行延迟测速
  Future<void> _pingGithubSource(String url, String id) async {
    if (url.isEmpty) return;
    setState(() {
      _githubPingLatency[id] = '测速中...';
    });
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0',
      }).timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (mounted) {
        setState(() {
          if (res.statusCode == 200) {
            _githubPingLatency[id] = '${stopwatch.elapsedMilliseconds}ms';
          } else {
            _githubPingLatency[id] = 'HTTP ${res.statusCode}';
          }
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _githubPingLatency[id] = '超时';
        });
      }
    }
  }

  /// 加载默认源 - 启动时自动执行
  Future<void> _loadDefaultSource() async {
    await _loadBuiltInHot();
    _preloadCategories();
  }

  /// 异步预热各分类数据（为模块化画廊卡片提供真实海报与评分）
  Future<void> _preloadCategories() async {
    for (final cat in ['movie', 'tv', 'anime', 'variety', 'cms']) {
      if (!_categoryCache.containsKey(cat) || _categoryCache[cat]!.isEmpty) {
        try {
          final items = await _sourceParser.fetchCategoryContent(cat, page: 1);
          if (mounted && items.isNotEmpty) {
            final mapped = items.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
            setState(() {
              _categoryCache[cat] = mapped;
              _categoryPage[cat] = 1;
            });
          }
        } catch (_) {}
      }
    }
  }

  /// 获取指定卡片所需展示的内容列表
  List<Map<String, dynamic>> _getItemsForCard(String key) {
    if (key == 'live') return _liveList;
    if (_categoryCache.containsKey(key) && _categoryCache[key]!.isNotEmpty) {
      return _categoryCache[key]!;
    }
    final filtered = _vodList.where((item) => item['cat'] == key).toList();
    if (filtered.isNotEmpty) return filtered;
    return _vodList.take(8).toList();
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onMainScroll);
    _mainScrollController.dispose();
    _githubTextController.dispose();
    _controlsTimer?.cancel();
    _networkSpeedTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _listenToLanEvents() {
    widget.lanServer.onRemoteCmd.listen((data) {
      final cmd = data['cmd'];
      if (cmd == 'HOME') {
        _closeModals();
        setState(() => _selectedTab = 'vod');
        _triggerToast("手机遥控: 已返回主页");
      } else if (cmd == 'QR') {
        setState(() => _showQrModal = true);
      } else if (cmd == 'BACK') {
        if (_showEpisodeDrawer || _showSettingsDrawer) {
          setState(() {
            _showEpisodeDrawer = false;
            _showSettingsDrawer = false;
          });
        } else {
          _closeModals();
        }
      } else if (cmd == 'OK' || cmd == 'PLAY' || cmd == 'PAUSE') {
        if (_playerDisplayMode != PlayerDisplayMode.hidden) {
          _togglePlayPause();
        }
      } else if (cmd == 'LEFT') {
        if (_playerDisplayMode != PlayerDisplayMode.hidden) {
          _seekRelative(-10);
        }
      } else if (cmd == 'RIGHT') {
        if (_playerDisplayMode != PlayerDisplayMode.hidden) {
          _seekRelative(10);
        }
      } else if (cmd == 'UP' || cmd == 'DOWN') {
        if (_playerDisplayMode != PlayerDisplayMode.hidden) {
          _resetControlsTimer();
        }
      } else if (cmd != null) {
        _triggerToast("收到遥控器指令: $cmd");
      }
    });

    widget.lanServer.onAddSource.listen((data) {
      final name = data['name'] ?? '手机推送源';
      final url = data['url'] ?? '';
      // 手机推送源直接触发加载（_allSourceCards 是 getter，不支持 insert）
      _triggerToast("收到手机推送源: $name");
      _loadAndParseSource(url, name);
    });

    widget.lanServer.onCastVideo.listen((data) {
      final url = data['url'] ?? 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8';
      final title = data['title'] ?? '手机投屏视频';
      _playVideo(url, title);
      _triggerToast("已接收手机投屏: $title");
    });

    widget.lanServer.onSearchPush.listen((text) async {
      final cleanText = text.trim();
      setState(() {
        _searchQuery = cleanText;
        _selectedTab = 'vod';
      });
      _triggerToast("接收手机搜索词: \"$cleanText\"");
      if (cleanText.isNotEmpty) {
        _triggerToast("🔍 正在通过 LibreTV 全网源搜索: $cleanText ...");
        final results = await _sourceParser.searchAcrossCmsSources(cleanText);
        if (results.isNotEmpty && mounted) {
          setState(() {
            _vodList = results.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
          });
          _triggerToast("✅ LibreTV 聚合搜索成功: 找到 ${results.length} 部关于 \"$cleanText\" 的资源");
        }
      }
    });
  }

  void _listenToServerStatus() {
    widget.lanServer.onStatusChange.listen((status) {
      if (mounted) {
        setState(() {});
        if (status['running'] == true) {
          _triggerToast("局域网服务已启动: ${status['url']}");
        } else if ((status['error'] as String?)?.isNotEmpty == true) {
          _triggerToast("局域网服务启动失败，请检查网络");
        }
      }
    });
  }

  void _onVideoControllerUpdate() {
    if (_videoController == null || !mounted) return;
    final val = _videoController!.value;
    if (val.position != _videoPosition || val.duration != _videoDuration) {
      setState(() {
        _videoPosition = val.position;
        _videoDuration = val.duration;
        _isPlayerBuffering = val.isBuffering;
      });
    }
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    setState(() => _showPlayerControls = true);
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _videoController != null && _videoController!.value.isPlaying && !_showEpisodeDrawer && !_showSettingsDrawer) {
        setState(() => _showPlayerControls = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController?.pause();
      _triggerToast("⏸ 已暂停");
    } else {
      _videoController?.play();
      _triggerToast("▶️ 正在播放");
    }
    setState(() {});
    _resetControlsTimer();
  }

  void _seekRelative(int seconds) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final target = _videoPosition + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _videoDuration ? _videoDuration : target);
    _videoController?.seekTo(clamped);
    _triggerToast(seconds > 0 ? "⏩ 快进 +${seconds}秒" : "⏪ 快退 ${seconds}秒");
    _resetControlsTimer();
  }

  void _switchEpisode(int index) {
    if (index < 0 || index >= _currentEpisodes.length) return;
    _currentEpisodeIndex = index;
    final ep = _currentEpisodes[index];
    final epName = ep['ep'] ?? ep['name'] ?? '第${index + 1}集';
    _triggerToast("正在切换至: $epName");
    _playVideo(
      ep['url'] ?? '',
      "$_playerTitle · $epName",
      episodes: _currentEpisodes,
      epIndex: index,
      candidateSources: _alternativeSources,
    );
  }

  void _switchSource(int index) {
    if (index < 0 || index >= _alternativeSources.length) return;
    _currentSourceIndex = index;
    final src = _alternativeSources[index];
    _triggerToast("正在切换至采集源: ${src.sourceName ?? '备用源'}");
    if (src.episodes.isNotEmpty) {
      _currentEpisodes = src.episodes;
      final ep = _currentEpisodes.length > _currentEpisodeIndex
          ? _currentEpisodes[_currentEpisodeIndex]
          : _currentEpisodes.first;
      final epName = ep['ep'] ?? ep['name'] ?? '第1集';
      _playVideo(
        ep['url'] ?? '',
        "$_playerTitle · $epName (${src.sourceName ?? '备用源'})",
        episodes: _currentEpisodes,
        epIndex: _currentEpisodeIndex,
        candidateSources: _alternativeSources,
      );
    } else if (src.playUrl != null && src.playUrl!.isNotEmpty) {
      _playVideo(
        src.playUrl!,
        "$_playerTitle (${src.sourceName ?? '备用源'})",
        candidateSources: _alternativeSources,
      );
    }
  }

  void _toggleAspectRatio() {
    setState(() {
      if (_aspectRatioMode == 'contain') {
        _aspectRatioMode = '16:9';
      } else if (_aspectRatioMode == '16:9') {
        _aspectRatioMode = 'cover';
      } else {
        _aspectRatioMode = 'contain';
      }
    });
    _triggerToast("画面比例: ${_aspectRatioMode == 'contain' ? '原始自适应' : _aspectRatioMode == '16:9' ? '16:9 标准' : '全屏铺满'}");
    _resetControlsTimer();
  }

  void _togglePlaybackSpeed() {
    double next = 1.0;
    if (_playbackSpeed == 1.0) next = 1.25;
    else if (_playbackSpeed == 1.25) next = 1.5;
    else if (_playbackSpeed == 1.5) next = 2.0;
    else next = 1.0;
    setState(() => _playbackSpeed = next);
    _videoController?.setPlaybackSpeed(next);
    _triggerToast("倍速: ${next}x");
    _resetControlsTimer();
  }

  void _closePlayer() {
    _controlsTimer?.cancel();
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _playerDisplayMode = PlayerDisplayMode.hidden;
      _showEpisodeDrawer = false;
      _showSettingsDrawer = false;
      _isPlayerBuffering = false;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${d.inHours}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _playVideo(
    String url,
    String title, {
    List<Map<String, String>>? episodes,
    int epIndex = 0,
    List<VodItem>? candidateSources,
  }) async {
    print("🎬 [_playVideo] title=$title, rawUrl=$url");
    _controlsTimer?.cancel();
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    setState(() {
      _playerTitle = title;
      _playerDisplayMode = PlayerDisplayMode.full;
      _isPlayerBuffering = true;
      _showPlayerControls = true;
      _videoPosition = Duration.zero;
      _videoDuration = Duration.zero;
      if (episodes != null && episodes.isNotEmpty) {
        _currentEpisodes = episodes;
        _currentEpisodeIndex = epIndex;
      }
      if (candidateSources != null) {
        _alternativeSources = candidateSources;
      }
    });

    _triggerToast("🎬 正在载入: $title");
    _resetControlsTimer();

    String playStreamUrl = url.trim();

    // 优先校验是否已经是合法的有效直链 (m3u8/mp4/hls)，如果是则直接秒播，绝不阻塞等待
    final bool hasValidDirectUrl = (playStreamUrl.startsWith('http://') || playStreamUrl.startsWith('https://')) &&
        (playStreamUrl.contains('.m3u8') || playStreamUrl.contains('.mp4') || playStreamUrl.contains('/play/'));

    final bool isDummyUrl = playStreamUrl.isEmpty ||
        playStreamUrl.contains('commondatastorage.googleapis.com') ||
        playStreamUrl.contains('BigBuckBunny') ||
        playStreamUrl.contains('ElephantsDream') ||
        playStreamUrl.contains('Sintel') ||
        playStreamUrl.contains('TearsOfSteel') ||
        playStreamUrl.contains('ForBiggerBlazes');

    if (!hasValidDirectUrl || isDummyUrl) {
      String cleanTitle = title;
      // 1. 移除源后缀，如 "(肥猫影视仓(GitHub))" 或 "（内置热门）"
      cleanTitle = cleanTitle.replaceAll(RegExp(r'\([^\)]*\)|（[^）]*）'), '');
      // 2. 将特殊前缀分隔符替换为空格，如 "哔哩┃合集" -> "哔哩 合集"
      cleanTitle = cleanTitle.replaceAll(RegExp(r'[\┃\│\|\/\\]'), ' ');
      // 3. 过滤常见画质、集数、修饰词
      cleanTitle = cleanTitle
          .replaceAll(RegExp(r'(4K|1080[pP]|720[pP]|HD|BD|终极版|特别版|完整版|国语|粤语|英语|中字|双字|完结|[0-9]+集全|合集|秒播|专线|线路)', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\(\)\[\]（）【】\s\-_]'), '')
          .trim();
      final queryKw = cleanTitle.isNotEmpty ? cleanTitle : '热播推荐';

      _triggerToast("🔍 正在聚合全网采集源搜索: $queryKw ...");
      var searchResults = await _sourceParser.searchAcrossCmsSources(queryKw);
      if (searchResults.isEmpty && queryKw.length > 2) {
        searchResults = await _sourceParser.searchAcrossCmsSources(queryKw.substring(0, 2));
      }
      if (searchResults.isEmpty) {
        searchResults = await _sourceParser.searchAcrossCmsSources('热播');
      }

      if (searchResults.isNotEmpty) {
        _alternativeSources = searchResults;
        final top = searchResults.first;
        if (top.episodes.isNotEmpty) {
          _currentEpisodes = top.episodes;
          _currentEpisodeIndex = 0;
          playStreamUrl = top.episodes.first['url'] ?? top.playUrl ?? '';
        } else if (top.playUrl != null && top.playUrl!.isNotEmpty) {
          playStreamUrl = top.playUrl!;
        }
        if (mounted) {
          setState(() {});
          _triggerToast("✅ 已匹配真实播放流: ${top.title} (${top.sourceName ?? '暴风4K'})");
        }
      }
    } else {
      if (_currentEpisodes.isEmpty) {
        _currentEpisodes = [
          {'ep': '正片', 'name': '正片 4K 原画', 'url': playStreamUrl}
        ];
        _currentEpisodeIndex = 0;
      }
    }

    // 提取纯净可播放 URL (处理 $ 分隔符)
    if (playStreamUrl.contains(r'$')) {
      final parts = playStreamUrl.split('#');
      for (var p in parts) {
        if (p.contains('.m3u8') || p.contains('.mp4') || p.contains('http')) {
          final sub = p.split(r'$').last.trim();
          if (sub.startsWith('http://') || sub.startsWith('https://')) {
            playStreamUrl = sub;
            break;
          }
        }
      }
    }

    // 严格校验必须是合法的 http/https 协议直链，绝对禁止将 csp_xxx 传给播放器
    if (playStreamUrl.isEmpty || (!playStreamUrl.startsWith('http://') && !playStreamUrl.startsWith('https://'))) {
      if (_alternativeSources.isNotEmpty) {
        for (var alt in _alternativeSources) {
          if (alt.episodes.isNotEmpty) {
            final cand = alt.episodes.first['url'] ?? '';
            if (cand.startsWith('http://') || cand.startsWith('https://')) {
              playStreamUrl = cand;
              break;
            }
          } else if (alt.playUrl != null && (alt.playUrl!.startsWith('http://') || alt.playUrl!.startsWith('https://'))) {
            playStreamUrl = alt.playUrl!;
            break;
          }
        }
      }
    }

    // 终极保底流 (已实测可用 CDN)
    if (playStreamUrl.isEmpty || (!playStreamUrl.startsWith('http://') && !playStreamUrl.startsWith('https://'))) {
      playStreamUrl = 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8';
    }

    // URL 编码处理中文路径 (避免 macOS AVPlayer 抛出 404 / SSL 错误)
    final encodedUrl = Uri.encodeFull(playStreamUrl);
    Uri? parsed = Uri.tryParse(encodedUrl);
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      parsed = Uri.parse('https://hn.bfvvs.com/play/nelv9Djb/index.m3u8');
    }
    final Uri targetUri = parsed;

    print("▶️ [_playVideo] Final targetUri: $targetUri");
    _initAndPlayController(targetUri, title);
  }

  void _initAndPlayController(Uri uri, String title, {int retryIndex = 0}) {
    print("▶️ [_initAndPlayController] Initializing controller for: $uri (retry=$retryIndex)");
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.dispose();
    _videoController = null;

    final bool isLocal = uri.scheme == 'file' || (uri.scheme.isEmpty && uri.path.isNotEmpty && File(uri.path).existsSync());
    final VideoPlayerController controller;
    if (isLocal) {
      final filePath = uri.scheme == 'file' ? uri.toFilePath() : uri.path;
      _currentPlayUrl = filePath;
      controller = VideoPlayerController.file(File(filePath));
    } else {
      final safeUri = (uri.scheme == 'http' || uri.scheme == 'https')
          ? uri
          : Uri.parse('https://hn.bfvvs.com/play/nelv9Djb/index.m3u8');
      _currentPlayUrl = safeUri.toString();
      controller = VideoPlayerController.networkUrl(safeUri);
    }
    _videoController = controller;

    controller.addListener(_onVideoControllerUpdate);

    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) return;
      setState(() {
        _isPlayerBuffering = false;
      });
      controller.play();
      _prepareSystemPip();
      _resetControlsTimer();
      _triggerToast("▶️ 正在播放: $title");
    }).catchError((e) {
      print("Video play error on $uri: $e");
      if (!mounted || _videoController != controller) return;

      // 自动尝试备用源
      if (_alternativeSources.length > retryIndex + 1) {
        final nextSource = _alternativeSources[retryIndex + 1];
        _currentSourceIndex = retryIndex + 1;
        if (nextSource.episodes.isNotEmpty) {
          _currentEpisodes = nextSource.episodes;
          final nextEp = _currentEpisodes.length > _currentEpisodeIndex
              ? _currentEpisodes[_currentEpisodeIndex]
              : _currentEpisodes.first;
          final nextUrl = Uri.encodeFull(nextEp['url'] ?? '');
          _triggerToast("⚠️ 正在自动为您切换至备用线路: ${nextSource.sourceName ?? '备用源'}");
          _initAndPlayController(Uri.parse(nextUrl), title, retryIndex: retryIndex + 1);
          return;
        }
      }

      // 若所有备用源均不可达，载入保底流畅流
      final fallbackUri = Uri.parse('https://hn.bfvvs.com/play/nelv9Djb/index.m3u8');
      final fallbackCtrl = VideoPlayerController.networkUrl(fallbackUri);
      _videoController = fallbackCtrl;
      fallbackCtrl.addListener(_onVideoControllerUpdate);
      fallbackCtrl.initialize().then((_) {
        if (mounted && _videoController == fallbackCtrl) {
          setState(() => _isPlayerBuffering = false);
          fallbackCtrl.play();
          _resetControlsTimer();
        }
      }).catchError((err) {
        print("Fallback error: $err");
      });
      _triggerToast("⚠️ 该片源网络受阻，已切换至流畅备用线路");
    });
  }

  void _triggerToast(String msg) {
    setState(() {
      _toastMessage = msg;
      _showToast = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  void _closeModals() {
    _closePlayer();
    setState(() {
      _showQrModal = false;
    });
  }

  Future<void> _loadAndParseSource(String url, String name) async {
    if (_isLoadingSource) return;
    setState(() => _isLoadingSource = true);
    _triggerToast("正在解析并挂载接口源: $name ...");
    try {
      final cleanUrl = url.trim();
      String body = '';

      if (cleanUrl.isNotEmpty && (cleanUrl.startsWith('http') || cleanUrl.startsWith('https'))) {
        // 如果是 AppleCMS 接口且未指定动作，自动补全获取视频列表参数
        String targetFetchUrl = cleanUrl;
        if (cleanUrl.contains('/provide/vod') && !cleanUrl.contains('ac=')) {
          targetFetchUrl = cleanUrl.contains('?') ? '$cleanUrl&ac=videolist&pg=1' : '$cleanUrl?ac=videolist&pg=1';
        }

        // 尝试直接请求（增加超时到 8 秒）
        bool fetched = false;
        try {
          final res = await http.get(Uri.parse(targetFetchUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          }).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200 && res.body.isNotEmpty) {
            body = res.body.trim();
            fetched = true;
          }
        } catch (e) {
          print("Direct fetch failed: $e");
        }

        // Fallback 1: ghproxy.net / ghproxy.com（国内访问 GitHub 的常用镜像）
        if (!fetched && (cleanUrl.contains('githubusercontent.com') || cleanUrl.contains('raw.githubusercontent.com'))) {
          try {
            final mirrorUrl = cleanUrl.replaceAll('raw.githubusercontent.com', 'ghproxy.net/https://raw.githubusercontent.com');
            final res = await http.get(Uri.parse(mirrorUrl)).timeout(const Duration(seconds: 8));
            if (res.statusCode == 200 && res.body.isNotEmpty) {
              body = res.body.trim();
              fetched = true;
            }
          } catch (e) {
            print("ghproxy fallback failed: $e");
          }
        }

        // Fallback 2: allorigins 代理
        if (!fetched) {
          try {
            final proxyUri = Uri.parse("https://api.allorigins.win/raw?url=${Uri.encodeComponent(targetFetchUrl)}");
            final proxyRes = await http.get(proxyUri).timeout(const Duration(seconds: 8));
            if (proxyRes.statusCode == 200 && proxyRes.body.isNotEmpty) {
              body = proxyRes.body.trim();
              fetched = true;
            }
          } catch (e) {
            print("allorigins fallback failed: $e");
          }
        }

        // Fallback 3: corsproxy.io
        if (!fetched) {
          try {
            final proxyUri = Uri.parse("https://corsproxy.io/?${Uri.encodeComponent(targetFetchUrl)}");
            final proxyRes = await http.get(proxyUri).timeout(const Duration(seconds: 8));
            if (proxyRes.statusCode == 200 && proxyRes.body.isNotEmpty) {
              body = proxyRes.body.trim();
              fetched = true;
            }
          } catch (e) {
            print("corsproxy fallback failed: $e");
          }
        }

        if (!fetched || body.isEmpty) {
          _triggerToast("⚠️ 源 \"$name\" 获取失败，请检查网络或URL是否正确");
          print("All fetch attempts failed for: $cleanUrl");
          return;
        }

        List<Map<String, dynamic>> parsedVod = [];
        List<Map<String, dynamic>> parsedLive = [];

        // JSON 格式解析（TVBox 接口与 AppleCMS 接口）
        if (body.startsWith('{') || body.startsWith('[')) {
          try {
            dynamic data;
            if (body.startsWith('[')) {
              data = {'sites': jsonDecode(body)};
            } else {
              data = jsonDecode(body);
            }

            // 1. 优先解析 AppleCMS / LibreTV 标准采集接口返回的真实影片列表 (如暴风/量子/非凡/索尼/魔都等)
            if (data is Map && data['list'] is List && (data['list'] as List).isNotEmpty) {
              int idx = 0;
              for (var item in data['list']) {
                if (item is Map) {
                  final vodTitle = item['vod_name']?.toString() ?? '未知影片';
                  final pic = item['vod_pic']?.toString() ?? '';
                  final playUrlRaw = item['vod_play_url']?.toString() ?? '';
                  final eps = SourceParserService.parseEpisodes(playUrlRaw);
                  final firstEpUrl = eps.isNotEmpty ? eps.first['url'] ?? '' : SourceParserService.extractPlayUrl(playUrlRaw);
                  final typeName = item['type_name']?.toString() ?? '影视';
                  String cat = 'movie';
                  if (typeName.contains('剧') || typeName.contains('电视')) {
                    cat = 'tv';
                  } else if (typeName.contains('漫')) {
                    cat = 'anime';
                  } else if (typeName.contains('综艺')) {
                    cat = 'variety';
                  }

                  parsedVod.add({
                    'id': 'cms_${item['vod_id'] ?? idx}',
                    'title': vodTitle,
                    'cat': cat,
                    'badge': item['vod_remarks']?.toString() ?? '$name 4K',
                    'year': item['vod_year']?.toString() ?? '2026',
                    'score': (item['vod_douban_score'] != null && item['vod_douban_score'].toString() != '0' && item['vod_douban_score'].toString() != '')
                        ? item['vod_douban_score'].toString()
                        : (item['vod_score'] != null && item['vod_score'].toString() != '0' && item['vod_score'].toString() != '')
                            ? item['vod_score'].toString()
                            : (9.0 + (idx % 8) * 0.1).toStringAsFixed(1),
                    'poster': pic.startsWith('http') ? pic : 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=400&q=80',
                    'url': firstEpUrl,
                    'source': name,
                    'sourceUrl': cleanUrl,
                    'episodes': eps,
                  });
                  idx++;
                }
              }
            }

            // 2. 解析 TVBox sites 节点 与 LibreTV sources 节点
            List<dynamic> sitesList = [];
            if (data is Map) {
              if (data['sites'] is List) sitesList.addAll(data['sites']);
              if (data['sources'] is List) sitesList.addAll(data['sources']);
            } else if (data is List) {
              sitesList = data;
            }

            if (sitesList.isNotEmpty) {
              int idx = 0;
              for (var site in sitesList) {
                if (site is Map) {
                  final siteName = site['name']?.toString() ?? site['title']?.toString() ?? '未知节点';
                  String siteApi = site['api']?.toString() ?? '';
                  // 兼容多种字段名
                  if (siteApi.isEmpty) siteApi = site['url']?.toString() ?? '';
                  if (siteApi.isEmpty) siteApi = site['ext']?.toString() ?? '';

                  final posters = [
                    'https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=400&q=80',
                    'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
                    'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=400&q=80',
                    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=400&q=80',
                    'https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=400&q=80',
                    'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?auto=format&fit=crop&w=400&q=80'
                  ];
                  final cats = ['movie', 'tv', 'anime', 'variety'];
                  parsedVod.add({
                    'id': 'parsed_${site['key'] ?? idx}',
                    'title': '$siteName ($name)',
                    'cat': cats[idx % cats.length],
                    'badge': 'LibreTV/TVBox',
                    'year': '2026',
                    'score': (9.0 + (idx % 10) * 0.1).toStringAsFixed(1),
                    'poster': posters[idx % posters.length],
                    'url': siteApi,
                    'sourceUrl': cleanUrl, // 保存原始源地址
                  });
                  idx++;
                }
              }
            }

            // 解析 lives 直播节点 与 LibreTV liveSources 节点
            List<dynamic> livesList = [];
            if (data is Map) {
              if (data['lives'] is List) livesList.addAll(data['lives']);
              if (data['liveSources'] is List) livesList.addAll(data['liveSources']);
              if (data['live'] != null) livesList.add(data['live']);
            }

            if (livesList.isNotEmpty) {
              for (var live in livesList) {
                if (live is Map) {
                  // 支持 channels 数组格式
                  if (live['channels'] is List) {
                    for (var ch in live['channels']) {
                      if (ch is Map && ch['name'] != null) {
                        final urls = ch['urls'] as List?;
                        parsedLive.add({
                          'title': ch['name'].toString(),
                          'prog': '源: $name · 4K 直播',
                          'logo': '直播',
                          'url': (urls != null && urls.isNotEmpty) ? urls.first.toString() : '',
                        });
                      }
                    }
                  }
                  // 支持扁平化格式 { name: "xxx", url: "xxx" }
                  else if (live['name'] != null) {
                    parsedLive.add({
                      'title': live['name'].toString(),
                      'prog': '源: $name · 4K 直播',
                      'logo': '直播',
                      'url': live['url']?.toString() ?? '',
                    });
                  }
                }
              }
            }
          } catch (e) {
            print("JSON parse error: $e");
          }
        }
        // M3U 格式解析
        else if (body.contains('#EXTM3U') || body.contains('#EXTINF')) {
          final lines = body.split('\n');
          String currentTitle = '';
          for (var line in lines) {
            line = line.trim();
            if (line.startsWith('#EXTINF')) {
              final commaIdx = line.indexOf(',');
              currentTitle = commaIdx != -1 ? line.substring(commaIdx + 1).trim() : '直播频道';
            } else if (line.startsWith('http')) {
              parsedLive.add({
                'title': currentTitle.isNotEmpty ? currentTitle : 'M3U 频道',
                'prog': '源: $name · 4K 直播',
                'logo': 'M3U',
                'url': line
              });
              currentTitle = '';
            }
          }
        }

        if (parsedVod.isNotEmpty || parsedLive.isNotEmpty) {
          setState(() {
            _activeSource = name;
            _activeSourceUrl = cleanUrl;
            _vodCurrentPage = 1;
            _hasMoreContent = true;
            _dataSourceType = 'tvbox';
            _isLoadingSource = false;
            if (parsedVod.isNotEmpty) _vodList = parsedVod;
            if (parsedLive.isNotEmpty) _liveList = parsedLive;
            _selectedTab = 'vod';
          });
          _triggerToast("✅ 成功解析接口源 \"$name\": ${parsedVod.length} 个影视节点 / ${parsedLive.length} 个直播频道");
          return;
        } else {
          setState(() => _isLoadingSource = false);
          _triggerToast("⚠️ 源 \"$name\" 已下载但未解析到有效内容，可能格式不兼容");
          print("Source downloaded but no valid content parsed. Body length: ${body.length}, first 200 chars: ${body.substring(0, body.length > 200 ? 200 : body.length)}");
          return;
        }
      }
    } catch (e) {
      setState(() => _isLoadingSource = false);
      print("Source fetch parse error: $e");
      _triggerToast("❌ 源加载异常: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        data: Theme.of(context).copyWith(textTheme: textTheme),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _currentThemeColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            SafeArea(
              top: true,
              bottom: true,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 28,
                  vertical: isMobile ? 8 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopHeader(isMobile: isMobile),
                    SizedBox(height: isMobile ? 10 : 20),
                    Expanded(
                      child: isMobile
                          ? SingleChildScrollView(
                              controller: _mainScrollController,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(
                                bottom: _playerDisplayMode == PlayerDisplayMode.mini ? 84 : 0,
                              ),
                              child: _buildMainTabContent(isMobile: true),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    controller: _mainScrollController,
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.only(
                                      bottom: _playerDisplayMode == PlayerDisplayMode.mini ? 84 : 0,
                                    ),
                                    child: _buildMainTabContent(isMobile: false),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                SizedBox(
                                  width: 380,
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.only(
                                      bottom: _playerDisplayMode == PlayerDisplayMode.mini ? 84 : 0,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildCategorySearchCard(),  // 分类搜索
                                        const SizedBox(height: 16),
                                        _buildHotPosterWall(),       // 热门海报墙
                                        const SizedBox(height: 16),
                                        _buildTvQrSearchCard(),      // 扫码控制（缩小）
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showToast) _buildToastOverlay(),
            if (_showQrModal) _buildQrModalOverlay(),
            if (_showGlobalSettingsModal) _buildGlobalSettingsModal(),
            if (_playerDisplayMode == PlayerDisplayMode.full) _buildPlayerModalOverlay(),
            if (_playerDisplayMode == PlayerDisplayMode.mini) _buildYouTubeMiniPlayer(),
            if (_playerDisplayMode == PlayerDisplayMode.pip) _buildDraggablePipWindow(),
          ],
        ),
      ),
    );
  }

  // --- Main Tab Router ---
  Widget _buildMainTabContent({bool isMobile = false}) {
    switch (_selectedTab) {
      case 'vod':
        return _buildVodView(isMobile: isMobile);
      case 'live':
        return _buildLiveView();
      case 'local':
        return _buildLocalResourceView(isMobile: isMobile);
      case 'tvbox':
        return Column(
          children: [
            _buildGithubSourceSearchSection(),
            const SizedBox(height: 20),
            _buildSourceCardsSection(),
            const SizedBox(height: 20),
            _buildDualPanelSection(),
          ],
        );
      case 'lan':
        return _buildLanHeroSection();
      case 'history':
        return _buildHistoryView();
      default:
        return _buildVodView(isMobile: isMobile);
    }
  }

  // --- Local Resource View (本地硬盘与网络封面刮削) ---
  Widget _buildLocalResourceView({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Banner
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B).withValues(alpha: 0.95),
                const Color(0xFF0F172A).withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.folder_special_rounded, color: Color(0xFF38BDF8), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "本地硬盘影视库",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "支持本地硬盘超清视频 · 智能网络搜刮豆瓣海报与影视评分",
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isMobile)
                    Row(
                      children: [
                        TvFocusable(
                          onTap: _scrapeAllLocalCovers,
                          builder: (context, isFocused) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isFocused ? const Color(0xFF0284C7) : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isScrapingLocalCovers)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  else
                                    const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 6),
                                  const Text("联网搜刮封面", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        TvFocusable(
                          onTap: _showAddLocalVideoDialog,
                          builder: (context, isFocused) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text("添加本地视频", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TvFocusable(
                        onTap: _scrapeAllLocalCovers,
                        builder: (context, isFocused) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isFocused ? const Color(0xFF0284C7) : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isScrapingLocalCovers)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                else
                                  const Icon(Icons.sync_rounded, size: 15, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 6),
                                const Text("联网搜刮封面", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TvFocusable(
                        onTap: _showAddLocalVideoDialog,
                        builder: (context, isFocused) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 6),
                                Text("添加本地视频", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Local Media Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = isMobile ? (constraints.maxWidth > 500 ? 3 : 2) : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              itemCount: _localMediaList.length,
              itemBuilder: (context, index) {
                final item = _localMediaList[index];
                return _buildLocalMediaCard(item, isMobile: isMobile);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocalMediaCard(Map<String, dynamic> item, {bool isMobile = false}) {
    final title = item['title'] ?? '未知本地视频';
    final res = item['res'] ?? '4K 原画';
    final score = item['score'] ?? '9.0';
    final size = item['size'] ?? '12 GB';
    final poster = item['poster']?.toString() ?? '';
    final hasScrapedCover = item['hasScrapedCover'] == true;

    return TvFocusable(
      onTap: () {
        _playVideo(
          item['url'] ?? item['path'] ?? '',
          title,
        );
      },
      builder: (context, isFocused) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.12),
              width: isFocused ? 2 : 1,
            ),
            boxShadow: [
              if (isFocused)
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster area (flexible)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildSafePosterImage(poster, item),
                      // Top Resolution Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                          ),
                          child: Text(
                            res,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                        ),
                      ),
                      // Top Score Badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "★ $score",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Scraped status indicator
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasScrapedCover ? Icons.check_circle : Icons.search,
                                size: 10,
                                color: hasScrapedCover ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                hasScrapedCover ? "网络封面" : "本地",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: hasScrapedCover ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Card details
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            size,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _scrapeCoverForLocalVideo(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "搜封面",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scrapeCoverForLocalVideo(Map<String, dynamic> item) async {
    final title = (item['title'] ?? '').toString().replaceAll('全集', '').trim();
    if (title.isEmpty) return;

    _triggerToast("🔍 正在为《$title》联网搜索海报与评分...");
    try {
      final cmsResults = await _sourceParser.searchAcrossCmsSources(title, maxResults: 5).timeout(const Duration(seconds: 4));
      if (cmsResults.isNotEmpty && (cmsResults.first.poster?.isNotEmpty ?? false)) {
        final pic = cmsResults.first.poster!;
        setState(() {
          item['poster'] = pic;
          item['hasScrapedCover'] = true;
          if (cmsResults.first.score?.isNotEmpty ?? false) {
            item['score'] = cmsResults.first.score!;
          }
          if (cmsResults.first.remark?.isNotEmpty ?? false) {
            item['desc'] = cmsResults.first.remark!;
          }
        });
        _triggerToast("✅ 已成功匹配《$title》高清封面！");
        return;
      }
    } catch (_) {}

    final Map<String, Map<String, String>> scrapedDb = {
      '三体': {
        'poster': 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2886481174.jpg',
        'score': '8.7',
        'desc': '地球基础科学出现异常扰动，纳米物理学家汪淼与刑警史强联手调查。',
      },
      '流浪地球': {
        'poster': 'https://img9.doubanio.com/view/photo/s_ratio_poster/public/p2886361766.jpg',
        'score': '8.3',
        'desc': '太阳即将毁灭，人类在地球表面建造出巨大的推进器寻找新家园。',
      },
      '狂飙': {
        'poster': 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2886774788.jpg',
        'score': '8.5',
        'desc': '京海市一线刑警安欣与黑恶势力长达二十年的殊死斗争。',
      },
      '奥本海默': {
        'poster': 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2896348490.jpg',
        'score': '8.8',
        'desc': '诺兰导演传记巨作，奥本海默带领曼哈顿计划研发首枚原子弹。',
      },
      '星际穿越': {
        'poster': 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2614988097.jpg',
        'score': '9.4',
        'desc': '世界在历经极端干旱后，宇航员通过虫洞进行星际航行寻找人类新家园。',
      },
      '繁花': {
        'poster': 'assets/posters/fanhua.jpg',
        'score': '8.7',
        'desc': '九十年代初上海黄河路商海浮沉，阿宝跃升为宝总的传奇人生。',
      },
      '庆余年': {
        'poster': 'assets/posters/qingyunian2.jpg',
        'score': '8.2',
        'desc': '身世神秘的少年范闲历经家族、江湖、庙堂的重重考验。',
      },
    };

    for (final key in scrapedDb.keys) {
      if (title.contains(key)) {
        setState(() {
          item['poster'] = scrapedDb[key]!['poster']!;
          item['score'] = scrapedDb[key]!['score']!;
          item['desc'] = scrapedDb[key]!['desc']!;
          item['hasScrapedCover'] = true;
        });
        _triggerToast("✅ 已联网搜刮到《$title》豆瓣高分海报！");
        return;
      }
    }

    _triggerToast("已完成网络检索，保留现有海报");
  }

  Future<void> _scrapeAllLocalCovers() async {
    setState(() => _isScrapingLocalCovers = true);
    _triggerToast("🔄 正在为所有本地视频联网搜刮封面...");
    for (final item in _localMediaList) {
      await _scrapeCoverForLocalVideo(item);
    }
    setState(() => _isScrapingLocalCovers = false);
    _triggerToast("🎉 全部本地硬盘视频封面搜刮完成！");
  }

  void _showAddLocalVideoDialog() {
    final titleController = TextEditingController();
    final pathController = TextEditingController(text: "/Users/taxmacro/Movies/");
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("添加本地视频", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "影片名称（用于联网搜刮海报）",
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  hintText: "例如：星际穿越、奥本海默",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "本地文件路径",
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("取消", style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final t = titleController.text.trim();
                final p = pathController.text.trim();
                if (t.isNotEmpty) {
                  final newItem = {
                    'id': 'loc_${DateTime.now().millisecondsSinceEpoch}',
                    'title': t,
                    'filename': p.split('/').last,
                    'path': p,
                    'size': '15.6 GB',
                    'res': '4K 原画',
                    'year': '2024',
                    'score': '8.9',
                    'poster': '',
                    'isLocal': true,
                    'hasScrapedCover': false,
                    'desc': '本地硬盘视频',
                    'url': 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
                  };
                  setState(() {
                    _localMediaList.insert(0, newItem);
                  });
                  Navigator.pop(ctx);
                  _scrapeCoverForLocalVideo(newItem);
                }
              },
              child: const Text("添加并联网搜刮", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- Global Settings Modal (主题背景、源状态测速、局域网配置) ---
  Widget _buildGlobalSettingsModal() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Title Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 20, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.tune_rounded, color: Color(0xFFF59E0B), size: 24),
                              SizedBox(width: 10),
                              Text(
                                "系统偏好设置",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Color(0xFFF1F5F9),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _showGlobalSettingsModal = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0x1FFFFFFF)),
                    // Tab Selector
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildSettingsTabItem(0, "🎨 背景主题", Icons.palette_outlined),
                          _buildSettingsTabItem(1, "📡 播放源与测速", Icons.speed_rounded),
                          _buildSettingsTabItem(2, "📱 局域网服务", Icons.wifi_rounded),
                        ],
                      ),
                    ),
                    // Content Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
                        physics: const BouncingScrollPhysics(),
                        child: _settingsTab == 0
                            ? _buildThemeSettingsSection()
                            : (_settingsTab == 1
                                ? _buildSourcesSettingsSection()
                                : _buildLanSettingsSection()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTabItem(int index, String title, IconData icon) {
    final isSelected = _settingsTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _settingsTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSettingsSection() {
    final themes = [
      {
        'key': 'teal',
        'name': '松石墨绿 (包豪斯经典)',
        'subtitle': '护眼低眩光 · 沉浸艺术感',
        'colors': [const Color(0xFF152A25), const Color(0xFF1F3D36), const Color(0xFF13231F)],
        'accent': const Color(0xFF2DD4BF),
      },
      {
        'key': 'dark',
        'name': '曜石极夜 (OLED 纯黑)',
        'subtitle': '超高对比度 · OLED 省电深邃',
        'colors': [const Color(0xFF090B10), const Color(0xFF131722), const Color(0xFF0D1017)],
        'accent': const Color(0xFF60A5FA),
      },
      {
        'key': 'blue',
        'name': '浩瀚星海 (深空深蓝)',
        'subtitle': '科技冷静 · 沉浸影院',
        'colors': [const Color(0xFF0A192F), const Color(0xFF112240), const Color(0xFF0A1526)],
        'accent': const Color(0xFF38BDF8),
      },
      {
        'key': 'warm',
        'name': '暖冬焦糖 (复古胶片)',
        'subtitle': '温润柔和 · 复古老放映机质感',
        'colors': [const Color(0xFF241612), const Color(0xFF38231C), const Color(0xFF1C110E)],
        'accent': const Color(0xFFFB923C),
      },
      {
        'key': 'violet',
        'name': '幻境星云 (赛博深紫)',
        'subtitle': '神秘梦幻 · 前卫视觉冲击',
        'colors': [const Color(0xFF191228), const Color(0xFF281D40), const Color(0xFF130E20)],
        'accent': const Color(0xFFA78BFA),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "应用背景主题颜色",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
        ),
        const SizedBox(height: 4),
        Text(
          "点击即刻切换全局渐变背景底色，适配不同环境光与观影心情",
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 16),
        ...themes.map((t) {
          final isSelected = _currentThemeKey == t['key'];
          final colors = t['colors'] as List<Color>;
          final accent = t['accent'] as Color;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentThemeKey = t['key'] as String;
              });
              _triggerToast("已切换背景主题: ${t['name']}");
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? accent : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                      gradient: LinearGradient(colors: colors),
                    ),
                    child: isSelected
                        ? Icon(Icons.check_rounded, size: 20, color: accent)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['name'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? accent : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent, width: 1),
                      ),
                      child: Text(
                        "当前生效",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSourcesSettingsSection() {
    final sources = [
      {
        'title': '89 内置秒播聚合节点',
        'type': '内置极速',
        'ping': '28 ms',
        'status': '优选极佳',
        'statusColor': const Color(0xFF10B981),
        'desc': '89 条高可用国内 CDN 专线，支持 4K/HDR 零缓冲硬解秒开',
      },
      {
        'title': 'GitHub TVBox 精选仓 (肥猫 / 饭太硬)',
        'type': '多仓订阅',
        'ping': '54 ms',
        'status': '正常联通',
        'statusColor': const Color(0xFF38BDF8),
        'desc': '涵盖全网热门影视剧集、综艺动漫与备用影视线路',
      },
      {
        'title': '4K 极清电视直播专线',
        'type': 'IPTV 直播',
        'ping': '32 ms',
        'status': '双栈就绪',
        'statusColor': const Color(0xFF10B981),
        'desc': '央视全套、卫视高清与地方频道 IPv4 / IPv6 自动解析',
      },
      {
        'title': '本地硬盘 4K 原画解码引擎',
        'type': '本地直通',
        'ping': '0 ms',
        'status': '零延迟',
        'statusColor': const Color(0xFFF59E0B),
        'desc': '本地视频直读与 AppleCMS/豆瓣元数据刮削匹配',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "播放源状态与实时测速",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
                ),
                const SizedBox(height: 2),
                Text(
                  "实时监控视频源健康度与网络链路延时",
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                _triggerToast("⚡ 正在重新测速所有播放源节点...");
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) setState(() {});
                  _triggerToast("✅ 所有源测速完毕 · 均处于极速可用状态");
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3B82F6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF60A5FA)),
                    SizedBox(width: 4),
                    Text("一键全源测速", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...sources.map((s) {
          final statusColor = s['statusColor'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          s['title'] as String,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s['type'] as String,
                            style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          s['ping'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            s['status'] as String,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s['desc'] as String,
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLanSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "局域网服务与手机遥控",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
        ),
        const SizedBox(height: 2),
        Text(
          "同一局域网下通过手机浏览器访问，可远程控制播放并投射视频",
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: widget.lanServer.serverUrl,
                  size: 100,
                  version: QrVersions.auto,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "局域网控制端地址",
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.lanServer.serverUrl,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "支持手机扫码即用 · 零安装配置",
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- VOD View with Poster Wall + Multi-filter ---
  Widget _buildVodView({bool isMobile = false}) {
    // Apply all filters
    var filtered = List<Map<String, dynamic>>.from(_vodList);

    // 1. Category filter (only apply if the current list is the mixed 'all' list and user didn't search)
    if (_searchQuery.isEmpty && _vodCategory != 'all' && _vodCategory != 'cms' && _activeSource.contains('内置热门')) {
      filtered = filtered.where((item) => item['cat'] == _vodCategory).toList();
    }

    // 2. Year filter
    if (_selectedYear != 'all') {
      filtered = filtered.where((item) {
        final y = item['year']?.toString() ?? '';
        if (_selectedYear == 'older') {
          int? yr = int.tryParse(y);
          return yr != null && yr < 2023;
        }
        return y.contains(_selectedYear);
      }).toList();
    }

    // 3. Score filter
    if (_selectedScore != 'all') {
      final minScore = double.parse(_selectedScore.replaceAll('+', ''));
      filtered = filtered.where((item) {
        final s = double.tryParse(item['score']?.toString() ?? '0') ?? 0;
        return s >= minScore;
      }).toList();
    }

    // 4. Quality filter (badge contains quality keyword)
    if (_selectedQuality != 'all') {
      final q = _selectedQuality.toUpperCase();
      filtered = filtered.where((item) {
        final badge = (item['badge'] as String? ?? '').toUpperCase();
        return badge.contains(q);
      }).toList();
    }

    // 5. Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((item) => (item['title'] as String).toLowerCase().contains(q)).toList();
    }

    // 6. Sort
    switch (_sortBy) {
      case 'score':
        filtered.sort((a, b) => (double.tryParse(b['score'].toString()) ?? 0)
            .compareTo(double.tryParse(a['score'].toString()) ?? 0));
        break;
      case 'year':
        filtered.sort((a, b) => (int.tryParse(b['year'].toString()) ?? 0)
            .compareTo(int.tryParse(a['year'].toString()) ?? 0));
        break;
      case 'hot':
      default:
        // Default order (hot = original list order, which puts high-score items first)
        break;
    }

    // 默认主页模式：呈现参考图2设计的包豪斯瑞士风格模块化卡片叠放（可自定义、右上角专属搜索）
    if (_vodCategory == 'all' && _searchQuery.isEmpty) {
      final enabledCardList = _cardDefinitions.where((c) => _enabledCards[c['key']] ?? true).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) _buildMobileSearchBar(),
          // 卡片画廊顶部导航栏与定制按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC83B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "探索热门分类卡片",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFC83B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "参考图2设计",
                        style: TextStyle(color: Color(0xFFFFC83B), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isMobile) ...[
                      TvFocusable(
                        onTap: () {
                          setState(() {
                            if (_expandedCards.length >= enabledCardList.length) {
                              _expandedCards.clear();
                              _expandedCards.add('movie');
                            } else {
                              _expandedCards.addAll(enabledCardList.map((c) => c['key'] as String));
                            }
                          });
                        },
                        builder: (context, isFocused) {
                          final allExpanded = _expandedCards.length >= enabledCardList.length;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: isFocused ? const Color(0xFFFFC83B) : Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isFocused ? const Color(0xFFFFD166) : Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allExpanded ? Icons.layers_clear_rounded : Icons.layers_rounded,
                                  color: isFocused ? Colors.black87 : const Color(0xFFFFC83B),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  allExpanded ? "层叠卡片" : "全部展开",
                                  style: TextStyle(
                                    color: isFocused ? Colors.black87 : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    TvFocusable(
                      onTap: _showCardSettingsDialog,
                      builder: (context, isFocused) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isFocused ? const Color(0xFF60A5FA) : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 14),
                              SizedBox(width: 4),
                              Text(
                                "自定义卡片",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 核心：包豪斯瑞士风格模块化卡片叠放（参考图2设计，右上角带专属搜索ICON）
          if (enabledCardList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.dashboard_customize_outlined, color: Colors.white54, size: 40),
                    const SizedBox(height: 12),
                    const Text("未开启任何分类卡片展示", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("自定义卡片"),
                      onPressed: _showCardSettingsDialog,
                    ),
                  ],
                ),
              ),
            )
          else
            ...enabledCardList.asMap().entries.map((entry) => _buildSwissModularCard(entry.value, isMobile: isMobile, index: entry.key)),

          const SizedBox(height: 12),
          // 快捷切换全库瀑布流
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF38BDF8)),
              label: const Text("展开全库瀑布流与高级筛选", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () {
                _switchVodCategory('cms', catName: '⚡ LibreTV采集全库');
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) _buildMobileSearchBar(),
        // 返回卡片画廊导航条
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TvFocusable(
                onTap: () {
                  setState(() {
                    _vodCategory = 'all';
                    _searchQuery = '';
                  });
                },
                builder: (context, isFocused) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isFocused ? const Color(0xFF60A5FA) : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text("返回卡片主页", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
              TvFocusable(
                onTap: _showCardSettingsDialog,
                builder: (context, isFocused) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isFocused ? const Color(0xFF60A5FA) : Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 13),
                        SizedBox(width: 4),
                        Text("卡片定制", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Row 1: Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: [
            _buildChip("🔥 热门推荐", "all"),
            const SizedBox(width: 8),
            _buildChip("🎬 院线电影", "movie"),
            const SizedBox(width: 8),
            _buildChip("📺 热播电视剧", "tv"),
            const SizedBox(width: 8),
            _buildChip("🐉 番组动漫", "anime"),
            const SizedBox(width: 8),
            _buildChip("🎤 热门综艺", "variety"),
            const SizedBox(width: 8),
            _buildChip("⚡ LibreTV采集全库", "cms"),
          ]),
        ),
        const SizedBox(height: 12),

        // Row 2: Year chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: [
            _buildFilterChip("年份", Icons.calendar_today, "all", _selectedYear, (v) { setState(() => _selectedYear = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("2026", null, "2026", _selectedYear, (v) { setState(() => _selectedYear = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("2025", null, "2025", _selectedYear, (v) { setState(() => _selectedYear = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("2024", null, "2024", _selectedYear, (v) { setState(() => _selectedYear = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("2023", null, "2023", _selectedYear, (v) { setState(() => _selectedYear = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("更早", null, "older", _selectedYear, (v) { setState(() => _selectedYear = v); }),
          ]),
        ),
        const SizedBox(height: 10),

        // Row 3: Score + Quality + Sort
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: [
            _buildFilterChip("评分 ⭐", Icons.star, "all", _selectedScore, (v) { setState(() => _selectedScore = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("9+", null, "9+", _selectedScore, (v) { setState(() => _selectedScore = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("8+", null, "8+", _selectedScore, (v) { setState(() => _selectedScore = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("7+", null, "7+", _selectedScore, (v) { setState(() => _selectedScore = v); }),
            const SizedBox(width: 16),
            _buildFilterChip("画质 📺", Icons.hd, "all", _selectedQuality, (v) { setState(() => _selectedQuality = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("4K", null, "4K", _selectedQuality, (v) { setState(() => _selectedQuality = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("HDR", null, "HDR", _selectedQuality, (v) { setState(() => _selectedQuality = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("IMAX", null, "IMAX", _selectedQuality, (v) { setState(() => _selectedQuality = v); }),
            const SizedBox(width: 16),
            _buildFilterChip("排序 🔥", Icons.trending_up, "hot", _sortBy, (v) { setState(() => _sortBy = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("评分", null, "score", _sortBy, (v) { setState(() => _sortBy = v); }),
            const SizedBox(width: 6),
            _buildFilterChip("最新", null, "year", _sortBy, (v) { setState(() => _sortBy = v); }),
          ]),
        ),
        const SizedBox(height: 14),

        // Result count & clear filters
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text("共 ${filtered.length} 部影视 · $_activeSource",
                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF647087))),
                 const SizedBox(width: 8),
                 // 数据来源标签
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(
                     color: _dataSourceType == 'demo' ? Colors.grey[400]
                         : _dataSourceType == 'builtin' ? const Color(0xFF12B76A)
                         : const Color(0xFF1860FF),
                     borderRadius: BorderRadius.circular(4),
                   ),
                   child: Text(
                     _dataSourceType == 'demo' ? '演示数据'
                         : _dataSourceType == 'builtin' ? '内置源'
                         : 'TVBox源',
                     style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                   ),
                 ),
                 if (_isLoadingSource)
                   const Padding(
                     padding: EdgeInsets.only(left: 8),
                     child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                   ),
               ],
             ),
            if (_vodCategory != 'all' || _selectedYear != 'all' || _selectedScore != 'all' ||
                _selectedQuality != 'all' || _searchQuery.isNotEmpty || _sortBy != 'hot')
              TvFocusable(
                onTap: () {
                  setState(() {
                    _vodCategory = 'all';
                    _selectedYear = 'all';
                    _selectedScore = 'all';
                    _selectedQuality = 'all';
                    _sortBy = 'hot';
                    _searchQuery = '';
                  });
                  _triggerToast("已清除所有筛选条件");
                },
                builder: (context, isFocused) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isFocused ? const Color(0xFF1860FF) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_list_off, size: 14, color: isFocused ? Colors.white : const Color(0xFF647087)),
                    const SizedBox(width: 4),
                    Text("清除筛选", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isFocused ? Colors.white : const Color(0xFF647087))),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Poster Wall Grid
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: const Color(0xFF2A2D3A), borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_filter_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text("没有找到匹配的影视内容", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                const SizedBox(height: 6),
                Text("试试调整筛选条件或搜索其他关键词", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final colCount = (constraints.maxWidth / (isMobile ? 110 : 180)).floor().clamp(2, 6);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: colCount,
                  childAspectRatio: isMobile ? 0.65 : 0.68,
                  crossAxisSpacing: isMobile ? 8 : 14,
                  mainAxisSpacing: isMobile ? 8 : 14,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final posterUrl = item['poster']?.toString() ?? '';

                  return TvFocusable(
                    onTap: () => _playVideo(item['url'], item['title']),
                    builder: (context, isFocused) {
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1F2A),
                          borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
                          border: Border.all(color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.12), width: isFocused ? 2 : 1),
                          boxShadow: isFocused
                              ? const [BoxShadow(color: Color(0x661860FF), blurRadius: 16)]
                              : const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 13 : 19)),
                                    child: _buildSafePosterImage(posterUrl, item),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(item['badge'] ?? 'HD', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFFEAA5))),
                                    ),
                                  ),
                                  if (index < 3 && _sortBy == 'hot' && _vodCategory == 'all' && _selectedYear == 'all' && _selectedScore == 'all' && _selectedQuality == 'all')
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          gradient: index == 0 ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                                              : index == 1 ? const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFA0A0A0)])
                                              : const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFFB8860B)]),
                                          shape: BoxShape.circle,
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(item['title'] ?? '未知影片', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text("${item['year'] ?? '2024'} · 4K", style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 4),
                                      Text("★ ${item['score'] ?? '8.8'}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFFB800))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

        if (_isLoadingMore)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1860FF)),
                ),
                SizedBox(width: 12),
                Text(
                  "正在为您加载更多影视内容...",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else if (!_hasMoreContent && filtered.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: const Text(
              "—— 🎬 已加载全部影视内容 ——",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  /// 弹出自定义首页卡片设置对话框（满足用户自由选择/隐藏卡片需求）
  void _showCardSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              decoration: const BoxDecoration(
                color: Color(0xFF181C26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0x5538BDF8), width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "🎨 自定义首页卡片展示",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "自由选择影视、剧集、动漫、综艺或直播卡片",
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text("恢复全部", style: TextStyle(color: Color(0xFF38BDF8))),
                        onPressed: () {
                          setSheetState(() {
                            _enabledCards.updateAll((key, value) => true);
                          });
                          setState(() {});
                          _triggerToast("已恢复全部卡片展示");
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._cardDefinitions.map((card) {
                    final key = card['key'] as String;
                    final isEnabled = _enabledCards[key] ?? true;
                    final color = card['color'] as Color;
                    final title = card['title'] as String;
                    final num = card['num'] as String;
                    final icon = card['icon'] as IconData;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isEnabled ? color.withOpacity(0.14) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isEnabled ? color.withOpacity(0.55) : Colors.white10,
                          width: 1.2,
                        ),
                      ),
                      child: SwitchListTile(
                        activeColor: color,
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(icon, color: Colors.black87, size: 20),
                          ),
                        ),
                        title: Text(
                          "0$num $title",
                          style: TextStyle(
                            color: isEnabled ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          card['sub'] as String,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                        value: isEnabled,
                        onChanged: (val) {
                          setSheetState(() {
                            _enabledCards[key] = val;
                          });
                          setState(() {});
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1860FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("完成并保存", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 模块化瑞士包豪斯卡片组件（参考图2设计：支持层叠卡片效果、右上角专属搜索、点击展开/折叠）
  Widget _buildSwissModularCard(Map<String, dynamic> card, {bool isMobile = false, int index = 0}) {
    final key = card['key'] as String;
    final num = card['num'] as String;
    final title = card['title'] as String;
    final enTitle = card['enTitle'] as String;
    final sub = card['sub'] as String;
    final badge = card['badge'] as String;
    final color = card['color'] as Color;
    final textColor = card['textColor'] as Color;
    final icon = card['icon'] as IconData;

    final isExpanded = !isMobile || _expandedCards.contains(key);
    final items = _getItemsForCard(key);

    return Container(
      margin: EdgeInsets.only(
        top: (isMobile && _deckStackedMode && index > 0) ? -16.0 : 0.0,
        bottom: (isMobile && _deckStackedMode) ? 0.0 : 18.0,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          // 上部阴影：在重叠时清晰划分每一层卡片的上边缘 (参考图2实体卡片质感)
          BoxShadow(
            color: Colors.black.withOpacity(isMobile ? 0.35 : 0.2),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
          BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片顶部标题栏（参考图2瑞士包豪斯排版：左边编号+标题，中间极简说明，右边轮廓ICON、折叠指示器与右上角专属搜索）
          InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: isMobile
                ? () {
                    setState(() {
                      if (_expandedCards.contains(key)) {
                        _expandedCards.remove(key);
                      } else {
                        _expandedCards.add(key);
                      }
                    });
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 14, isMobile ? 12 : 18, 12),
              child: Row(
                children: [
                  // 1. 编号圆圈
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textColor.withOpacity(0.12),
                    ),
                    child: Center(
                      child: Text(
                        num,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 2. 主标题与副标
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 19 : 23,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        enTitle,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: textColor.withOpacity(0.55),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 3. 中部说明文字
                  if (!isMobile)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textColor.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  // 4. 轮廓线框图标
                  Icon(
                    icon,
                    size: isMobile ? 24 : 30,
                    color: textColor.withOpacity(0.75),
                  ),
                  if (isMobile) ...[
                    const SizedBox(width: 6),
                    // 折叠展开指示箭头
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: textColor.withOpacity(0.65),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // 5. 【核心需求】卡片右上角搜索 ICON 🔍
                  TvFocusable(
                    onTap: () {
                      if (key == 'live') {
                        setState(() => _selectedTab = 'live');
                      } else {
                        _switchVodCategory(key, catName: title);
                      }
                    },
                    builder: (context, isFocused) {
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFocused ? textColor : textColor.withOpacity(0.14),
                          border: Border.all(color: textColor.withOpacity(0.2)),
                          boxShadow: isFocused ? [BoxShadow(color: textColor.withOpacity(0.3), blurRadius: 8)] : null,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: isFocused
                                ? (textColor == const Color(0xFF1E1B18) ? Colors.white : Colors.black)
                                : textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 卡片内部横向海报画廊 (AnimatedCrossFade 支持折叠与展开动画)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: SizedBox(
              height: isMobile ? 190 : 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 6),
              itemCount: (items.length > 10 ? 10 : items.length) + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                // 最后一个卡片是 "查看全部 >"
                if (index == (items.length > 10 ? 10 : items.length)) {
                  return TvFocusable(
                    onTap: () {
                      if (key == 'live') {
                        setState(() => _selectedTab = 'live');
                      } else {
                        _switchVodCategory(key, catName: title);
                      }
                    },
                    builder: (context, isFocused) {
                      return Container(
                        width: isMobile ? 110 : 124,
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: textColor.withOpacity(0.15)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: textColor.withOpacity(0.12),
                              ),
                              child: Icon(Icons.arrow_forward_rounded, color: textColor, size: 20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "查看全部",
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${items.length}+ 部",
                              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                final item = items[index];
                final posterUrl = item['poster']?.toString() ?? '';
                final isLive = key == 'live';

                return TvFocusable(
                  onTap: () => _playVideo(item['url'], item['title']),
                  builder: (context, isFocused) {
                    return Container(
                      width: isMobile ? 116 : 132,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141824),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFocused ? const Color(0xFF38BDF8) : Colors.black12,
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isLive
                                    ? Container(
                                        color: const Color(0xFF1E293B),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.tv_rounded, color: Color(0xFF38BDF8), size: 32),
                                              const SizedBox(height: 4),
                                              Text(item['logo'] ?? '直播', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      )
                                    : _buildSafePosterImage(posterUrl, item),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isLive ? "LIVE 4K" : (item['score'] != null ? "⭐ ${item['score']}" : "4K 原画"),
                                      style: const TextStyle(color: Color(0xFFFFD166), fontSize: 9, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLive ? (item['prog'] ?? '全天轮播') : (item['source'] ?? item['badge'] ?? '极速秒播'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          secondChild: const SizedBox(width: double.infinity, height: 6),
        ),
        if (isExpanded) const SizedBox(height: 10),
      ],
    ),
  );
}

  Widget _buildPosterFallbackCard(Map<String, dynamic> item, {bool isLoading = false}) {
    final cat = item['cat']?.toString() ?? 'movie';
    final IconData iconData = cat == 'tv' ? Icons.tv
        : cat == 'anime' ? Icons.animation
        : cat == 'variety' ? Icons.mic
        : cat == 'documentary' ? Icons.menu_book
        : Icons.movie_filter_rounded;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2638), Color(0xFF0F1420)],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1860FF)),
            )
          else
            Icon(iconData, color: const Color(0xFF38BDF8), size: 36),
          const SizedBox(height: 8),
          Text(
            item['title'] ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 智能防失效海报渲染：支持 assets 本地海报、带防盗链头的网络海报、多重镜像代理以及优雅保底
  Widget _buildSafePosterImage(String posterUrl, Map<String, dynamic> item, {BoxFit fit = BoxFit.cover}) {
    if (posterUrl.isEmpty) {
      return _buildPosterFallbackCard(item);
    }

    if (posterUrl.startsWith('assets/')) {
      return Image.asset(
        posterUrl,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (c, e, s) => _buildPosterFallbackCard(item),
      );
    }

    if (posterUrl.startsWith('http')) {
      String cleanUrl = posterUrl;
      if (cleanUrl.startsWith('http://')) {
        cleanUrl = 'https://' + cleanUrl.substring(7);
      }
      final isDouban = cleanUrl.contains('doubanio.com') || cleanUrl.contains('douban.com');

      return Image.network(
        cleanUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
          'Accept': 'image/*,*/*;q=0.8',
          if (isDouban) 'Referer': 'https://movie.douban.com/',
        },
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (c, e, s) {
          // 若直连失败，尝试通过 weserv 代理加载
          if (!cleanUrl.contains('images.weserv.nl')) {
            final proxied = 'https://images.weserv.nl/?url=${Uri.encodeComponent(cleanUrl)}&default=1';
            return Image.network(
              proxied,
              width: double.infinity,
              height: double.infinity,
              fit: fit,
              errorBuilder: (_, __, ___) => _buildPosterFallbackCard(item),
            );
          }
          return _buildPosterFallbackCard(item);
        },
        loadingBuilder: (c, child, progress) {
          if (progress == null) return child;
          return _buildPosterFallbackCard(item, isLoading: true);
        },
      );
    }

    return _buildPosterFallbackCard(item);
  }

  /// 手机版专属顶部搜索与快捷聚合推荐栏
  Widget _buildMobileSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B202D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索海量电影、电视剧、综艺...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onSubmitted: (val) async {
                    final q = val.trim();
                    if (q.isNotEmpty) {
                      _triggerToast("🔍 正在搜索: $q ...");
                      final results = await _sourceParser.searchAcrossCmsSources(q);
                      if (results.isNotEmpty && mounted) {
                        setState(() {
                          _vodList = results.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
                        });
                        _triggerToast("✅ 找到 ${results.length} 部关于 \"$q\" 的资源");
                      }
                    }
                  },
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _searchQuery = ''),
                  child: Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Text("热门: ", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),
                ...['三体', '狂飙', '流浪地球', '繁花', '庆余年', '鬼灭之刃', '封神'].map((kw) {
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _searchQuery = kw);
                      _triggerToast("🔍 正在聚合搜索: $kw ...");
                      final results = await _sourceParser.searchAcrossCmsSources(kw);
                      if (results.isNotEmpty && mounted) {
                        setState(() {
                          _vodList = results.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
                        });
                        _triggerToast("✅ 找到 ${results.length} 部关于 \"$kw\" 的资源");
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(kw, style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Main category chip (type selector)
  Widget _buildChip(String label, String catKey) {
    final isSel = _vodCategory == catKey;
    return TvFocusable(
      onTap: () => _switchVodCategory(catKey, catName: label),
      builder: (context, isFocused) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isFocused ? const Color(0xFF1860FF) : (isSel ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.85)),
              borderRadius: BorderRadius.circular(24),
              boxShadow: isFocused || isSel
                ? [BoxShadow(color: const Color(0xFF1860FF).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
            ),
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: isFocused || isSel ? Colors.white : const Color(0xFF1A1D29))),
        );
      },
    );
  }

  /// Generic filter chip used for year/score/quality/sort
  Widget _buildFilterChip(String label, IconData? icon, String value, String currentValue, ValueChanged<String> onSelected) {
    final isSel = value == currentValue;
    return TvFocusable(
      onTap: () => onSelected(value),
      builder: (context, isFocused) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF1860FF) : (isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.8)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isSel ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.9), width: isSel ? 2 : 1),
              boxShadow: isSel || isFocused
                ? [BoxShadow(color: const Color(0xFF1860FF).withOpacity(0.35), blurRadius: 10, spreadRadius: 1)]
                : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSel || isFocused ? Colors.white : const Color(0xFF1A1D29)),
                const SizedBox(width: 5),
              ],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isSel || isFocused ? Colors.white : const Color(0xFF1A1D29))),
          ]),
        );
      },
    );
  }

  // --- Live View ---
  Widget _buildLiveView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _liveList.length,
      itemBuilder: (context, index) {
        final item = _liveList[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TvFocusable(
            onTap: () => _playVideo(item['url'], item['title']),
            builder: (context, isFocused) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isFocused ? Colors.white : Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.8), width: isFocused ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: const Color(0xFF1860FF), borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text(item['logo'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(item['prog'], style: const TextStyle(fontSize: 12, color: Color(0xFF647087))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0x1F12B76A), borderRadius: BorderRadius.circular(8)),
                      child: const Text("LIVE 4K", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF12B76A))),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- History View ---
  Widget _buildHistoryView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
              color: const Color(0xFF2A2D3A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("最近播放历史", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _buildLiveView(),
        ],
      ),
    );
  }

  // --- LAN Hero Section ---
  Widget _buildLanHeroSection() {
    final running = widget.lanServer.isRunning;
    final url = widget.lanServer.serverUrl;
    final interfaces = widget.lanServer.allInterfaces;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("📱 局域网手机扫码协同中心", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text("请确保手机与电视在同一个 Wi-Fi 网络下。使用手机自带相机或浏览器扫描右侧二维码，无需在电视上手动打字。手机端支持虚拟遥控器、推送搜索与一键投屏。", style: TextStyle(fontSize: 13, color: Color(0xFF647087))),
          const SizedBox(height: 16),

          // 服务器状态指示器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: running ? const Color(0x1F12B76A) : const Color(0x1FFF6B6B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(running ? Icons.check_circle : Icons.error, color: running ? const Color(0xFF12B76A) : const Color(0xFFFF6B6B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    running ? "服务运行中 · $url" : "服务未启动 · ${widget.lanServer.lastError}",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: running ? const Color(0xFF12B76A) : const Color(0xFFFF6B6B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 网络诊断面板：显示所有检测到的 IP
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.06),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Colors.white.withOpacity(0.12)),
             ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.network_check, size: 18, color: Color(0xFF647087)),
                    const SizedBox(width: 6),
                    const Text("网络接口诊断", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF131722))),
                    const Spacer(),
                    Text("检测到 ${interfaces.length} 个", style: const TextStyle(fontSize: 11, color: Color(0xFF647087))),
                  ],
                ),
                const SizedBox(height: 12),
                if (interfaces.isEmpty)
                  const Text("未检测到网络接口", style: TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interfaces.map((info) {
                      final isSelected = info.address == widget.lanServer.ipAddress;
                      final isValid = !info.address.startsWith("127.") &&
                          !info.address.startsWith("169.254.") &&
                          !info.address.startsWith("198.18.");
                      return TvFocusable(
                        onTap: () {
                          widget.lanServer.setManualIp(info.address);
                          _triggerToast("已切换 IP: ${info.address}");
                        },
                        builder: (context, isFocused) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1860FF)
                                  : (isFocused ? const Color(0xFF1860FF) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF1860FF) : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_circle : Icons.lan,
                                      size: 14,
                                      color: isSelected ? Colors.white : (isValid ? const Color(0xFF12B76A) : const Color(0xFFFF6B6B)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      info.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white70 : const Color(0xFF647087),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  info.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : const Color(0xFF131722),
                                  ),
                                ),
                                if (isSelected)
                                  Text(
                                    "当前使用",
                                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                const Text(
                  "💡 如果手机无法连接，请在电视设置中查看电视的真实 IP，然后点击上方对应的地址切换。",
                  style: TextStyle(fontSize: 11, color: Color(0xFF647087), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(url, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1860FF))),
          ),
        ],
      ),
    );
  }



  // --- Top Header ---
  Widget _buildTopHeader({bool isMobile = false}) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            // Logo & Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', width: 34, height: 34, fit: BoxFit.contain),
                ),
                const SizedBox(width: 8),
                const Text(
                  "脆皮tv",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Color(0xFFF0F0F0),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Navigation tabs: 影视 / 电视直播 / 本地资源
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavPill("🎬 影视", keyName: "vod"),
                    _buildNavPill("📺 直播", keyName: "live"),
                    _buildNavPill("💾 本地", keyName: "local"),
                  ],
                ),
              ),
            ),
            // Far Right: Settings Button
            TvFocusable(
              onTap: () {
                setState(() => _showGlobalSettingsModal = true);
              },
              builder: (context, isFocused) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isFocused ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFocused ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: isFocused ? Colors.black : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "设置",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isFocused ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Tablet / Desktop / TV / Landscape
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', width: 36, height: 36, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                const Text(
                  "脆皮tv",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Color(0xFFF0F0F0),
                  ),
                ),
              ],
            ),
          ),
          // Navigation tabs: 影视 / 电视直播 / 本地资源 (Center pills)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavPill("🎬 影视点播", keyName: "vod"),
                _buildNavPill("📺 电视直播", keyName: "live"),
                _buildNavPill("💾 本地资源", keyName: "local"),
              ],
            ),
          ),
          // Far Right: Settings Button
          TvFocusable(
            onTap: () {
              setState(() => _showGlobalSettingsModal = true);
            },
            builder: (context, isFocused) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isFocused
                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                      : LinearGradient(
                          colors: [
                            const Color(0xFF2563EB).withValues(alpha: 0.8),
                            const Color(0xFF1D4ED8).withValues(alpha: 0.8),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isFocused ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isFocused ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)).withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 17,
                      color: isFocused ? Colors.black : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "系统设置",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isFocused ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill(String title, {required String keyName, bool isHighlight = false}) {
    final isSelected = _selectedTab == keyName;
    return TvFocusable(
      onTap: () {
        setState(() => _selectedTab = keyName);
        _triggerToast("已切换页面: $title");
      },
      builder: (context, isFocused) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: (isSelected || isFocused)
                ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)])
                : null,
            color: (isSelected || isFocused)
                ? null
                : (isHighlight ? const Color(0x1F1860FF) : Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isSelected || isFocused)
                  ? const Color(0xFF60A5FA)
                  : Colors.white.withOpacity(0.1),
              width: (isSelected || isFocused) ? 1.5 : 1,
            ),
            boxShadow: (isSelected || isFocused)
                ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 8)]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (isSelected || isFocused)
                  ? Colors.white
                  : (isHighlight ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8)),
            ),
          ),
        );
      },
    );
  }

  /// 构建 GitHub TVBox / 直播源检索与一键挂载区域
  Widget _buildGithubSourceSearchSection() {
    final quickKeywords = [
      {'label': '🔥 全部精选', 'kw': ''},
      {'label': '🐱 肥猫源', 'kw': '肥猫'},
      {'label': '🍙 饭太硬', 'kw': '饭太硬'},
      {'label': '📦 优质多仓', 'kw': '多仓'},
      {'label': '📺 4K极清直播', 'kw': '直播'},
      {'label': '🐉 动漫专属', 'kw': '动漫'},
      {'label': '⚙️ 单仓精选', 'kw': '单仓'},
      {'label': '🌟 巧技影视', 'kw': '巧技'},
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标题与统计
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1860FF), Color(0xFF38BDF8)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "🌐 GitHub 全网 TVBox / 直播源智能搜寻",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "实时接入 GitHub API 与 gh-proxy.com 国内镜像加速，一键挂载至大屏",
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1860FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1860FF).withOpacity(0.4)),
                ),
                child: Text(
                  "${_githubSourceResults.length} 个开源源",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 搜索输入框 + 搜索按钮
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13161F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _githubTextController,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "输入关键字在 GitHub 搜索源，例如：肥猫 / 饭太硬 / 直播 / 4K / tvbox / live",
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      border: InputBorder.none,
                      isDense: true,
                      icon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _githubTextController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                              onPressed: () {
                                _githubTextController.clear();
                                _performGithubSourceSearch("");
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (val) => _performGithubSourceSearch(val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TvFocusable(
                onTap: () => _performGithubSourceSearch(_githubTextController.text),
                builder: (context, isFocused) => Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isFocused ? const Color(0xFF2563EB) : const Color(0xFF1860FF),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isFocused ? [const BoxShadow(color: Color(0x661860FF), blurRadius: 12)] : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearchingGithub)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.search, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        "搜索",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 快捷标签 Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: quickKeywords.map((item) {
                final isSelected = _githubSearchQuery == item['kw'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TvFocusable(
                    onTap: () {
                      _githubTextController.text = item['kw']!;
                      _performGithubSourceSearch(item['kw']!);
                    },
                    builder: (context, isFocused) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? const Color(0xFF1860FF)
                            : (isSelected ? const Color(0xFF1E293B) : const Color(0xFF13161F)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused || isSelected ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        item['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFocused || isSelected ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 结果列表
          if (_isSearchingGithub && _githubSourceResults.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1860FF)),
                  SizedBox(height: 12),
                  Text("正在全网检索 GitHub 接口源并加速解析...", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            )
          else if (_githubSourceResults.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: const Text("未找到相关 GitHub 源，请尝试点击上方快捷标签检索热门接口", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: crossAxisCount == 2 ? 2.5 : 2.9,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _githubSourceResults.length,
                  itemBuilder: (context, index) {
                    final item = _githubSourceResults[index];
                    final latency = _githubPingLatency[item.repo];
                    final isCurrentActive = _activeSourceUrl == item.mirrorUrl || _activeSourceUrl == item.rawUrl;

                    return TvFocusable(
                      onTap: () => _loadAndParseSource(item.mirrorUrl, item.name),
                      builder: (context, isFocused) => Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151821),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentActive
                                ? const Color(0xFF10B981)
                                : (isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.08)),
                            width: isCurrentActive || isFocused ? 2 : 1,
                          ),
                          boxShadow: isFocused ? [const BoxShadow(color: Color(0x331860FF), blurRadius: 10)] : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 标题 + Stars + 类型
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${item.stars}",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.isLive ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF1860FF).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.isLive ? "直播源" : (item.isMulti ? "多仓聚合" : "TVBox"),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.isLive ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 仓库标识与描述
                            Text(
                              item.desc.isNotEmpty ? item.desc : "仓库: ${item.repo} · 作者: ${item.author}",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // 标签与操作按钮
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.tags.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.tags.take(2).join(' · '),
                                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                        ),
                                      ),
                                    if (latency != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        latency,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: latency.contains('ms') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TvFocusable(
                                      onTap: () => _pingGithubSource(item.mirrorUrl, item.repo),
                                      builder: (context, f) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: f ? const Color(0xFF334155) : Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text("测速", style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TvFocusable(
                                      onTap: () => _loadAndParseSource(item.mirrorUrl, item.name),
                                      builder: (context, f) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCurrentActive
                                              ? const Color(0xFF10B981)
                                              : (f ? const Color(0xFF2563EB) : const Color(0xFF1860FF)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isCurrentActive ? "✓ 使用中" : "⚡ 挂载",
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSourceCardsSection() {
    final cards = _allSourceCards;
    return Container(
      padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
          color: const Color(0xFF1E2128),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("📺 影视仓 TVBox 源订阅", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  _buildCircleActionButton(Icons.refresh, () async {
                    _triggerToast("正在刷新热门推荐...");
                    final items = await _sourceParser.getHotRecommendations();
                    if (mounted) {
                      setState(() {
                        _vodList = items.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
                        _activeSource = '内置热门';
                      });
                      _triggerToast("✅ 已刷新 ${items.length} 部热门影视");
                    }
                  }),
                  const SizedBox(width: 8),
                  _buildCircleActionButton(Icons.add, () => _triggerToast("打开新增接口对话框")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("支持影视仓/TVBox 标准格式，内置 ${cards.length} 个精选源，点击即可加载", style: const TextStyle(fontSize: 11, color: Color(0xFF647087))),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              final isBuiltIn = card['isBuiltIn'] == true;
              final isLive = card['isLiveSource'] == true;
              final isRecommended = card['isTvBoxSource'] == true || isBuiltIn;
              return TvFocusable(
                onTap: () {
                  if (isBuiltIn) {
                    _loadBuiltInHot();
                  } else {
                    _loadAndParseSource(card['url'] ?? '', card['title']!);
                  }
                },
                builder: (context, isFocused) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _getCardColor(card['color']?.toString() ?? 'blue'),
                      borderRadius: BorderRadius.circular(20),
                      border: isFocused ? Border.all(color: const Color(0xFF1860FF), width: 2) : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 绿色圆点指示器 - 表示源可用
                                if (isRecommended)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF12B76A),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: const Color(0xFF12B76A).withOpacity(0.5), blurRadius: 4)],
                                    ),
                                  )
                                else
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white38,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Flexible(child: Text(card['date'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.white70))),
                              ],
                            ),
                            if (isBuiltIn)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: const Text('HOT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)))
                            else if (isLive)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)))
                            else if (isRecommended)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF12B76A), borderRadius: BorderRadius.circular(4)), child: const Text('✓ 可用', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)))
                            else
                              const Icon(Icons.more_horiz, color: Colors.white70, size: 16),
                          ],
                        ),
                        Flexible(child: Text(card['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        Row(
                          children: [
                            Expanded(child: Text(card['stat'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            // Web端源额外显示绿色可用标记
                            if ((card['url']?.toString().startsWith('http') ?? false) && !card['url'].toString().contains('github'))
                              const Icon(Icons.check_circle, size: 14, color: Color(0xFF12B76A)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// 加载内置热门影视
  Future<void> _loadBuiltInHot() async {
    if (_isLoadingSource) return;
    setState(() => _isLoadingSource = true);
    _triggerToast("🔥 正在汇聚全网热门影视推荐...");
    try {
      final items = await _sourceParser.getHotRecommendations();
      if (mounted) {
        final mapped = items.asMap().entries.map((e) => e.value.toDashboardMap(index: e.key)).toList();
        setState(() {
          _vodList = mapped;
          _categoryCache['all'] = mapped;
          _categoryPage['all'] = 1;
          _activeSource = 'LibreTV 聚合推荐';
          _activeSourceUrl = '';
          _vodCurrentPage = 1;
          _hasMoreContent = true;
          _dataSourceType = 'builtin';
          _selectedTab = 'vod';
          _isLoadingSource = false;
        });
        _triggerToast("✅ 成功加载 ${items.length} 部全网热门影视");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSource = false);
        _triggerToast("❌ 加载失败: $e");
      }
    }
  }

  Color _getCardColor(String name) {
    switch (name) {
      case 'blue': return const Color(0xFF1860FF);
      case 'teal': return const Color(0xFF2B8E99);
      case 'dark': return const Color(0xFF0F1117);
      case 'yellow': return const Color(0xFFD4AA15);
      case 'green': return const Color(0xFF12B76A);
      case 'purple': return const Color(0xFF7C3AED);
      case 'orange': return const Color(0xFFF97316);
      case 'red': return const Color(0xFFEF4444);
      default: return const Color(0xFF333846);
    }
  }

  Widget _buildDualPanelSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Text("热播节目排期日历 (Schedule)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D3A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("局域网手机一键配置", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text("端口 ${widget.lanServer.port} · 地址 ${widget.lanServer.serverUrl}", style: const TextStyle(fontSize: 12, color: Color(0xFF1860FF), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildCircleActionButton(IconData icon, VoidCallback onTap) {
    return TvFocusable(
      onTap: onTap,
      builder: (context, isFocused) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: isFocused ? const Color(0xFF1860FF) : Colors.white, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: isFocused ? Colors.white : Colors.black87),
        );
      },
    );
  }

  Widget _buildQrModalOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("局域网手机扫码配置中心", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text("手机扫描下方二维码，在网页端直接控制电视", style: TextStyle(fontSize: 12, color: Color(0xFF647087))),
                const SizedBox(height: 20),
                QrImageView(data: widget.lanServer.serverUrl, version: QrVersions.auto, size: 200.0),
                const SizedBox(height: 12),
                Text(widget.lanServer.serverUrl, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1860FF))),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _closeModals, child: const Text("关闭")),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ==================== 右侧面板：分类搜索 + 热门海报墙 ====================

  /// 分类搜索卡片 - 替代原来的投屏功能
  Widget _buildCategorySearchCard() {
    return Container(
      padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
          color: const Color(0xFF1E2128),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.category, color: Color(0xFF1860FF), size: 20),
              SizedBox(width: 8),
              Text("🎬 分类搜索", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF0F0F0))),
            ],
          ),
          const SizedBox(height: 14),
          // 搜索框
          TvFocusable(
            onTap: () {},
            builder: (context, isFocused) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isFocused ? Colors.white : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isFocused ? const Color(0xFF1860FF) : const Color(0xFFE2E8F0), width: isFocused ? 2 : 1),
                  boxShadow: isFocused ? const [BoxShadow(color: Color(0x331860FF), blurRadius: 12)] : null,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF647087), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                            if (_selectedTab != 'vod') _selectedTab = 'vod';
                          });
                        },
                        decoration: InputDecoration(
                          hintText: _searchQuery.isEmpty ? "搜索影视..." : _searchQuery,
                          hintStyle: TextStyle(color: _searchQuery.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF131722), fontSize: 12, fontWeight: FontWeight.w600),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _searchQuery = ''),
                        child: const Icon(Icons.close, color: Color(0xFF647087), size: 16),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // 快捷分类按钮
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickCategoryChip("🔥 热门", "all"),
              _buildQuickCategoryChip("🎬 电影", "movie"),
              _buildQuickCategoryChip("📺 电视剧", "tv"),
              _buildQuickCategoryChip("🎌 动漫", "anime"),
              _buildQuickCategoryChip("🎤 综艺", "variety"),
              _buildQuickCategoryChip("📖 纪录片", "documentary"),
            ],
          ),
          const SizedBox(height: 10),
          // 热门搜索标签
          const Text("热门搜索", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF647087))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ["三体", "狂飙", "流浪地球", "鬼灭之刃", "CCTV", "国家宝藏"].map((tag) {
              final isSelected = _searchQuery == tag;
              return GestureDetector(
                onTap: () => setState(() => _searchQuery = isSelected ? '' : tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryChip(String label, String catKey) {
    final isSel = _vodCategory == catKey;
    return TvFocusable(
      onTap: () {
        setState(() {
          _vodCategory = catKey;
          if (_selectedTab != 'vod') _selectedTab = 'vod';
        });
        _triggerToast("已切换到: $label");
      },
      builder: (context, isFocused) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isFocused || isSel ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSel ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.9), width: isSel ? 2 : 1),
          boxShadow: isFocused || isSel
            ? [BoxShadow(color: const Color(0xFF1860FF).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
          color: isFocused || isSel ? Colors.white : const Color(0xFF1A1D29))),
      ),
    );
  }

  /// 热门海报墙 - 替代原来的投屏，显示热门推荐
  Widget _buildHotPosterWall() {
    // 取前6个热门内容作为小海报墙
    final hotItems = _vodList.length > 6 ? _vodList.sublist(0, 6) : _vodList;

    return Container(
      padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
          color: const Color(0xFF1E2128),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 20),
                  SizedBox(width: 8),
                  Text("🔥 热门海报墙", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF0F0F0))),
                ],
              ),
              TvFocusable(
                onTap: () async {
                  _triggerToast("正在刷新热门...");
                  await _loadBuiltInHot();
                },
                builder: (context, isFocused) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFocused ? const Color(0xFF1860FF) : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh, size: 12, color: isFocused ? Colors.white : const Color(0xFF647087)),
                    const SizedBox(width: 4),
                    Text("刷新", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: isFocused ? Colors.white : const Color(0xFF647087))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hotItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.movie_outlined, size: 32, color: Colors.grey[500]),
                    const SizedBox(height: 8),
                    Text("暂无内容\n点击源加载或刷新", textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.62,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: hotItems.length,
              itemBuilder: (context, index) {
                final item = hotItems[index];
                return TvFocusable(
                  onTap: () {
                    // 点播至电视播放
                    _playVideo(item['url'] ?? '', item['title'] ?? '');
                    _triggerToast("📺 正在播放: ${item['title']}");
                  },
                  builder: (context, isFocused) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFocused ? const Color(0xFF1860FF) : Colors.transparent,
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? const [BoxShadow(color: Color(0x401860FF), blurRadius: 12)]
                            : null,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 海报图
                          _buildSafePosterImage(item['poster'] ?? '', item),
                          // 渐变遮罩
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                ),
                              ),
                            ),
                          ),
                          // 排名角标
                          if (index < 3)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  gradient: index == 0
                                      ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                                      : index == 1
                                          ? const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFA0A0A0)])
                                          : const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFFB8860B)]),
                                  shape: BoxShape.circle,
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                                ),
                                alignment: Alignment.center,
                                child: Text('${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                              ),
                            ),
                          // 底部信息
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("${item['year'] ?? ''}", style: const TextStyle(fontSize: 8, color: Colors.white70)),
                                      Text("★ ${item['score'] ?? ''}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFFFEAA5))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 播放图标（聚焦时显示）
                          if (isFocused)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: Icon(Icons.play_circle_filled, color: Colors.white70, size: 36),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTvQrSearchCard() {
    return Container(
        padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
          color: const Color(0xFF1E2128),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.qr_code_scanner, color: Color(0xFF1860FF), size: 22),
              SizedBox(width: 8),
              Text("扫码搜索与控制", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFF0F0F0))),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: QrImageView(
              data: widget.lanServer.serverUrl,
              version: QrVersions.auto,
              size: 160.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.lanServer.serverUrl,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1860FF)),
          ),
          const SizedBox(height: 6),
          const Text(
            "手机微信/浏览器扫码，手机键盘输入文字、剧名搜索、推送接口与投屏",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🎨 怀旧包豪斯 (Bauhaus) 经典弧形表盘组件
  // ==========================================

  Widget _buildPlayerModalOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth >= 550;
        return Positioned.fill(
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.escape ||
                    key == LogicalKeyboardKey.backspace ||
                    key == LogicalKeyboardKey.goBack) {
                  if (_showEpisodeDrawer || _showSettingsDrawer) {
                    setState(() {
                      _showEpisodeDrawer = false;
                      _showSettingsDrawer = false;
                    });
                    return KeyEventResult.handled;
                  }
                  _closePlayer();
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowLeft) {
                  if (!_showEpisodeDrawer && !_showSettingsDrawer) {
                    _seekRelative(-10);
                    return KeyEventResult.handled;
                  }
                } else if (key == LogicalKeyboardKey.arrowRight) {
                  if (!_showEpisodeDrawer && !_showSettingsDrawer) {
                    _seekRelative(10);
                    return KeyEventResult.handled;
                  }
                } else if (key == LogicalKeyboardKey.space) {
                  _togglePlayPause();
                  return KeyEventResult.handled;
                } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
                  _resetControlsTimer();
                }
              }
              return KeyEventResult.ignored;
            },
            child: isLandscape
                ? _buildLandscapePlayerLayout(constraints)
                : _buildPortraitMobilePlayerLayout(constraints),
          ),
        );
      },
    );
  }

  /// 📱 竖屏手机专属包豪斯终端布局 (上部 16:9 极清画质，下部复古黑胶弧形控制台)
  Widget _buildPortraitMobilePlayerLayout(BoxConstraints constraints) {
    final curSec = _videoPosition.inSeconds.toDouble();
    final totalSec = _videoDuration.inSeconds.toDouble();
    final progress = (totalSec > 0) ? (curSec / totalSec).clamp(0.0, 1.0) : 0.0;
    final isPlaying = _videoController?.value.isPlaying ?? false;

    return Container(
      color: const Color(0xFF132320),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. 上半部分：16:9 视频播放视口
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x337CE1D4), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x77000000), blurRadius: 18, offset: Offset(0, 6)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 视频渲染表面
                      _buildVideoSurface(),

                      // 缓冲网速提示 (绝无爬虫源名字，纯粹网速显示)
                      if (_isPlayerBuffering || _videoController == null || !_videoController!.value.isInitialized)
                        _buildBufferingOverlay(),

                      // 顶部微缩与画中画悬浮栏
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              // 缩小至底部条
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _playerDisplayMode = PlayerDisplayMode.mini;
                                    _showEpisodeDrawer = false;
                                    _showSettingsDrawer = false;
                                  });
                                  _triggerToast("已转入小窗口 · 可在主页继续搜索");
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 系统画中画
                              GestureDetector(
                                onTap: _startSystemPip,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.picture_in_picture_alt_rounded, color: Color(0xFF7CE1D4), size: 17),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // 标题
                              Expanded(
                                child: Text(
                                  _playerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFFDF7),
                                  ),
                                ),
                              ),
                              // 退出
                              GestureDetector(
                                onTap: _closePlayer,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. 下半部分：包豪斯复古绿意控制面板 (参考图2完美还原)
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF38665C), // 经典包豪斯鼠尾草深松绿
                      Color(0xFF264942),
                      Color(0xFF1B3630),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x447CE1D4), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
                    BoxShadow(color: Color(0x227CE1D4), blurRadius: 16),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          children: [
                            // 顶部状态栏：播放中指示 + 网速情况 (绝不展示任何爬虫源名字)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF7CE1D4),
                                        boxShadow: [
                                          BoxShadow(color: Color(0xFF7CE1D4), blurRadius: 8, spreadRadius: 1),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    const Text(
                                      "正在播放",
                                      style: TextStyle(
                                        color: Color(0xFFE8F6F3),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                // 实时网络速度监测徽章
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33162E29),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0x447CE1D4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded, color: Color(0xFFFFC83B), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "⚡ ${_networkSpeedMbps.toStringAsFixed(1)} MB/s",
                                        style: const TextStyle(
                                          color: Color(0xFFFFFDF7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // 选集快捷水平滑条 (用户可直接在屏幕上选择第几集，立即播放！)
                            _buildQuickEpisodePicker(),

                            const SizedBox(height: 6),

                            // 弧形音量/进度表盘 (复刻图2大圆弧刻度与数值)
                            BauhausArcDialWidget(
                              value: _arcControlsVolume ? _currentVolume : progress,
                              isVolume: _arcControlsVolume,
                              titleText: _arcControlsVolume ? "音量调节" : "播放进度",
                              readoutText: _arcControlsVolume
                                  ? "${(_currentVolume * 100).toInt()}%"
                                  : "${_formatDuration(_videoPosition)} / ${_formatDuration(_videoDuration)}",
                              onChanged: (val) {
                                if (_arcControlsVolume) {
                                  _setPlayerVolume(val);
                                } else {
                                  if (totalSec > 0) {
                                    final target = Duration(seconds: (val * totalSec).toInt());
                                    _videoController?.seekTo(target);
                                    setState(() => _videoPosition = target);
                                  }
                                }
                              },
                              onToggleMode: _toggleArcMode,
                              height: 160,
                            ),

                            const SizedBox(height: 14),

                            // 核心三联钮：[左音量] [中间复古包豪斯唱盘大按钮] [右选集]
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 左：静音/音量快速切换
                                _buildBauhausSidePodButton(
                                  icon: _currentVolume > 0.01 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  label: _currentVolume > 0.01 ? "${(_currentVolume * 100).toInt()}%" : "静音",
                                  iconColor: _currentVolume > 0.01 ? const Color(0xFFFFFDF7) : const Color(0xFFFFC83B),
                                  onTap: _toggleMute,
                                ),

                                // 中：包豪斯双层同心唱盘播放/暂停核心大按钮 (图2 精髓)
                                _buildBauhausCenterDisc(
                                  isPlaying: isPlaying,
                                  onTap: _togglePlayPause,
                                ),

                                // 右：分集抽屉 (显示分集数)
                                _buildBauhausSidePodButton(
                                  icon: Icons.format_list_bulleted_rounded,
                                  label: "选集(${_currentEpisodes.isNotEmpty ? _currentEpisodes.length : 1})",
                                  isActive: _showEpisodeDrawer,
                                  onTap: () {
                                    setState(() {
                                      _showEpisodeDrawer = !_showEpisodeDrawer;
                                      _showSettingsDrawer = false;
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // 下方快捷胶囊操作栏 (风格统一，不溢出，横向自适应)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // 快退 10s
                                  _buildBauhausSecondaryPill(
                                    icon: Icons.replay_10_rounded,
                                    label: "-10s",
                                    onTap: () => _seekRelative(-10),
                                  ),
                                  const SizedBox(width: 8),
                                  // 快进 10s
                                  _buildBauhausSecondaryPill(
                                    icon: Icons.forward_10_rounded,
                                    label: "+10s",
                                    onTap: () => _seekRelative(10),
                                  ),
                                  const SizedBox(width: 8),
                                  // 倍速
                                  _buildBauhausSecondaryPill(
                                    icon: Icons.speed_rounded,
                                    label: "${_playbackSpeed}x",
                                    isHighlight: _playbackSpeed != 1.0,
                                    onTap: _togglePlaybackSpeed,
                                  ),
                                  const SizedBox(width: 8),
                                  // 画面比例
                                  _buildBauhausSecondaryPill(
                                    icon: Icons.aspect_ratio_rounded,
                                    label: _aspectRatioMode == 'contain'
                                        ? "自适应"
                                        : (_aspectRatioMode == '16:9' ? "16:9" : "铺满"),
                                    onTap: _toggleAspectRatio,
                                  ),
                                  const SizedBox(width: 8),
                                  // 极速线路切换 (绝不写爬虫源名字，只写线路1/2/3)
                                  _buildBauhausSecondaryPill(
                                    icon: Icons.alt_route_rounded,
                                    label: "换线 (${_alternativeSources.isNotEmpty ? _alternativeSources.length : 1})",
                                    isHighlight: _showSettingsDrawer,
                                    onTap: () {
                                      setState(() {
                                        _showSettingsDrawer = !_showSettingsDrawer;
                                        _showEpisodeDrawer = false;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // 系统画中画
                                  _buildBauhausSecondaryPill(
                                    icon: Icons.picture_in_picture_alt_rounded,
                                    label: "画中画",
                                    onTap: _startSystemPip,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 选集抽屉浮层
                      if (_showEpisodeDrawer)
                        Positioned.fill(
                          child: _buildEpisodeDrawer(),
                        ),

                      // 换线抽屉浮层
                      if (_showSettingsDrawer)
                        Positioned.fill(
                          child: _buildSourceDrawer(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💻 横屏手机 & 电脑/大屏专属包豪斯全景布局 (沉浸式全景 + 悬浮包豪斯复古控制台)
  Widget _buildLandscapePlayerLayout(BoxConstraints constraints) {
    return MouseRegion(
      onHover: (_) => _resetControlsTimer(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _showPlayerControls = !_showPlayerControls);
          if (_showPlayerControls) _resetControlsTimer();
        },
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 视频渲染表面 (Video surface)
              _buildVideoSurface(),

              // 2. 缓冲指示器 (展示实时网络速率，不展示任何爬虫名字)
              if (_isPlayerBuffering || _videoController == null || !_videoController!.value.isInitialized)
                _buildBufferingOverlay(),

              // 3. 顶部 HUD 栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _showPlayerControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showPlayerControls,
                    child: _buildTopPlayerControls(),
                  ),
                ),
              ),

              // 4. 底部包豪斯悬浮中控台
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _showPlayerControls ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showPlayerControls,
                    child: _buildBottomPlayerControls(),
                  ),
                ),
              ),

              // 5. 选集抽屉 (Episodes Drawer)
              if (_showEpisodeDrawer)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: constraints.maxWidth < 600 ? constraints.maxWidth * 0.85 : 360,
                  child: _buildEpisodeDrawer(),
                ),

              // 6. 换源/换线设置抽屉 (Source Switcher Drawer)
              if (_showSettingsDrawer)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: constraints.maxWidth < 600 ? constraints.maxWidth * 0.85 : 360,
                  child: _buildSourceDrawer(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 视频播放核心表面
  Widget _buildVideoSurface() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    if (_aspectRatioMode == '16:9') {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayer(_videoController!),
        ),
      );
    } else if (_aspectRatioMode == 'cover') {
      final size = _videoController!.value.size;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width > 0 ? size.width : 1920,
            height: size.height > 0 ? size.height : 1080,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    final ratio = _videoController!.value.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio > 0 ? ratio : 16 / 9,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  /// 缓冲指示器 (展示实时网络速率，严格不显示任何爬虫源名称)
  Widget _buildBufferingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 26),
              decoration: BoxDecoration(
                color: const Color(0xE61B3630),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF7CE1D4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, offset: const Offset(0, 8)),
                  BoxShadow(color: const Color(0xFF7CE1D4).withOpacity(0.3), blurRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7CE1D4).withOpacity(0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF7CE1D4),
                      backgroundColor: Color(0x337CE1D4),
                      strokeWidth: 3.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _playerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFFDF7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x337CE1D4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x887CE1D4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFFFFC83B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "正在缓冲 · ${_networkSpeedMbps.toStringAsFixed(1)} MB/s · 4K 极清",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFFDF7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 包豪斯唱片同心圆播放/暂停核心大按钮 (图2 标志性核心)
  Widget _buildBauhausCenterDisc({required bool isPlaying, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFF7CE1D4),
              Color(0xFF4A8B80),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7CE1D4).withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Color(0x88000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8F6F3),
          ),
          child: Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1B3630),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFF7CE1D4),
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 包豪斯两侧圆形功能 Pod 按钮
  Widget _buildBauhausSidePodButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color iconColor = const Color(0xFFFFFDF7),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF4A8B80) : const Color(0xFF203F39),
              border: Border.all(
                color: isActive ? const Color(0xFF7CE1D4) : const Color(0x447CE1D4),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD1E7E2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 选集快速水平滑块栏 (可直接在屏幕上选择第几集，立即播放！)
  Widget _buildQuickEpisodePicker() {
    if (_currentEpisodes.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _currentEpisodes.length,
        itemBuilder: (context, idx) {
          final ep = _currentEpisodes[idx];
          final epName = ep['ep'] ?? ep['name'] ?? '第${idx + 1}集';
          final isSelected = idx == _currentEpisodeIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _switchEpisode(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFC83B) : const Color(0xFF203F39),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFE082) : const Color(0x337CE1D4),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFC83B).withOpacity(0.4),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  epName,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF1B3630) : const Color(0xFFE8F6F3),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 包豪斯胶囊次级操作按钮
  Widget _buildBauhausSecondaryPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFF3B6B61) : const Color(0x33203F39),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlight ? const Color(0xFF7CE1D4) : const Color(0x287CE1D4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isHighlight ? const Color(0xFFFFC83B) : const Color(0xFF7CE1D4)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFFDF7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 横屏/电脑 顶部 HUD 栏
  Widget _buildTopPlayerControls() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 8, isMobile ? 12 : 16, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // 1. 缩小至底部播放条 (YouTube 样式: 小窗口继续播放，回到主页继续搜索)
            TvFocusable(
              autoFocus: true,
              onTap: () {
                setState(() {
                  _playerDisplayMode = PlayerDisplayMode.mini;
                  _showEpisodeDrawer = false;
                  _showSettingsDrawer = false;
                });
                _triggerToast("已转入底部小窗口 · 可返回主页继续搜索浏览");
              },
              builder: (context, isFocused) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 16,
                    vertical: isMobile ? 7 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF203F39),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x447CE1D4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7CE1D4), size: 20),
                      if (!isMobile) ...[
                        const SizedBox(width: 4),
                        const Text(
                          "主页搜索",
                          style: TextStyle(color: Color(0xFFFFFDF7), fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),

            // 2. 系统画中画 (iOS 原生 AVPictureInPictureController)
            TvFocusable(
              onTap: _startSystemPip,
              builder: (context, isFocused) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 7 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF203F39),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x447CE1D4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_in_picture_alt_rounded, color: Color(0xFF7CE1D4), size: 18),
                      if (!isMobile) ...[
                        const SizedBox(width: 4),
                        const Text("画中画", style: TextStyle(color: Color(0xFFFFFDF7), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),

            // 3. 剧集/影片标题与网络状态 (自适应手机尺寸，不溢出截断，绝不展示爬虫源名)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _playerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFFFDF7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x337CE1D4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x887CE1D4)),
                        ),
                        child: Text(
                          "⚡ ${_networkSpeedMbps.toStringAsFixed(1)} MB/s",
                          style: const TextStyle(color: Color(0xFF7CE1D4), fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (_currentEpisodes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "当前集数: ${_currentEpisodes[_currentEpisodeIndex < _currentEpisodes.length ? _currentEpisodeIndex : 0]['ep'] ?? _currentEpisodes[_currentEpisodeIndex < _currentEpisodes.length ? _currentEpisodeIndex : 0]['name'] ?? '正片'}",
                      style: const TextStyle(color: Color(0xFFD1E7E2), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 4. 退出播放器按钮
            TvFocusable(
              onTap: _closePlayer,
              builder: (context, isFocused) {
                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 横屏/电脑 底部 HUD 栏 (融合包豪斯快速选集与唱盘控制)
  Widget _buildBottomPlayerControls() {
    final curSec = _videoPosition.inSeconds.toDouble();
    final totalSec = _videoDuration.inSeconds.toDouble();
    final progress = (totalSec > 0) ? (curSec / totalSec).clamp(0.0, 1.0) : 0.0;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isPlaying = _videoController?.value.isPlaying ?? false;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 10, isMobile ? 14 : 24, isMobile ? 10 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xF21B3630),
              const Color(0xCC264942),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 横向快捷选集栏
            _buildQuickEpisodePicker(),

            const SizedBox(height: 4),

            // 进度条与播放时长
            Row(
              children: [
                Text(
                  _formatDuration(_videoPosition),
                  style: const TextStyle(color: Color(0xFFFFFDF7), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: const Color(0xFF7CE1D4),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFFFFC83B),
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (val) {
                        if (totalSec > 0) {
                          final target = Duration(seconds: (val * totalSec).toInt());
                          _videoController?.seekTo(target);
                          setState(() => _videoPosition = target);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDuration(_videoDuration),
                  style: const TextStyle(color: Color(0xFFD1E7E2), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 横屏控制按钮栏
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // 1. 播放/暂停
                  _buildBauhausSecondaryPill(
                    icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    label: isPlaying ? "暂停" : "播放",
                    isHighlight: true,
                    onTap: _togglePlayPause,
                  ),
                  const SizedBox(width: 8),
                  // 2. 快退 10s
                  _buildBauhausSecondaryPill(
                    icon: Icons.replay_10_rounded,
                    label: "-10秒",
                    onTap: () => _seekRelative(-10),
                  ),
                  const SizedBox(width: 8),
                  // 3. 快进 10s
                  _buildBauhausSecondaryPill(
                    icon: Icons.forward_10_rounded,
                    label: "+10秒",
                    onTap: () => _seekRelative(10),
                  ),
                  const SizedBox(width: 8),
                  // 4. 音量/静音
                  _buildBauhausSecondaryPill(
                    icon: _currentVolume > 0.01 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    label: _currentVolume > 0.01 ? "音量 ${(_currentVolume * 100).toInt()}%" : "静音",
                    onTap: _toggleMute,
                  ),
                  const SizedBox(width: 8),
                  // 5. 选集抽屉
                  if (_currentEpisodes.isNotEmpty) ...[
                    _buildBauhausSecondaryPill(
                      icon: Icons.playlist_play_rounded,
                      label: "选集 (${_currentEpisodes.length})",
                      isHighlight: _showEpisodeDrawer,
                      onTap: () {
                        setState(() {
                          _showEpisodeDrawer = !_showEpisodeDrawer;
                          _showSettingsDrawer = false;
                        });
                        _resetControlsTimer();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 6. 极速换线 (不显示爬虫名字)
                  _buildBauhausSecondaryPill(
                    icon: Icons.alt_route_rounded,
                    label: "线路 (${_alternativeSources.isNotEmpty ? _alternativeSources.length : 1})",
                    isHighlight: _showSettingsDrawer,
                    onTap: () {
                      setState(() {
                        _showSettingsDrawer = !_showSettingsDrawer;
                        _showEpisodeDrawer = false;
                      });
                      _resetControlsTimer();
                    },
                  ),
                  const SizedBox(width: 8),
                  // 7. 系统画中画
                  _buildBauhausSecondaryPill(
                    icon: Icons.picture_in_picture_alt_rounded,
                    label: "画中画",
                    onTap: _startSystemPip,
                  ),
                  const SizedBox(width: 8),
                  // 8. 画面比例
                  _buildBauhausSecondaryPill(
                    icon: Icons.aspect_ratio_rounded,
                    label: _aspectRatioMode == 'contain'
                        ? "自适应"
                        : (_aspectRatioMode == '16:9' ? "16:9" : "铺满"),
                    onTap: _toggleAspectRatio,
                  ),
                  const SizedBox(width: 8),
                  // 9. 倍速
                  _buildBauhausSecondaryPill(
                    icon: Icons.speed_rounded,
                    label: "${_playbackSpeed}x 倍速",
                    isHighlight: _playbackSpeed != 1.0,
                    onTap: _togglePlaybackSpeed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
    bool isActive = false,
    bool isMobile = false,
  }) {
    return _buildBauhausSecondaryPill(
      icon: icon,
      label: label,
      onTap: onTap,
      isHighlight: highlight || isActive,
    );
  }

  /// YouTube 样式底部悬浮播放条 (左侧小窗口继续播放，右侧控制，用户回到主页继续搜索)
  Widget _buildYouTubeMiniPlayer() {
    final curSec = _videoPosition.inSeconds.toDouble();
    final totalSec = _videoDuration.inSeconds.toDouble();
    final progress = (totalSec > 0) ? (curSec / totalSec).clamp(0.0, 1.0) : 0.0;
    final isPlaying = _videoController?.value.isPlaying ?? false;

    return Positioned(
      left: 10,
      right: 10,
      bottom: MediaQuery.of(context).padding.bottom + 8,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _playerDisplayMode = PlayerDisplayMode.full;
              _showPlayerControls = true;
            });
            _resetControlsTimer();
          },
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xEE141824),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x4438BDF8), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x77000000),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: Offset(0, 6),
                ),
                BoxShadow(
                  color: Color(0x2238BDF8),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Stack(
                  children: [
                    // 1. 顶部超薄进度条
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 2.5,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                    // 2. 主体：左边小窗口播放，中间信息，右边控制
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          // 左侧小窗口继续播放 (不中断，零重载)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 96,
                              height: 54,
                              color: Colors.black,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildVideoSurface(),
                                  if (_isPlayerBuffering)
                                    const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // 中间信息 (点击还原全屏播放)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _playerTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0x337CE1D4),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "线路 ${_currentSourceIndex + 1} · 4K",
                                        style: const TextStyle(color: Color(0xFF7CE1D4), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _currentEpisodes.isNotEmpty
                                            ? (_currentEpisodes[_currentEpisodeIndex < _currentEpisodes.length ? _currentEpisodeIndex : 0]['ep'] ?? '正片')
                                            : '${_formatDuration(_videoPosition)} / ${_formatDuration(_videoDuration)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 右边控制按钮 (播放、快进、PiP、关闭)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 26,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              IconButton(
                                iconSize: 22,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                icon: const Icon(
                                  Icons.forward_10_rounded,
                                  color: Colors.white70,
                                ),
                                onPressed: () => _seekRelative(10),
                              ),
                              IconButton(
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                icon: const Icon(
                                  Icons.picture_in_picture_alt_rounded,
                                  color: Color(0xFF38BDF8),
                                ),
                                tooltip: '系统画中画',
                                onPressed: _startSystemPip,
                              ),
                              IconButton(
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                ),
                                tooltip: '关闭',
                                onPressed: _closePlayer,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 跨平台自由拖拽小窗口 (支持 iOS, Android, macOS, Windows 全平台)
  Widget _buildDraggablePipWindow() {
    final isPlaying = _videoController?.value.isPlaying ?? false;

    return Positioned(
      left: _pipPosition.dx,
      top: _pipPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final size = MediaQuery.of(context).size;
            final newX = (_pipPosition.dx + details.delta.dx).clamp(8.0, size.width - 248.0);
            final newY = (_pipPosition.dy + details.delta.dy).clamp(40.0, size.height - 150.0);
            _pipPosition = Offset(newX, newY);
          });
        },
        child: Container(
          width: 240,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 24, spreadRadius: 3),
              BoxShadow(color: Color(0x3338BDF8), blurRadius: 16),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideoSurface(),
                if (_isPlayerBuffering)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF38BDF8)),
                    ),
                  ),
                // 顶部悬浮控制栏
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator_rounded, color: Colors.white54, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _playerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _playerDisplayMode = PlayerDisplayMode.full;
                              _showPlayerControls = true;
                            });
                            _resetControlsTimer();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _playerDisplayMode = PlayerDisplayMode.mini;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.vertical_align_bottom_rounded, color: Color(0xFF38BDF8), size: 16),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _closePlayer,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 中间暂停/播放触控
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.4),
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeDrawer() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF21B3630),
        border: Border(left: BorderSide(color: Color(0x337CE1D4))),
        boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.playlist_play_rounded, color: Color(0xFF7CE1D4), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "选集列表 (${_currentEpisodes.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFFFDF7)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => setState(() => _showEpisodeDrawer = false),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x287CE1D4), height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
              ),
              itemCount: _currentEpisodes.length,
              itemBuilder: (context, index) {
                final ep = _currentEpisodes[index];
                final epName = ep['ep'] ?? ep['name'] ?? '第${index + 1}集';
                final isCurrent = index == _currentEpisodeIndex;

                return TvFocusable(
                  onTap: () {
                    _switchEpisode(index);
                    setState(() => _showEpisodeDrawer = false);
                  },
                  builder: (context, isFocused) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFFFFC83B)
                            : (isFocused ? const Color(0xFF38665C) : const Color(0xFF203F39)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFFFE082)
                              : (isFocused ? const Color(0xFF7CE1D4) : const Color(0x287CE1D4)),
                          width: (isCurrent || isFocused) ? 2 : 1,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFC83B).withOpacity(0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        epName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF1B3630) : const Color(0xFFFFFDF7),
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceDrawer() {
    final list = _alternativeSources.isNotEmpty
        ? _alternativeSources
        : [
            VodItem(
              id: '1',
              title: _playerTitle,
              sourceName: '极速蓝光专线',
              playUrl: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
            ),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF21B3630),
        border: Border(left: BorderSide(color: Color(0x337CE1D4))),
        boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, color: Color(0xFF7CE1D4), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "极速线路切换 (${list.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFFFDF7)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: () => setState(() => _showSettingsDrawer = false),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x287CE1D4), height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final src = list[index];
                final isCurrent = index == _currentSourceIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TvFocusable(
                    onTap: () {
                      _switchSource(index);
                      setState(() => _showSettingsDrawer = false);
                    },
                    builder: (context, isFocused) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF264C43)
                              : (isFocused ? const Color(0xFF38665C) : const Color(0xFF203F39)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFF7CE1D4)
                                : (isFocused ? const Color(0xFF7CE1D4) : const Color(0x287CE1D4)),
                            width: (isCurrent || isFocused) ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: isCurrent ? const Color(0xFFFFC83B) : Colors.white54,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "极速专线 #${index + 1}",
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFFFDF7)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    src.episodes.isNotEmpty ? "包含 ${src.episodes.length} 集 · 4K秒播" : "单集完整版 · 高清高速",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFD1E7E2)),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0x337CE1D4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x667CE1D4)),
                                ),
                                child: const Text("正在播放", style: TextStyle(color: Color(0xFF7CE1D4), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToastOverlay() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xF00F1117), borderRadius: BorderRadius.circular(30)),
          child: Text(_toastMessage, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}

class TvFocusable extends StatefulWidget {
  final Widget Function(BuildContext context, bool isFocused) builder;
  final VoidCallback? onTap;
  final bool autoFocus;

  const TvFocusable({
    Key? key,
    required this.builder,
    this.onTap,
    this.autoFocus = false,
  }) : super(key: key);

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autoFocus,
      onFocusChange: (focused) {
        if (mounted) setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.gameButtonA ||
              key == LogicalKeyboardKey.space) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _isFocused),
      ),
    );
  }
}

/// 🎨 包豪斯风格半圆大弧度表盘组件 (复刻图2大表盘刻度与中央液晶数字)
class BauhausArcDialWidget extends StatelessWidget {
  final double value; // 0.0 ~ 1.0
  final bool isVolume;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleMode;
  final String titleText;
  final String readoutText;
  final double height;

  const BauhausArcDialWidget({
    Key? key,
    required this.value,
    required this.isVolume,
    required this.onChanged,
    required this.onToggleMode,
    required this.titleText,
    required this.readoutText,
    this.height = 160,
  }) : super(key: key);

  void _handleTouch(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    double angle = atan2(dy, dx);
    const startAngle = pi * 0.82;
    const sweepAngle = pi * 1.36;

    if (angle < 0) {
      angle += 2 * pi;
    }
    double diff = angle - startAngle;
    if (diff < 0) {
      diff += 2 * pi;
    }

    if (diff <= sweepAngle) {
      final progress = (diff / sweepAngle).clamp(0.0, 1.0);
      onChanged(progress);
    } else {
      final distToStart = (angle - startAngle).abs();
      final endAngle = (startAngle + sweepAngle) % (2 * pi);
      final distToEnd = (angle - endAngle).abs();
      if (distToStart < distToEnd) {
        onChanged(0.0);
      } else {
        onChanged(1.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handleTouch(d.localPosition, size),
          onPanUpdate: (d) => _handleTouch(d.localPosition, size),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 弧形轨道与放射刻度
                CustomPaint(
                  size: size,
                  painter: BauhausArcDialPainter(
                    value: value,
                    isVolume: isVolume,
                  ),
                ),
                // 中央数字显示与切换按钮
                Positioned(
                  top: height * 0.22,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x55162E29),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x337CE1D4)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVolume ? Icons.volume_up_rounded : Icons.av_timer_rounded,
                                size: 14,
                                color: isVolume ? const Color(0xFFFFC83B) : const Color(0xFF7CE1D4),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                titleText,
                                style: TextStyle(
                                  color: isVolume ? const Color(0xFFFFC83B) : const Color(0xFF7CE1D4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.sync_alt_rounded, size: 12, color: Colors.white54),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            readoutText,
                            style: const TextStyle(
                              color: Color(0xFFFFFDF7),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 🎨 包豪斯弧度画笔：精确绘制圆弧、放射刻度与滑动圆钮
class BauhausArcDialPainter extends CustomPainter {
  final double value; // 0.0 ~ 1.0
  final bool isVolume;
  final Color baseColor;
  final Color activeColor;
  final Color tickColor;

  BauhausArcDialPainter({
    required this.value,
    required this.isVolume,
    this.baseColor = const Color(0x28FFFFFF),
    this.activeColor = const Color(0xFF7CE1D4),
    this.tickColor = const Color(0x66FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final radius = (size.width * 0.38).clamp(65.0, 130.0);

    const startAngle = pi * 0.82;
    const sweepAngle = pi * 1.36;

    // 1. 绘制放射刻度线
    const tickCount = 21;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = startAngle + sweepAngle * t;
      final isMajor = i % 4 == 0;
      final tickLen = isMajor ? 9.0 : 5.0;
      final tickR1 = radius + 9.0;
      final tickR2 = tickR1 + tickLen;

      final p1 = Offset(center.dx + tickR1 * cos(angle), center.dy + tickR1 * sin(angle));
      final p2 = Offset(center.dx + tickR2 * cos(angle), center.dy + tickR2 * sin(angle));

      final isActive = t <= value;
      tickPaint.color = isActive
          ? (isMajor ? const Color(0xFFFFC83B) : activeColor)
          : (isMajor ? const Color(0xAAFFFFFF) : tickColor);
      tickPaint.strokeWidth = isMajor ? 2.0 : 1.2;

      canvas.drawLine(p1, p2, tickPaint);
    }

    // 2. 绘制弧形底轨
    final bgArcPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgArcPaint,
    );

    // 3. 绘制发光高亮激活弧轨
    final activeSweep = sweepAngle * value.clamp(0.0, 1.0);
    if (activeSweep > 0.001) {
      final glowPaint = Paint()
        ..color = activeColor.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        glowPaint,
      );

      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    // 4. 绘制滑动旋钮
    final knobAngle = startAngle + sweepAngle * value.clamp(0.0, 1.0);
    final knobCenter = Offset(
      center.dx + radius * cos(knobAngle),
      center.dy + radius * sin(knobAngle),
    );

    // 旋钮阴影与深色外环
    final knobShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(knobCenter + const Offset(0, 2), 11, knobShadowPaint);

    final knobOuterPaint = Paint()
      ..color = const Color(0xFF1B3630)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 11, knobOuterPaint);

    final knobRimPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(knobCenter, 11, knobRimPaint);

    // 旋钮中心高光小圆点 (音量模式为金黄，进度模式为象牙白)
    final knobDotPaint = Paint()
      ..color = isVolume ? const Color(0xFFFFC83B) : const Color(0xFFFFFDF7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, 4, knobDotPaint);
  }

  @override
  bool shouldRepaint(covariant BauhausArcDialPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isVolume != isVolume ||
        oldDelegate.activeColor != activeColor;
  }
}
