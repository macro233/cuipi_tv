import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
