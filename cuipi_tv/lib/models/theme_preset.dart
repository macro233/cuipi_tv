import 'package:flutter/material.dart';

class ThemePreset {
  final String key;
  final String name;
  final String subtitle;
  final List<Color> colors;
  final Color accent;

  const ThemePreset({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.colors,
    required this.accent,
  });

  static const List<ThemePreset> presets = [
    ThemePreset(
      key: 'teal',
      name: '松石墨绿 (包豪斯经典)',
      subtitle: '护眼低眩光 · 沉浸艺术感',
      colors: [Color(0xFF152A25), Color(0xFF1F3D36), Color(0xFF13231F)],
      accent: Color(0xFF2DD4BF),
    ),
    ThemePreset(
      key: 'dark',
      name: '曜石极夜 (OLED 纯黑)',
      subtitle: '超高对比度 · OLED 省电深邃',
      colors: [Color(0xFF090B10), Color(0xFF131722), Color(0xFF0D1017)],
      accent: Color(0xFF60A5FA),
    ),
    ThemePreset(
      key: 'blue',
      name: '浩瀚星海 (深空深蓝)',
      subtitle: '科技冷静 · 沉浸影院',
      colors: [Color(0xFF0A192F), Color(0xFF112240), Color(0xFF0A1526)],
      accent: Color(0xFF38BDF8),
    ),
    ThemePreset(
      key: 'warm',
      name: '暖冬焦糖 (复古胶片)',
      subtitle: '温润柔和 · 复古老放映机质感',
      colors: [Color(0xFF241612), Color(0xFF38231C), Color(0xFF1C110E)],
      accent: Color(0xFFFB923C),
    ),
    ThemePreset(
      key: 'violet',
      name: '幻境星云 (赛博深紫)',
      subtitle: '神秘梦幻 · 前卫视觉冲击',
      colors: [Color(0xFF191228), Color(0xFF281D40), Color(0xFF130E20)],
      accent: Color(0xFFA78BFA),
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
}
