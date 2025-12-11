import 'package:flutter/material.dart';

class CallControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final String? tooltip;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isActive = true,
    this.activeColor,
    this.inactiveColor,
    this.size = 64.0,
    this.tooltip,
  });

  Color _getColor(BuildContext context) {
    if (isActive) {
      return activeColor ?? Colors.green;
    } else {
      return inactiveColor ?? Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }
}

