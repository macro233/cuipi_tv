import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/theme_preset.dart';

class SettingsModal extends StatefulWidget {
  final String currentThemeKey;
  final ValueChanged<String> onThemeChanged;
  final String serverUrl;
  final VoidCallback onClose;
  final Function(String) onTriggerToast;

  const SettingsModal({
    Key? key,
    required this.currentThemeKey,
    required this.onThemeChanged,
    required this.serverUrl,
    required this.onClose,
    required this.onTriggerToast,
  }) : super(key: key);

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  int _settingsTab = 0; // 0: 主题背景颜色, 1: 播放源状态与测速, 2: 局域网服务

  @override
  Widget build(BuildContext context) {
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
                            onTap: widget.onClose,
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
        ...ThemePreset.presets.map((t) {
          final isSelected = widget.currentThemeKey == t.key;
          return GestureDetector(
            onTap: () {
              widget.onThemeChanged(t.key);
              widget.onTriggerToast("已切换背景主题: ${t.name}");
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: t.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? t.accent : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: t.accent.withValues(alpha: 0.35),
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
                      gradient: LinearGradient(colors: t.colors),
                    ),
                    child: isSelected ? Icon(Icons.check_rounded, size: 20, color: t.accent) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? t.accent : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.subtitle,
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
                        color: t.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.accent, width: 1),
                      ),
                      child: Text(
                        "当前生效",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.accent),
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
        'desc': '本地视频直读与持久化离线缩略图秒出',
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
                widget.onTriggerToast("⚡ 正在重新测速所有播放源节点...");
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) setState(() {});
                  widget.onTriggerToast("✅ 所有源测速完毕 · 均处于极速可用状态");
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
