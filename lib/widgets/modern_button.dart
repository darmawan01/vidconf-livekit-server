import 'package:flutter/material.dart';

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.gradient,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 58.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed =
        (isEnabled && !isLoading) ? onPressed : null;
    final buttonGradient = gradient ??
        (backgroundColor == null
            ? const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null);

    final isDisabled = effectiveOnPressed == null;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled ? null : buttonGradient,
        color: isDisabled
            ? Colors.grey[300]
            : (buttonGradient == null ? backgroundColor : null),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: (buttonGradient?.colors.first ?? backgroundColor ?? Colors.grey)
                      .withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          textColor ?? Colors.white,
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 20,
                          color: isDisabled
                              ? Colors.grey[600]
                              : (textColor ?? Colors.white),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? Colors.grey[600]
                              : (textColor ?? Colors.white),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
