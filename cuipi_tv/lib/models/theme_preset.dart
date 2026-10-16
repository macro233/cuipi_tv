import 'package:flutter/material.dart';

class ThemePreset {
  final String key;
  final String name;
  final String subtitle;
  final List<Color> colors;
  final Color accent;
  final bool isLight;
  final Color textColor;
  final Color secondaryTextColor;
  final Color cardColor;
  final Color cardBorder;

  const ThemePreset({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.colors,
    required this.accent,
    this.isLight = false,
    this.textColor = Colors.white,
    this.secondaryTextColor = const Color(0xFF94A3B8),
    this.cardColor = const Color(0x1AFFFFFF),
    this.cardBorder = const Color(0x26FFFFFF),
  });

  static const List<ThemePreset> presets = [
    // 🎨 优雅包豪斯浅色系（摆脱暗色压抑，复刻艺术纸质感）
    ThemePreset(
      key: 'ivory',
      name: '包豪斯象牙白 (纸实质感)',
      subtitle: '图2画廊风 · 暖米纸面与陶土焦糖点缀',
      colors: [Color(0xFFFAF7F0), Color(0xFFF3ECE0), Color(0xFFE9DFD0)],
      accent: Color(0xFFD9531E), // 包豪斯经典陶土红橙
      isLight: true,
      textColor: Color(0xFF1E1A17),
      secondaryTextColor: Color(0xFF6B645A),
      cardColor: Color(0xF5FFFFFF),
      cardBorder: Color(0x33D9531E),
    ),
    ThemePreset(
      key: 'sunset',
      name: '日落暖杏 (朝霞陶土)',
      subtitle: '温润明亮 · 治愈柔光与温暖触感',
      colors: [Color(0xFFFFF6ED), Color(0xFFFEE8D6), Color(0xFFFDD5B4)],
      accent: Color(0xFFF97316),
      isLight: true,
      textColor: Color(0xFF2C1810),
      secondaryTextColor: Color(0xFF7A584B),
      cardColor: Color(0xF5FFFFFF),
      cardBorder: Color(0x33F97316),
    ),
    ThemePreset(
      key: 'mint',
      name: '北欧薄荷 (浅绿清新)',
      subtitle: '通透自然 · 护眼微风与草木呼吸感',
      colors: [Color(0xFFF1F8F5), Color(0xFFE1EFE8), Color(0xFFCFE6DC)],
      accent: Color(0xFF0D9488),
      isLight: true,
      textColor: Color(0xFF0F241D),
      secondaryTextColor: Color(0xFF476B61),
      cardColor: Color(0xF5FFFFFF),
      cardBorder: Color(0x330D9488),
    ),
    ThemePreset(
      key: 'sky',
      name: '海盐冰川 (清爽浅蓝)',
      subtitle: '冷萃明快 · 极简开阔海平线视野',
      colors: [Color(0xFFF0F6FA), Color(0xFFDFEDF6), Color(0xFFCEE2F0)],
      accent: Color(0xFF0284C7),
      isLight: true,
      textColor: Color(0xFF0E2238),
      secondaryTextColor: Color(0xFF486582),
      cardColor: Color(0xF5FFFFFF),
      cardBorder: Color(0x330284C7),
    ),
    ThemePreset(
      key: 'sakura',
      name: '京都暮云 (柔雾浅粉)',
      subtitle: '恬淡轻盈 · 暮春落樱般的浪漫粉调',
      colors: [Color(0xFFFAF2F5), Color(0xFFF5E3E9), Color(0xFFEED0DB)],
      accent: Color(0xFFE11D48),
      isLight: true,
      textColor: Color(0xFF2D1420),
      secondaryTextColor: Color(0xFF7A4B62),
      cardColor: Color(0xF5FFFFFF),
      cardBorder: Color(0x33E11D48),
    ),

    // 🌌 沉浸经典深色系（高对比度夜间观影）
    ThemePreset(
      key: 'teal',
      name: '松石墨绿 (包豪斯经典)',
      subtitle: '护眼低眩光 · 沉浸艺术感',
      colors: [Color(0xFF152A25), Color(0xFF1F3D36), Color(0xFF13231F)],
      accent: Color(0xFF2DD4BF),
      isLight: false,
    ),
    ThemePreset(
      key: 'dark',
      name: '曜石极夜 (OLED 纯黑)',
      subtitle: '超高对比度 · OLED 省电深邃',
      colors: [Color(0xFF090B10), Color(0xFF131722), Color(0xFF0D1017)],
      accent: Color(0xFF60A5FA),
      isLight: false,
    ),
    ThemePreset(
      key: 'blue',
      name: '浩瀚星海 (深空深蓝)',
      subtitle: '科技冷静 · 沉浸影院',
      colors: [Color(0xFF0A192F), Color(0xFF112240), Color(0xFF0A1526)],
      accent: Color(0xFF38BDF8),
      isLight: false,
    ),
    ThemePreset(
      key: 'warm',
      name: '暖冬焦糖 (复古胶片)',
      subtitle: '温润柔和 · 复古老放映机质感',
      colors: [Color(0xFF241612), Color(0xFF38231C), Color(0xFF1C110E)],
      accent: Color(0xFFFB923C),
      isLight: false,
    ),
  ];

  static ThemePreset getByKey(String key) {
    return presets.firstWhere(
      (p) => p.key == key,
      orElse: () => presets.first,
    );
  }

  static List<Color> getThemeColors(String key) {
    return getByKey(key).colors;
  }

  static bool isLightTheme(String key) {
    return getByKey(key).isLight;
  }
}
