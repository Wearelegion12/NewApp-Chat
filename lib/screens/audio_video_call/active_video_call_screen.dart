import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:loveell/services/call_service.dart';
import 'package:loveell/models/user_model.dart';

class ActiveVideoCallScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel partner;
  final CallService callService;

  const ActiveVideoCallScreen({
    super.key,
    required this.currentUser,
    required this.partner,
    required this.callService,
  });

  @override
  State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  int _callDuration = 0;
  bool _isCallEnded = false;
  late Timer _timer;
  bool _localVideoVisible = true;

  // Create renderers for video
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _startTimer();
    _listenToCallStatus();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // Attach streams to renderers
    if (widget.callService.localStream != null) {
      _localRenderer.srcObject = widget.callService.localStream;
    }

    if (widget.callService.remoteStreams.isNotEmpty) {
      _remoteRenderer.srcObject = widget.callService.remoteStreams.first;
    }

    // Listen for stream changes
    widget.callService.callStatusStream.listen((status) {
      if (widget.callService.localStream != null) {
        _localRenderer.srcObject = widget.callService.localStream;
      }
      if (widget.callService.remoteStreams.isNotEmpty) {
        _remoteRenderer.srcObject = widget.callService.remoteStreams.first;
      }
    });
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.callService.callStatus == CallStatus.connected) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  void dispose() {
    _timer.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            if (_remoteRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade800,
                        child: Text(
                          widget.partner.name.isNotEmpty
                              ? widget.partner.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.partner.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<CallStatus>(
                        stream: widget.callService.callStatusStream,
                        initialData: CallStatus.connecting,
                        builder: (context, snapshot) {
                          final status = snapshot.data ?? CallStatus.connecting;
                          String statusText = status == CallStatus.connecting
                              ? 'Connecting...'
                              : 'Connecting...';
                          return Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Local video preview (small overlay)
            if (_localRenderer.srcObject != null && _localVideoVisible)
              Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _localVideoVisible = !_localVideoVisible;
                    });
                  },
                  child: Container(
                    width: 100,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RTCVideoView(
                        _localRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
              ),

            // Call duration
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_callDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Control buttons
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: () {
                      widget.callService.toggleMute();
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),

                  // Video toggle button
                  _buildControlButton(
                    icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    color: _isVideoEnabled ? Colors.white : Colors.red,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    label: _isVideoEnabled ? 'Video On' : 'Video Off',
                    onPressed: () {
                      widget.callService.toggleVideo();
                      setState(() {
                        _isVideoEnabled = !_isVideoEnabled;
                        _localVideoVisible = !_localVideoVisible;
                      });
                      // Update renderer
                      if (widget.callService.localStream != null) {
                        _localRenderer.srcObject =
                            widget.callService.localStream;
                      }
                    },
                  ),

                  // Switch camera button
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    color: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    label: 'Flip',
                    onPressed: () async {
                      await widget.callService.switchCamera();
                      // Update renderer after camera switch
                      if (widget.callService.localStream != null) {
                        _localRenderer.srcObject =
                            widget.callService.localStream;
                      }
                    },
                  ),

                  // End call button
                  Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
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
                          onPressed: () {
                            widget.callService.endCall().then((_) {
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            });
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
                ],
              ),
            ),

            // Small indicator for local video hidden
            if (!_localVideoVisible && _localRenderer.srcObject != null)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam_off,
                    color: Colors.white,
                    size: 20,
                  ),
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
    required Color backgroundColor,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: backgroundColor,
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
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
