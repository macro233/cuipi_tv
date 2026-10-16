import 'package:flutter/material.dart';
import '../models/theme_preset.dart';
import 'tv_focusable.dart';

class AppTopHeader extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onOpenSettings;
  final bool isMobile;
  final bool isTv;
  final String currentThemeKey;

  const AppTopHeader({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onOpenSettings,
    this.isMobile = false,
    this.isTv = false,
    this.currentThemeKey = 'ivory',
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemePreset.getByKey(currentThemeKey);
    final isLight = theme.isLight;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            // 1. Seamless Brand Mascot Logo & Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "脆皮",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isLight ? theme.textColor : const Color(0xFFFFFDF7),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFC83B), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            "TV",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF14161E),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "极简高清影院 · 局域网互联",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isLight ? theme.secondaryTextColor : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),

            // 2. 右侧局域网状态指示 Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isLight ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLight ? theme.cardBorder : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "局域网服务",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLight ? theme.textColor : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 📺 大屏电视版 (TV Mode) & 💻 电脑/平板桌面端
    final logoSize = isTv ? 44.0 : 36.0;
    final titleFontSize = isTv ? 24.0 : 20.0;
    final badgeFontSize = isTv ? 12.0 : 11.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTv ? 24 : 14,
        vertical: isTv ? 14 : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. 无缝一体化品牌 Logo & 标题（彻底告别生硬未抠白框，融入主题）
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isTv ? 14 : 11),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: isTv ? 14 : 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isTv ? 14 : 11),
                  child: Image.asset(
                    'assets/logo.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "脆皮",
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isLight ? theme.textColor : const Color(0xFFFFFDF7),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 8 : 6,
                  vertical: isTv ? 3 : 2,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC83B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(isTv ? 8 : 6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  "TV",
                  style: TextStyle(
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF14161E),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          // 2. 中间导航胶囊：影视点播 / 电视直播 / 本地资源 (天然透明无缝，电视版更大)
          Container(
            padding: EdgeInsets.all(isTv ? 5 : 3),
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(isTv ? 32 : 24),
              border: Border.all(
                color: isLight
                    ? theme.cardBorder
                    : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavPill(
                  "影视点播",
                  icon: Icons.movie_filter_rounded,
                  keyName: "vod",
                  theme: theme,
                  isTv: isTv,
                ),
                _buildNavPill(
                  "电视直播",
                  icon: Icons.live_tv_rounded,
                  keyName: "live",
                  theme: theme,
                  isTv: isTv,
                ),
                _buildNavPill(
                  "本地资源",
                  icon: Icons.dns_rounded,
                  keyName: "local",
                  theme: theme,
                  isTv: isTv,
                ),
              ],
            ),
          ),

          // 3. 右侧系统设置按钮 (大屏高反差、大触摸/按键区域)
          TvFocusable(
            onTap: onOpenSettings,
            builder: (context, isFocused) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 20 : 14,
                  vertical: isTv ? 12 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: isFocused
                      ? const LinearGradient(
                          colors: [Color(0xFFFFC83B), Color(0xFFD97706)],
                        )
                      : (isLight
                          ? null
                          : LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.14),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                            )),
                  color: (!isFocused && isLight)
                      ? Colors.black.withValues(alpha: 0.05)
                      : null,
                  borderRadius: BorderRadius.circular(isTv ? 24 : 18),
                  border: Border.all(
                    color: isFocused
                        ? const Color(0xFFFFD166)
                        : (isLight
                            ? theme.cardBorder
                            : Colors.white.withValues(alpha: 0.2)),
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: isTv ? 20 : 16,
                      color: isFocused
                          ? const Color(0xFF14161E)
                          : (isLight ? theme.textColor : Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "偏好设置",
                      style: TextStyle(
                        fontSize: isTv ? 15 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: isFocused
                            ? const Color(0xFF14161E)
                            : (isLight ? theme.textColor : Colors.white),
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

  Widget _buildNavPill(
    String title, {
    IconData? icon,
    required String keyName,
    required ThemePreset theme,
    required bool isTv,
  }) {
    final isSelected = selectedTab == keyName;
    final isLight = theme.isLight;

    return TvFocusable(
      onTap: () => onTabChanged(keyName),
      builder: (context, isFocused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: isTv ? 20 : 14,
            vertical: isTv ? 10 : 7,
          ),
          decoration: BoxDecoration(
            gradient: (isSelected || isFocused)
                ? LinearGradient(
                    colors: [theme.accent, theme.accent.withValues(alpha: 0.85)],
                  )
                : null,
            color: (isSelected || isFocused)
                ? null
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isTv ? 22 : 16),
            border: Border.all(
              color: (isSelected || isFocused)
                  ? theme.accent
                  : Colors.transparent,
              width: (isSelected || isFocused) ? 1.5 : 1,
            ),
            boxShadow: (isSelected || isFocused)
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.35),
                      blurRadius: isTv ? 12 : 8,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: isTv ? 18 : 15,
                  color: (isSelected || isFocused)
                      ? Colors.white
                      : (isLight ? theme.textColor : const Color(0xFFCBD5E1)),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: isTv ? 15 : 12.5,
                  fontWeight: (isSelected || isFocused) ? FontWeight.w900 : FontWeight.w700,
                  color: (isSelected || isFocused)
                      ? Colors.white
                      : (isLight ? theme.textColor : const Color(0xFFCBD5E1)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
