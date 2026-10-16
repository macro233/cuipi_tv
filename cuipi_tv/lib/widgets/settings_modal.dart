import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/theme_preset.dart';
import '../models/video_source_model.dart';
import '../services/source_manager_service.dart';

class SettingsModal extends StatefulWidget {
  final String currentThemeKey;
  final ValueChanged<String> onThemeChanged;
  final String serverUrl;
  final VoidCallback onClose;
  final Function(String) onTriggerToast;
  final ValueChanged<VideoSourceModel>? onSelectSource;

  const SettingsModal({
    super.key,
    required this.currentThemeKey,
    required this.onThemeChanged,
    required this.serverUrl,
    required this.onClose,
    required this.onTriggerToast,
    this.onSelectSource,
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  int _settingsTab = 0; // 0: 主题背景颜色, 1: 播放源状态与测速, 2: 局域网服务
  final SourceManagerService _sourceManager = SourceManagerService();
  List<VideoSourceModel> _sources = [];
  bool _isLoadingSources = true;
  bool _isPinging = false;
  String _sortCriterion = 'default'; // 'default', 'ping', 'name'
  String _activeSourceId = 'src_bf';

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final list = await _sourceManager.loadSources();
    if (mounted) {
      setState(() {
        _sources = List.from(list);
        _activeSourceId = _sourceManager.activeSourceId;
        _isLoadingSources = false;
      });
    }
  }

  void _onSortChanged(String criterion) {
    setState(() {
      _sortCriterion = criterion;
      if (criterion == 'ping') {
        _sources.sort((a, b) => a.pingMs.compareTo(b.pingMs));
      } else if (criterion == 'name') {
        _sources.sort((a, b) => a.name.compareTo(b.name));
      } else {
        _sources = List.from(_sourceManager.getDefaultSources());
      }
    });
    _sourceManager.saveSources(_sources);
    widget.onTriggerToast("已按${criterion == 'ping' ? '测速延迟' : criterion == 'name' ? '名称' : '默认推荐'}排序");
  }

  Future<void> _pingAllSources() async {
    if (_isPinging) return;
    setState(() => _isPinging = true);
    widget.onTriggerToast("⚡ 正在并行全网测速所有播放源节点...");
    await _sourceManager.pingAllSources((done, total) {
      if (mounted) setState(() {});
    });
    if (mounted) {
      setState(() {
        _isPinging = false;
        if (_sortCriterion == 'ping') {
          _sources.sort((a, b) => a.pingMs.compareTo(b.pingMs));
        }
      });
      widget.onTriggerToast("✅ 全源测速完成 · 最优节点已就绪");
    }
  }

  void _showAddSourceDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String selectedType = 'cms';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2433),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              title: Row(
                children: const [
                  Icon(Icons.add_link_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text("添加自定义播放源", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("源名称", style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "例如：极速4K自建源 / 我的备用仓",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.25),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text("源地址 (API / JSON / M3U)", style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: urlCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "https://... / http://...",
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.25),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text("接口协议类型", style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeChip('cms', 'CMS 采集', selectedType, (val) => setDialogState(() => selectedType = val)),
                        const SizedBox(width: 8),
                        _buildTypeChip('tvbox', 'TVBox 仓', selectedType, (val) => setDialogState(() => selectedType = val)),
                        const SizedBox(width: 8),
                        _buildTypeChip('live', 'IPTV 直播', selectedType, (val) => setDialogState(() => selectedType = val)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("取消", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final url = urlCtrl.text.trim();
                    if (name.isEmpty || url.isEmpty) {
                      widget.onTriggerToast("⚠️ 请完整填写源名称与链接");
                      return;
                    }
                    Navigator.pop(ctx);
                    final newSource = VideoSourceModel(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      url: url,
                      type: selectedType,
                      desc: '用户自定义源 · 实时解析',
                      isBuiltIn: false,
                    );
                    await _sourceManager.addSource(newSource);
                    setState(() {
                      _sources.insert(0, newSource);
                    });
                    widget.onTriggerToast("正在对新源《$name》测速...");
                    final ms = await _sourceManager.pingSource(newSource);
                    if (mounted) setState(() {});
                    widget.onTriggerToast("✅ 已成功添加《$name》(延迟: ${ms}ms)");
                  },
                  child: const Text("添加并立即测速", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypeChip(String type, String label, String current, ValueChanged<String> onSelect) {
    final isSelected = current == type;
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF60A5FA) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 660),
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
                            onTap: widget.onClose,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Navigation Tabs
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
    final lightThemes = ThemePreset.presets.where((t) => t.isLight).toList();
    final darkThemes = ThemePreset.presets.where((t) => !t.isLight).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 浅色艺术系提示
        Row(
          children: const [
            Icon(Icons.light_mode_rounded, color: Color(0xFFF59E0B), size: 18),
            SizedBox(width: 6),
            Text(
              "☀️ 优雅艺术浅色系 (包豪斯纸实质感 · 告别沉闷暗色)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "完美复刻参考海报的暖白羊皮纸与画廊质感，明快呼吸、温润优雅",
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 12),
        ...lightThemes.map((t) => _buildThemeCard(t)),

        const SizedBox(height: 16),
        // 深色沉浸系提示
        Row(
          children: const [
            Icon(Icons.dark_mode_rounded, color: Color(0xFF818CF8), size: 18),
            SizedBox(width: 6),
            Text(
              "🌙 经典沉浸深色系 (高对比度 · OLED夜间专线)",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "适合昏暗光线或家庭影院夜间沉浸播放",
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 12),
        ...darkThemes.map((t) => _buildThemeCard(t)),
      ],
    );
  }

  Widget _buildThemeCard(ThemePreset t) {
    final isSelected = widget.currentThemeKey == t.key;
    return GestureDetector(
      onTap: () {
        widget.onThemeChanged(t.key);
        widget.onTriggerToast("已切换背景主题: ${t.name}");
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: t.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? t.accent : (t.isLight ? const Color(0x33000000) : Colors.white.withValues(alpha: 0.15)),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                border: Border.all(color: t.isLight ? Colors.black26 : Colors.white38, width: 1.5),
                gradient: LinearGradient(colors: t.colors),
              ),
              child: isSelected ? Icon(Icons.check_rounded, size: 20, color: t.accent) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? t.accent : (t.isLight ? const Color(0xFF1E1A17) : Colors.white),
                        ),
                      ),
                      if (t.isLight) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text("亮色质感", style: TextStyle(fontSize: 10, color: t.accent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: t.isLight ? const Color(0xFF5A5248) : Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "当前生效",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部控制与操作栏
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "播放源管理与全源测速",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("${_sources.length} 个可用源", style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "点击任意源即可激活切换 · 支持自定义添加与实时排序",
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
            Row(
              children: [
                // 添加源按钮
                GestureDetector(
                  onTap: _showAddSourceDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_rounded, size: 14, color: Color(0xFF34D399)),
                        SizedBox(width: 4),
                        Text("添加源", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF34D399))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 一键测速按钮
                GestureDetector(
                  onTap: _pingAllSources,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3B82F6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isPinging)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF60A5FA)),
                          )
                        else
                          const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 4),
                        Text(_isPinging ? "测速中" : "一键测速", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF60A5FA))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 排序筛选条
        Row(
          children: [
            const Text("排序方式:", style: TextStyle(fontSize: 11, color: Colors.white60)),
            const SizedBox(width: 8),
            _buildSortFilterPill("⚡ 按延迟升序", 'ping'),
            const SizedBox(width: 6),
            _buildSortFilterPill("🔥 默认推荐", 'default'),
            const SizedBox(width: 6),
            _buildSortFilterPill("🔤 按名称", 'name'),
          ],
        ),

        const SizedBox(height: 12),

        if (_isLoadingSources)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sources.length,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = _sources.removeAt(oldIdx);
                _sources.insert(newIdx, item);
              });
              _sourceManager.saveSources(_sources);
              widget.onTriggerToast("已更新播放源优先级顺序");
            },
            itemBuilder: (context, index) {
              final src = _sources[index];
              final isActive = _activeSourceId == src.id;
              final isFast = src.pingMs < 40;
              final pingColor = src.pingMs < 40
                  ? const Color(0xFF10B981)
                  : (src.pingMs < 80 ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B));

              return Container(
                key: ValueKey(src.id),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.1),
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // 拖拽排序图标
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator_rounded, color: Colors.white38, size: 20),
                    ),
                    const SizedBox(width: 10),
                    // 激活单选框 / 图标
                    GestureDetector(
                      onTap: () {
                        setState(() => _activeSourceId = src.id);
                        _sourceManager.setActiveSource(src.id);
                        widget.onSelectSource?.call(src);
                        widget.onTriggerToast("已激活源: ${src.name}");
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? const Color(0xFF2563EB) : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: isActive ? const Color(0xFF60A5FA) : Colors.white24, width: 1.5),
                        ),
                        child: isActive ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 名称与描述
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeSourceId = src.id);
                          _sourceManager.setActiveSource(src.id);
                          widget.onSelectSource?.call(src);
                          widget.onTriggerToast("已激活源: ${src.name}");
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  src.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isActive ? const Color(0xFF60A5FA) : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    src.typeLabel,
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              src.desc.isNotEmpty ? src.desc : src.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 延迟测速 Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pingColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: pingColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 12, color: pingColor),
                          const SizedBox(width: 2),
                          Text("${src.pingMs} ms", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pingColor)),
                        ],
                      ),
                    ),
                    // 删除自定义源按钮
                    if (!src.isBuiltIn) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          await _sourceManager.deleteSource(src.id);
                          setState(() {
                            _sources.removeWhere((s) => s.id == src.id);
                          });
                          widget.onTriggerToast("已删除自定义源: ${src.name}");
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSortFilterPill(String label, String key) {
    final isSelected = _sortCriterion == key;
    return GestureDetector(
      onTap: () => _onSortChanged(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, color: isSelected ? const Color(0xFF60A5FA) : Colors.white70, fontWeight: FontWeight.bold),
        ),
      ),
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
                  data: widget.serverUrl,
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
                      widget.serverUrl,
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
}
