import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'call_type_selector.dart';
import 'error_message_widget.dart';
import 'modern_button.dart';
import '../services/livekit_service.dart';

class JoinFormCard extends StatelessWidget {
  final CallType selectedCallType;
  final ValueChanged<CallType> onCallTypeChanged;
  final TextEditingController roomNameController;
  final TextEditingController nameController;
  final String? Function(String?)? validateRoomName;
  final String? Function(String?)? validateName;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onJoinPressed;

  const JoinFormCard({
    super.key,
    required this.selectedCallType,
    required this.onCallTypeChanged,
    required this.roomNameController,
    required this.nameController,
    this.validateRoomName,
    this.validateName,
    this.errorMessage,
    this.isLoading = false,
    required this.onJoinPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CallTypeSelector(
            selectedType: selectedCallType,
            onTypeChanged: onCallTypeChanged,
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: roomNameController,
            decoration: InputDecoration(
              labelText: 'Room Name',
              hintText: 'Enter room name',
              prefixIcon: const Icon(Icons.meeting_room_outlined),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: validateRoomName,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Your Name',
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: validateName,
            textCapitalization: TextCapitalization.words,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 20),
            ErrorMessageWidget(message: errorMessage!),
          ],
          const SizedBox(height: 28),
          ModernButton(
            text: 'Join Room',
            onPressed: isLoading ? null : onJoinPressed,
            isLoading: isLoading,
            isEnabled: !isLoading,
            width: double.infinity,
            icon: selectedCallType == CallType.video
                ? Icons.videocam_rounded
                : Icons.phone_rounded,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 600.ms).slideY(
          begin: 0.2,
          end: 0,
        );
  }
}

