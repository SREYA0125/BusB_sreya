import 'package:flutter/material.dart';

class HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final Color backgroundColor;
  final double borderRadius;

  const HoverButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 55.0,
    this.backgroundColor = Colors.blueAccent,
    this.borderRadius = 30.0,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          transform: Matrix4.identity()..scale(_isHovering && widget.onPressed != null ? 1.05 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _isHovering && widget.onPressed != null
                ? [
                    BoxShadow(
                      color: widget.backgroundColor.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
