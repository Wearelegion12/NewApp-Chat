import 'package:flutter/material.dart';
import 'package:loveell/services/call_service.dart';
import 'package:loveell/models/user_model.dart';

class ActiveCallScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel partner;
  final CallService callService;

  const ActiveCallScreen({
    super.key,
    required this.currentUser,
    required this.partner,
    required this.callService,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  int _callDuration = 0;
  bool _isCallEnded = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenToCallStatus();
  }

  void _listenToCallStatus() {
    widget.callService.callStatusStream.listen((status) {
      if (status == CallStatus.ended && mounted && !_isCallEnded) {
        _isCallEnded = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    });
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && widget.callService.callStatus == CallStatus.connected) {
        setState(() => _callDuration++);
        _startTimer();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // Call header with back button and timer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      await widget.callService.endCall();
                      if (mounted) Navigator.pop(context);
                    },
                  ),

                  // Call timer / status
                  StreamBuilder<CallStatus>(
                    stream: widget.callService.callStatusStream,
                    initialData: CallStatus.connecting,
                    builder: (context, snapshot) {
                      final status = snapshot.data ?? CallStatus.connecting;
                      String statusText = '';
                      Color statusColor = Colors.white70;

                      if (status == CallStatus.connecting) {
                        statusText = 'Connecting...';
                        statusColor = Colors.orange;
                      } else if (status == CallStatus.connected) {
                        statusText = _formatDuration(_callDuration);
                        statusColor = Colors.white;
                      }

                      return Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Partner info section
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Partner avatar with animated border
                  StreamBuilder<CallStatus>(
                    stream: widget.callService.callStatusStream,
                    initialData: CallStatus.connecting,
                    builder: (context, snapshot) {
                      final isConnected = snapshot.data == CallStatus.connected;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          // FIXED: Replaced withOpacity with withValues
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isConnected
                                ? const Color(0xFF4CAF50)
                                // FIXED: Replaced withOpacity with withValues
                                : const Color(0xFFE91E63)
                                    .withValues(alpha: 0.5),
                            width: isConnected ? 3 : 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.partner.name.isNotEmpty
                                ? widget.partner.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFFE91E63),
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  Text(
                    widget.partner.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  StreamBuilder<CallStatus>(
                    stream: widget.callService.callStatusStream,
                    initialData: CallStatus.connecting,
                    builder: (context, snapshot) {
                      final status = snapshot.data ?? CallStatus.connecting;
                      String statusMessage = '';

                      if (status == CallStatus.connecting) {
                        statusMessage = 'Connecting...';
                      } else if (status == CallStatus.connected) {
                        statusMessage = 'Connected';
                      }

                      return Text(
                        statusMessage,
                        // FIXED: Replaced withOpacity with withValues
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Call controls
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // FIXED: Replaced withOpacity with withValues
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: () {
                      widget.callService.toggleMute();
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),

                  // End call button
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red,
                              blurRadius: 20,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.call_end,
                              color: Colors.white, size: 30),
                          onPressed: () async {
                            await widget.callService.endCall();
                            if (mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'End',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Speaker button
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeakerOn ? Colors.blue : Colors.white,
                    label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                    onPressed: () {
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            // FIXED: Replaced withOpacity with withValues
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 24),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          // FIXED: Replaced withOpacity with withValues
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
