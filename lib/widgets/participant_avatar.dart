import 'package:flutter/material.dart';

class ParticipantAvatar extends StatefulWidget {
  final String name;
  final double size;
  final bool isSpeaking;
  final double? audioLevel;
  final bool showVideoOffIndicator;
  final Color? color;

  const ParticipantAvatar({
    super.key,
    required this.name,
    this.size = 80.0,
    this.isSpeaking = false,
    this.audioLevel,
    this.showVideoOffIndicator = false,
    this.color,
  });

  @override
  State<ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<ParticipantAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ParticipantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  double _getPulseScale() {
    if (!widget.isSpeaking) return 1.0;
    final level = widget.audioLevel ?? 0.0;
    final intensity = (level * 0.2).clamp(0.0, 0.2);
    return 1.0 + intensity;
  }

  double _getBorderWidth() {
    if (!widget.isSpeaking) return 0.0;
    final level = widget.audioLevel ?? 0.0;
    return 2.0 + (level * 2.0).clamp(0.0, 2.0);
  }

  double _getShadowIntensity() {
    if (!widget.isSpeaking) return 0.0;
    final level = widget.audioLevel ?? 0.0;
    return (0.3 + level * 0.4).clamp(0.3, 0.7);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static const List<Color> _colorPalette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFF3B82F6),
  ];

  Color _getColorForName(String name) {
    if (widget.color != null) return widget.color!;
    final hash = name.hashCode;
    return _colorPalette[hash.abs() % _colorPalette.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getColorForName(widget.name);
    final initials = _getInitials(widget.name);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseScale = widget.isSpeaking ? _pulseAnimation.value * _getPulseScale() : 1.0;
        final borderWidth = _getBorderWidth();
        final shadowIntensity = _getShadowIntensity();
        
        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
              border: widget.isSpeaking
                  ? Border.all(
                      color: Colors.green,
                      width: borderWidth,
                    )
                  : null,
              boxShadow: widget.isSpeaking
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: shadowIntensity),
                        blurRadius: 15.0 + (widget.audioLevel ?? 0.0) * 10.0,
                        spreadRadius: 3.0 + (widget.audioLevel ?? 0.0) * 3.0,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.size * 0.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.showVideoOffIndicator)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

