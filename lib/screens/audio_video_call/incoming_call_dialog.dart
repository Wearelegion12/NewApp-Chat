import 'package:flutter/material.dart';
import 'package:loveell/services/call_service.dart';

class IncomingCallDialog extends StatefulWidget {
  final String callerName;
  final String roomId;
  final String callType; // 'audio' or 'video'
  final CallService callService;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.roomId,
    required this.callType,
    required this.callService,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
        _startTimer();
      } else if (_secondsRemaining == 0) {
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              // FIXED: Replaced withOpacity with withValues
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // FIXED: Both withOpacity calls replaced
                      color: isVideo
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVideo ? Icons.videocam : Icons.phone_in_talk,
                      size: 40,
                      color: isVideo
                          ? Colors.blue.shade600
                          : Colors.green.shade600,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            Text(
              widget.callerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isVideo ? 'Incoming video call' : 'Incoming audio call',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              '$_secondsRemaining s',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject button
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    onPressed: widget.onReject,
                  ),
                ),

                // Accept button
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isVideo ? Colors.blue : Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isVideo ? Icons.videocam : Icons.call,
                      color: Colors.white,
                    ),
                    onPressed: widget.onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
