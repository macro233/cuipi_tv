import 'package:flutter/material.dart';
import '../models/theme_preset.dart';
import 'tv_focusable.dart';

class AppTopHeader extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onOpenSettings;
  final bool isMobile;
  final String currentThemeKey;

  const AppTopHeader({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onOpenSettings,
    this.isMobile = false,
    this.currentThemeKey = 'teal',
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
                        color: theme.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', width: 34, height: 34, fit: BoxFit.contain),
                ),
                const SizedBox(width: 8),
                Text(
                  "脆皮tv",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isLight ? theme.textColor : const Color(0xFFF0F0F0),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Navigation tabs: 影视 / 直播 / 本地
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavPill("🎬 影视", keyName: "vod", theme: theme),
                    _buildNavPill("📺 直播", keyName: "live", theme: theme),
                    _buildNavPill("💾 本地", keyName: "local", theme: theme),
                  ],
                ),
              ),
            ),
            // Far Right: Settings Button
            TvFocusable(
              onTap: onOpenSettings,
              builder: (context, isFocused) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? theme.accent
                        : (isLight ? Colors.white : Colors.white.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFocused ? theme.accent : (isLight ? theme.cardBorder : Colors.white.withValues(alpha: 0.18)),
                      width: 1.2,
                    ),
                    boxShadow: isLight
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: isFocused ? Colors.white : (isLight ? theme.textColor : theme.accent),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "设置",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isFocused ? Colors.white : (isLight ? theme.textColor : Colors.white),
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
              color: isLight ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isLight ? theme.cardBorder : Colors.white.withValues(alpha: 0.15)),
              boxShadow: isLight
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]
                  : null,
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
                        color: theme.accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', width: 36, height: 36, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Text(
                  "脆皮tv",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isLight ? theme.textColor : const Color(0xFFF0F0F0),
                  ),
                ),
              ],
            ),
          ),
          // Navigation tabs: 影视点播 / 电视直播 / 本地资源 (Center pills)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isLight ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: isLight ? theme.cardBorder : Colors.white.withValues(alpha: 0.15)),
              boxShadow: isLight
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavPill("🎬 影视点播", keyName: "vod", theme: theme),
                _buildNavPill("📺 电视直播", keyName: "live", theme: theme),
                _buildNavPill("💾 本地资源", keyName: "local", theme: theme),
              ],
            ),
          ),
          // Far Right: Settings Button
          TvFocusable(
            onTap: onOpenSettings,
            builder: (context, isFocused) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isFocused
                      ? LinearGradient(colors: [theme.accent, theme.accent.withValues(alpha: 0.8)])
                      : LinearGradient(
                          colors: [
                            const Color(0xFF2563EB).withValues(alpha: 0.85),
                            const Color(0xFF1D4ED8).withValues(alpha: 0.85),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isFocused ? Colors.white : const Color(0xFF60A5FA).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isFocused ? theme.accent : const Color(0xFF2563EB)).withValues(alpha: 0.35),
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
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "系统设置",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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

  Widget _buildNavPill(String title, {required String keyName, required ThemePreset theme}) {
    final isSelected = selectedTab == keyName;
    final isLight = theme.isLight;

    return TvFocusable(
      onTap: () => onTabChanged(keyName),
      builder: (context, isFocused) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: (isSelected || isFocused)
                ? LinearGradient(colors: [theme.accent, theme.accent.withValues(alpha: 0.85)])
                : null,
            color: (isSelected || isFocused)
                ? null
                : (isLight ? Colors.transparent : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isSelected || isFocused)
                  ? theme.accent
                  : (isLight ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
              width: (isSelected || isFocused) ? 1.5 : 1,
            ),
            boxShadow: (isSelected || isFocused)
                ? [BoxShadow(color: theme.accent.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: (isSelected || isFocused)
                  ? Colors.white
                  : (isLight ? theme.secondaryTextColor : const Color(0xFF94A3B8)),
            ),
          ),
        );
      },
    );
  }
}
