import 'package:flutter/material.dart';
import '../services/livekit_service.dart';

class CallTypeSelector extends StatelessWidget {
  final CallType selectedType;
  final ValueChanged<CallType> onTypeChanged;

  const CallTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Call Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CallTypeOption(
                type: CallType.video,
                icon: Icons.videocam,
                label: 'Video Call',
                isSelected: selectedType == CallType.video,
                onTap: () => onTypeChanged(CallType.video),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CallTypeOption(
                type: CallType.voice,
                icon: Icons.phone,
                label: 'Voice Call',
                isSelected: selectedType == CallType.voice,
                onTap: () => onTypeChanged(CallType.voice),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CallTypeOption extends StatelessWidget {
  final CallType type;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CallTypeOption({
    required this.type,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

