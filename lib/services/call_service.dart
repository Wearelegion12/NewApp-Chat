import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:loveell/models/user_model.dart';

enum CallStatus {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  ended,
  rejected,
}

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // WebRTC related
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = [];

  // Call state
  CallStatus _callStatus = CallStatus.idle;
  String? _currentRoomId;
  String? _currentCallId;
  String? _currentCallType; // 'audio' or 'video'
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _offerCandidatesSubscription;
  StreamSubscription<QuerySnapshot>? _answerCandidatesSubscription;

  // Callbacks
  Function(CallStatus)? onStatusChanged;
  Function(String callerName, String roomId, String callType)? onIncomingCall;

  // Getters
  CallStatus get callStatus => _callStatus;
  MediaStream? get localStream => _localStream;
  List<MediaStream> get remoteStreams => _remoteStreams;
  bool get isInCall => _callStatus == CallStatus.connected;
  String? get currentCallType => _currentCallType;

  // Stream for UI updates
  final _callStatusController = StreamController<CallStatus>.broadcast();
  Stream<CallStatus> get callStatusStream => _callStatusController.stream;

  // WebRTC configuration
  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  // Initialize call service
  Future<void> init() async {
    // Initialization complete
  }

  // Request microphone and camera access for video call
  Future<void> _getUserMedia(bool isVideo) async {
    try {
      final mediaConstraints = isVideo
          ? {'audio': true, 'video': true}
          : {'audio': true, 'video': false};
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      rethrow;
    }
  }

  // Create a peer connection
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_config, _constraints);

    // Add local stream
    if (_localStream != null) {
      _peerConnection?.addStream(_localStream!);
    }

    // Handle ICE candidates
    _peerConnection?.onIceCandidate = (candidate) {
      _sendIceCandidate(candidate);
    };

    // Handle connection state changes
    _peerConnection?.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _updateCallStatus(CallStatus.ended);
        onStatusChanged?.call(CallStatus.ended);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateCallStatus(CallStatus.connected);
        onStatusChanged?.call(CallStatus.connected);
      }
    };

    // Handle remote stream
    _peerConnection?.onTrack = (event) {
      _remoteStreams.clear();
      if (event.streams.isNotEmpty) {
        _remoteStreams.add(event.streams[0]);
      }
    };
  }

  // Send ICE candidate to Firestore
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (_currentRoomId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final isCaller = await _isCaller();
      final collection = isCaller ? 'offerCandidates' : 'answerCandidates';

      await _firestore
          .collection('rooms')
          .doc(_currentRoomId!)
          .collection(collection)
          .add({
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail
    }
  }

  // Check if current user is the caller
  Future<bool> _isCaller() async {
    if (_currentRoomId == null) return false;

    final roomDoc =
        await _firestore.collection('rooms').doc(_currentRoomId).get();
    final user = _auth.currentUser;

    if (!roomDoc.exists || user == null) return false;

    return roomDoc.data()?['callerId'] == user.uid;
  }

  // Update call status
  void _updateCallStatus(CallStatus status) {
    _callStatus = status;
    _callStatusController.add(status);
  }

  // Start an audio call
  Future<String?> startAudioCall(UserModel callee) async {
    return _startCall(callee, 'audio');
  }

  // Start a video call
  Future<String?> startVideoCall(UserModel callee) async {
    return _startCall(callee, 'video');
  }

  // Generic start call method
  Future<String?> _startCall(UserModel callee, String callType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      _currentCallType = callType;
      _updateCallStatus(CallStatus.calling);

      // Get media permissions based on call type
      await _getUserMedia(callType == 'video');

      final callerDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!callerDoc.exists) {
        return null;
      }
      final callerData =
          UserModel.fromMap(callerDoc.data() as Map<String, dynamic>);

      // Create room
      final roomRef = _firestore.collection('rooms').doc();
      _currentRoomId = roomRef.id;

      await roomRef.set({
        'callerId': user.uid,
        'callerName': callerData.name,
        'calleeId': callee.uid,
        'calleeName': callee.name,
        'callType': callType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create call record
      final callRef = _firestore.collection('calls').doc();
      _currentCallId = callRef.id;

      await callRef.set({
        'callId': callRef.id,
        'callerId': user.uid,
        'callerName': callerData.name,
        'calleeId': callee.uid,
        'calleeName': callee.name,
        'callType': callType,
        'status': 'ringing',
        'startTime': FieldValue.serverTimestamp(),
      });

      await _createPeerConnection();

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      await roomRef.update({
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      });

      // Listen for answer
      _roomSubscription = roomRef.snapshots().listen((snapshot) {
        if (snapshot.exists) {
          final answer = snapshot.data()?['answer'];
          if (answer != null) {
            _handleAnswer(answer);
          }
        }
      });

      // Listen for answer ICE candidates
      _answerCandidatesSubscription =
          roomRef.collection('answerCandidates').snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final candidateData = change.doc.data()?['candidate'];
            if (candidateData != null) {
              final candidate = RTCIceCandidate(
                candidateData['candidate'],
                candidateData['sdpMid'],
                candidateData['sdpMLineIndex'],
              );
              _peerConnection?.addCandidate(candidate);
            }
          }
        }
      });

      return roomRef.id;
    } catch (e) {
      _updateCallStatus(CallStatus.ended);
      return null;
    }
  }

  // Handle incoming answer
  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    try {
      _updateCallStatus(CallStatus.connecting);
      final answer =
          RTCSessionDescription(answerData['sdp'], answerData['type']);
      await _peerConnection?.setRemoteDescription(answer);
    } catch (e) {
      // Silently fail
    }
  }

  // Listen for incoming calls
  void listenForIncomingCalls() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('rooms')
        .where('calleeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final callerName = data['callerName'] as String?;
        final callType = data['callType'] as String? ?? 'audio';
        if (callerName != null) {
          onIncomingCall?.call(callerName, doc.id, callType);
        }
      }
    });
  }

  // Accept an incoming call
  Future<void> acceptCall(String roomId) async {
    try {
      _currentRoomId = roomId;
      _updateCallStatus(CallStatus.ringing);

      final roomRef = _firestore.collection('rooms').doc(roomId);
      final roomDoc = await roomRef.get();

      if (!roomDoc.exists) {
        return;
      }

      final data = roomDoc.data();
      if (data == null) return;

      _currentCallType = data['callType'] ?? 'audio';

      // Get media permissions based on call type
      await _getUserMedia(_currentCallType == 'video');

      await _createPeerConnection();

      final offerData = data['offer'];
      if (offerData == null) return;

      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await roomRef.update({
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'status': 'active',
      });

      // Update call record
      final callsQuery = await _firestore
          .collection('calls')
          .where('callerId', isEqualTo: data['callerId'])
          .where('calleeId', isEqualTo: data['calleeId'])
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (callsQuery.docs.isNotEmpty) {
        _currentCallId = callsQuery.docs.first.id;
        await callsQuery.docs.first.reference.update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      }

      // Listen for offer ICE candidates
      _offerCandidatesSubscription =
          roomRef.collection('offerCandidates').snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final candidateData = change.doc.data()?['candidate'];
            if (candidateData != null) {
              final candidate = RTCIceCandidate(
                candidateData['candidate'],
                candidateData['sdpMid'],
                candidateData['sdpMLineIndex'],
              );
              _peerConnection?.addCandidate(candidate);
            }
          }
        }
      });

      _updateCallStatus(CallStatus.connected);
    } catch (e) {
      _updateCallStatus(CallStatus.ended);
    }
  }

  // Reject an incoming call
  Future<void> rejectCall(String roomId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final roomDoc = await roomRef.get();

      if (!roomDoc.exists) return;

      final data = roomDoc.data();
      if (data == null) return;

      await roomRef.update({'status': 'rejected'});

      final callsQuery = await _firestore
          .collection('calls')
          .where('callerId', isEqualTo: data['callerId'])
          .where('calleeId', isEqualTo: data['calleeId'])
          .orderBy('startTime', descending: true)
          .limit(1)
          .get();

      if (callsQuery.docs.isNotEmpty) {
        await callsQuery.docs.first.reference.update({
          'status': 'rejected',
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  // End current call
  Future<void> endCall() async {
    try {
      if (_currentCallId != null) {
        await _firestore.collection('calls').doc(_currentCallId).update({
          'status': 'ended',
          'endTime': FieldValue.serverTimestamp(),
        });
      }

      if (_currentRoomId != null) {
        await _firestore.collection('rooms').doc(_currentRoomId).update({
          'status': 'ended',
        });
      }
    } catch (e) {
      // Silently fail
    } finally {
      _cleanup();
    }
  }

  // Toggle mute
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  // Toggle video
  void toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  // FIXED: Switch camera using Helper class
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  // Check if muted
  bool isMuted() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        return !audioTracks.first.enabled;
      }
    }
    return false;
  }

  // Check if video is enabled
  bool isVideoEnabled() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        return videoTracks.first.enabled;
      }
    }
    return false;
  }

  // Clean up resources
  void _cleanup() {
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((track) {
      track.stop();
      _localStream?.removeTrack(track);
    });
    _localStream = null;
    _remoteStreams.clear();
    _roomSubscription?.cancel();
    _offerCandidatesSubscription?.cancel();
    _answerCandidatesSubscription?.cancel();
    _currentRoomId = null;
    _currentCallId = null;
    _currentCallType = null;
    _updateCallStatus(CallStatus.idle);
  }

  // Dispose
  void dispose() {
    _cleanup();
    _callStatusController.close();
  }
}
