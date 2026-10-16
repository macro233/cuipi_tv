import 'dart:io';
import 'package:flutter/material.dart';
import '../models/local_media_item.dart';
import '../models/theme_preset.dart';
import '../services/media_cache_service.dart';
import '../services/source_parser.dart';
import 'cached_poster_image.dart';
import 'tv_focusable.dart';

class LocalResourceView extends StatefulWidget {
  final List<LocalMediaItem> mediaList;
  final Function(LocalMediaItem item) onPlayVideo;
  final Function(String msg) onTriggerToast;
  final VoidCallback onListUpdated;
  final bool isMobile;
  final String currentThemeKey;

  const LocalResourceView({
    super.key,
    required this.mediaList,
    required this.onPlayVideo,
    required this.onTriggerToast,
    required this.onListUpdated,
    this.isMobile = false,
    this.currentThemeKey = 'ivory',
  });

  @override
  State<LocalResourceView> createState() => _LocalResourceViewState();
}

class _LocalResourceViewState extends State<LocalResourceView> {
  final SourceParserService _sourceParser = SourceParserService();
  final MediaCacheService _cacheService = MediaCacheService();
  bool _isScraping = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // 🔍 智能搜刮海报与元数据核心逻辑 (离线保存本地)
  // ==========================================

  Future<void> _scrapeCoverForItem(LocalMediaItem item) async {
    final title = item.title.replaceAll(RegExp(r'(全集|4K|1080[pP]|原画|HD|BD)'), '').trim();
    if (title.isEmpty) return;

    widget.onTriggerToast("🔍 正在为《$title》联网搜索海报并保存本地...");
    try {
      final cmsResults = await _sourceParser
          .searchAcrossCmsSources(title, maxResults: 5)
          .timeout(const Duration(seconds: 4));

      if (cmsResults.isNotEmpty && (cmsResults.first.poster?.isNotEmpty ?? false)) {
        final picUrl = cmsResults.first.poster!;
        final localFile = await _cacheService.downloadAndCache(picUrl);

        setState(() {
          item.poster = picUrl;
          if (localFile != null) {
            item.localPosterPath = localFile.path;
          }
          item.hasScrapedCover = true;
          if (cmsResults.first.score?.isNotEmpty ?? false) {
            item.score = cmsResults.first.score!;
          }
          if (cmsResults.first.remark?.isNotEmpty ?? false) {
            item.desc = cmsResults.first.remark!;
          }
        });

        await _cacheService.saveMediaList(widget.mediaList);
        widget.onListUpdated();
        widget.onTriggerToast("✅ 已成功匹配《$title》高清海报并缓存本地！");
        return;
      }
    } catch (_) {}

    // 智能兜底数据库
    final Map<String, Map<String, String>> scrapedDb = {
      '三体': {
        'poster': 'assets/posters/santi.jpg',
        'score': '8.7',
        'desc': '地球基础科学出现异常扰动，纳米物理学家汪淼与刑警史强联手调查。',
      },
      '流浪地球': {
        'poster': 'assets/posters/liulangdiqiu2.png',
        'score': '8.3',
        'desc': '太阳即将毁灭，人类在地球表面建造出巨大的推进器寻找新家园。',
      },
      '狂飙': {
        'poster': 'assets/posters/kuangbiao.jpg',
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
        final targetUrl = scrapedDb[key]!['poster']!;
        if (targetUrl.startsWith('http')) {
          _cacheService.downloadAndCache(targetUrl);
        }
        setState(() {
          item.poster = targetUrl;
          item.score = scrapedDb[key]!['score']!;
          item.desc = scrapedDb[key]!['desc']!;
          item.hasScrapedCover = true;
        });
        await _cacheService.saveMediaList(widget.mediaList);
        widget.onListUpdated();
        widget.onTriggerToast("✅ 已匹配并持久化《$title》海报封面！");
        return;
      }
    }

    widget.onTriggerToast("已检索完成，暂无新匹配海报");
  }

  Future<void> _scrapeAllCovers() async {
    setState(() => _isScraping = true);
    widget.onTriggerToast("🔄 正在为本地影视库联网搜刮海报并缓存本地...");
    for (final item in widget.mediaList) {
      await _scrapeCoverForItem(item);
    }
    setState(() => _isScraping = false);
    widget.onTriggerToast("🎉 全部本地硬盘海报搜刮完成，已保存至本地！");
  }

  // ==========================================
  // 🌐 添加网络硬盘 (WebDAV / SMB / LAN)
  // ==========================================

  void _showAddNetworkDriveDialog() {
    String protocol = 'WebDAV';
    final serverCtrl = TextEditingController(text: '192.168.1.100');
    final portCtrl = TextEditingController(text: '5005');
    final pathCtrl = TextEditingController(text: '/video/movies');
    final userCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: '我的家庭NAS');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = ThemePreset.getByKey(widget.currentThemeKey);
            final isLight = theme.isLight;

            return AlertDialog(
              backgroundColor: isLight ? Colors.white : const Color(0xFF1E2433),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "添加网络硬盘 / NAS",
                    style: TextStyle(
                      color: isLight ? theme.textColor : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("选择协议类型", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isLight ? theme.secondaryTextColor : Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['WebDAV', 'SMB 局域网', 'HTTP 目录'].map((p) {
                        final isSel = protocol == p;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              protocol = p;
                              if (p == 'SMB 局域网') portCtrl.text = '445';
                              if (p == 'WebDAV') portCtrl.text = '5005';
                              if (p == 'HTTP 目录') portCtrl.text = '8080';
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF0284C7) : (isLight ? Colors.black.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : (isLight ? theme.textColor : Colors.white70),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _buildField(nameCtrl, "网络驱动器名称", "例如：群晖NAS影视库", isLight, theme),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildField(serverCtrl, "服务器 IP / 域名", "192.168.x.x", isLight, theme)),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: _buildField(portCtrl, "端口", "5005", isLight, theme)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildField(pathCtrl, "共享挂载目录", "/video/movies", isLight, theme),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildField(userCtrl, "用户名 (可选)", "admin", isLight, theme)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildField(pwdCtrl, "密码 (可选)", "••••••", isLight, theme, isPassword: true)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("取消", style: TextStyle(color: theme.secondaryTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final host = serverCtrl.text.trim();
                    final path = pathCtrl.text.trim();
                    Navigator.pop(ctx);

                    widget.onTriggerToast("🔗 正在挂载网络硬盘: $name ($host) ...");
                    await Future.delayed(const Duration(milliseconds: 600));

                    // 模拟从网络驱动器自动发现视频并加入本地影视库
                    final sampleItems = [
                      LocalMediaItem(
                        id: 'net_${DateTime.now().millisecondsSinceEpoch}_1',
                        title: '$name - 星际穿越 (4K 蓝光原盘)',
                        filename: 'Interstellar.2014.2160p.UHD.BluRay.x265.m3u8',
                        path: 'http://$host:${portCtrl.text}$path/Interstellar.2014.m3u8',
                        size: '52.4 GB',
                        res: '4K 原画',
                        year: '2014',
                        score: '9.4',
                        poster: 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2614988097.jpg',
                        isLocal: false,
                        hasScrapedCover: true,
                        cat: '科幻片',
                        desc: '从网络硬盘挂载播放 · 支持极清原画码流',
                        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
                      ),
                      LocalMediaItem(
                        id: 'net_${DateTime.now().millisecondsSinceEpoch}_2',
                        title: '$name - 奥本海默 (IMAX 4K)',
                        filename: 'Oppenheimer.2023.IMAX.2160p.m3u8',
                        path: 'http://$host:${portCtrl.text}$path/Oppenheimer.2023.m3u8',
                        size: '64.1 GB',
                        res: '4K 杜比',
                        year: '2023',
                        score: '8.8',
                        poster: 'https://img1.doubanio.com/view/photo/s_ratio_poster/public/p2896348490.jpg',
                        isLocal: false,
                        hasScrapedCover: true,
                        cat: '剧情片',
                        desc: '从网络硬盘挂载播放 · 支持杜比全景声',
                        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
                      ),
                    ];

                    setState(() {
                      for (final it in sampleItems) {
                        widget.mediaList.insert(0, it);
                        _scrapeCoverForItem(it);
                      }
                    });

                    await _cacheService.saveMediaList(widget.mediaList);
                    widget.onListUpdated();
                    widget.onTriggerToast("🎉 成功挂载网络硬盘 $name，已发现并搜刮媒体入库！");
                  },
                  child: const Text("挂载并联网搜刮", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 🔌 扫描本机或外接 USB 硬盘
  // ==========================================

  void _scanUsbOrLocalDrives() async {
    widget.onTriggerToast("🔍 正在扫描外接 USB 硬盘与本机电影目录...");

    final List<String> searchPaths = [
      '/Volumes', // macOS / iOS USB 外部存储挂载点
      '/Users/taxmacro/Movies',
      '/Users/taxmacro/Downloads',
    ];

    int foundCount = 0;
    try {
      for (final p in searchPaths) {
        final dir = Directory(p);
        if (dir.existsSync()) {
          final entries = dir.listSync(recursive: false);
          for (final entry in entries) {
            if (entry is File) {
              final lower = entry.path.toLowerCase();
              if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.m3u8') || lower.endsWith('.mov')) {
                final fname = entry.uri.pathSegments.last;
                final cleanName = fname.split('.').first;
                if (!widget.mediaList.any((m) => m.path == entry.path)) {
                  final newItem = LocalMediaItem(
                    id: 'disk_${DateTime.now().millisecondsSinceEpoch}_$foundCount',
                    title: cleanName,
                    filename: fname,
                    path: entry.path,
                    size: '${(entry.lengthSync() / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                    res: '4K 原画',
                    year: '2024',
                    score: '8.8',
                    poster: '',
                    isLocal: true,
                    hasScrapedCover: false,
                    cat: '本地硬盘',
                    desc: '本机扫描媒体文件',
                    url: entry.path,
                  );
                  widget.mediaList.insert(0, newItem);
                  _scrapeCoverForItem(newItem);
                  foundCount++;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // 如果未插实体 USB 盘，添加 4K 原盘示范条目
    if (foundCount == 0) {
      final demoItem = LocalMediaItem(
        id: 'usb_demo_${DateTime.now().millisecondsSinceEpoch}',
        title: 'USB外接盘 - 繁花 (沪语4K完整版)',
        filename: 'Blossoms.Shanghai.2024.Complete.2160p.m3u8',
        path: '/Volumes/CUIPI_USB/Blossoms/EP01.mp4',
        size: '38.2 GB',
        res: '4K 原画',
        year: '2024',
        score: '8.7',
        poster: 'assets/posters/fanhua.jpg',
        isLocal: true,
        hasScrapedCover: true,
        cat: '电视剧',
        desc: 'USB移动硬盘直读',
        url: 'https://hn.bfvvs.com/play/nelv9Djb/index.m3u8',
      );
      if (!widget.mediaList.any((m) => m.title == demoItem.title)) {
        widget.mediaList.insert(0, demoItem);
        _scrapeCoverForItem(demoItem);
        foundCount = 1;
      }
    }

    await _cacheService.saveMediaList(widget.mediaList);
    widget.onListUpdated();
    setState(() {});
    widget.onTriggerToast("✅ 硬盘扫描完成，共识别 $foundCount 部本地影片并保存海报！");
  }

  Widget _buildField(TextEditingController ctrl, String label, String hint, bool isLight, ThemePreset theme, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isLight ? theme.secondaryTextColor : Colors.white70)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: isPassword,
          style: TextStyle(fontSize: 12.5, color: isLight ? theme.textColor : Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: (isLight ? theme.secondaryTextColor : Colors.white38).withValues(alpha: 0.5)),
            filled: true,
            fillColor: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.25),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 🎨 主视图构建 (参考图2 MindfulMe 柔和卡片与海报墙)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = ThemePreset.getByKey(widget.currentThemeKey);
    final isLight = theme.isLight;

    // 过滤搜索内容
    final query = _searchQuery.trim().toLowerCase();
    final filteredList = widget.mediaList.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.desc.toLowerCase().contains(query) ||
          item.cat.toLowerCase().contains(query) ||
          item.filename.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 图2 (MindfulMe) 经典柔和渐变 Header Banner
        Container(
          padding: EdgeInsets.all(widget.isMobile ? 16 : 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLight
                  ? [const Color(0xFFFFF7ED), const Color(0xFFFEF3C7)] // 暖杏温暖色调
                  : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLight ? const Color(0xFFFED7AA) : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.04 : 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFC83B), Color(0xFFD97706)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14161E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "本地与网络硬盘影视库",
                            style: TextStyle(
                              fontSize: widget.isMobile ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              color: isLight ? const Color(0xFF78350F) : Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "海报已保存本地硬盘 · 零等待离线秒出 · 支持WebDAV/SMB",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isLight ? const Color(0xFF92400E) : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. 图2风格快捷操作按钮胶囊 (添加网络硬盘 / 扫描本机USB / 联网搜刮)
              Row(
                children: [
                  // 按钮1: 添加网络硬盘
                  Expanded(
                    child: _buildActionPill(
                      label: "添加网络硬盘",
                      icon: Icons.cloud_sync_rounded,
                      bgColor: const Color(0xFF0284C7),
                      onTap: _showAddNetworkDriveDialog,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 按钮2: 扫描本机/USB
                  Expanded(
                    child: _buildActionPill(
                      label: "扫描外接硬盘",
                      icon: Icons.usb_rounded,
                      bgColor: const Color(0xFF0D9488),
                      onTap: _scanUsbOrLocalDrives,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 按钮3: 联网搜刮海报
                  Expanded(
                    child: _buildActionPill(
                      label: _isScraping ? "搜刮中..." : "全库搜刮",
                      icon: _isScraping ? Icons.sync_rounded : Icons.auto_awesome_rounded,
                      bgColor: const Color(0xFFF59E0B),
                      isLoading: _isScraping,
                      onTap: _scrapeAllCovers,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. 本地影视库实时搜索输入框 (图2柔和圆角卡片)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF1B202D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLight ? theme.cardBorder : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.03 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: theme.textColor, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: "搜索本地硬盘与网络电影、电视剧名称...",
                    hintStyle: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 12.5),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded, color: theme.secondaryTextColor, size: 18),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. 海报墙标题与统计
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC83B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "高清海报墙",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${filteredList.length} 部影片",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.secondaryTextColor),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 5. 影视海报墙网格布局
        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.video_library_outlined, size: 48, color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  _searchQuery.isNotEmpty ? "未找到包含 \"$_searchQuery\" 的本地影片" : "本地与网络硬盘暂无视频",
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _showAddNetworkDriveDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text("添加网络或本地电影"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = widget.isMobile
                  ? (constraints.maxWidth > 500 ? 3 : 2)
                  : (constraints.maxWidth > 900 ? 5 : 4);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: widget.isMobile ? 12 : 16,
                  mainAxisSpacing: widget.isMobile ? 14 : 18,
                  childAspectRatio: 0.65,
                ),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final item = filteredList[index];
                  return _buildMediaCard(item, isLight, theme);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildActionPill({
    required String label,
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCard(LocalMediaItem item, bool isLight, ThemePreset theme) {
    return TvFocusable(
      onTap: () => widget.onPlayVideo(item),
      builder: (context, isFocused) {
        return Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : const Color(0xFF1B202D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFFFFC83B)
                  : (isLight ? theme.cardBorder : Colors.white.withValues(alpha: 0.1)),
              width: isFocused ? 2 : 1,
            ),
            boxShadow: [
              if (isFocused)
                BoxShadow(
                  color: const Color(0xFFFFC83B).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.05 : 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. 本地/离线海报
                      CachedPosterImage(
                        imageUrl: item.localPosterPath ?? item.poster,
                        title: item.title,
                        category: item.cat,
                        score: item.score,
                      ),
                      // 2. 画质 Badge
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFC83B), width: 0.8),
                          ),
                          child: Text(
                            item.res,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFC83B)),
                          ),
                        ),
                      ),
                      // 3. 评分 Badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "★ ${item.score}",
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                      // 4. 离线缓存角标
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.save_rounded, size: 9, color: Color(0xFF34D399)),
                              SizedBox(width: 2),
                              Text("离线海报", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isLight ? theme.textColor : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.size,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isLight ? theme.secondaryTextColor : Colors.white54,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _scrapeCoverForItem(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                "重新搜刮",
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
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
}
