import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:loveell/services/image_cache_service.dart';

class ImageConverter {
  static Future<String?> xFileToBase64(XFile imageFile,
      {bool highQuality = false}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      return null;
    }
  }

  static Future<XFile?> pickImage(ImageSource source,
      {bool highQuality = false}) async {
    final picker = ImagePicker();
    try {
      if (highQuality) {
        return await picker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 90,
        );
      } else {
        return await picker.pickImage(
          source: source,
          maxWidth: 500,
          maxHeight: 500,
          imageQuality: 70,
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  static Widget getCachedAvatar({
    required String? base64Image,
    required String name,
    required String uid,
    double size = 56,
    Color? backgroundColor,
    Color? textColor,
    Key? key,
    bool highQuality = false,
  }) {
    return CachedAvatar(
      key: key,
      base64Image: base64Image,
      name: name,
      size: size,
      backgroundColor: backgroundColor,
      textColor: textColor,
      uniqueId: uid,
      highQuality: highQuality,
    );
  }
}

class CachedAvatar extends StatefulWidget {
  final String? base64Image;
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final String uniqueId;
  final bool highQuality;

  const CachedAvatar({
    super.key,
    required this.base64Image,
    required this.name,
    required this.size,
    this.backgroundColor,
    this.textColor,
    required this.uniqueId,
    this.highQuality = false,
  });

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  Uint8List? _cachedBytes;
  String? _currentBase64Hash;
  bool _isLoading = false;
  bool _showInitials = false;

  @override
  void initState() {
    super.initState();
    _currentBase64Hash = widget.base64Image?.hashCode.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadImage();
      }
    });
  }

  @override
  void didUpdateWidget(CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newHash = widget.base64Image?.hashCode.toString() ?? 'null';
    final oldHash = oldWidget.base64Image?.hashCode.toString() ?? 'null';

    if (newHash != oldHash) {
      debugPrint(
          'CachedAvatar: Image changed for user ${widget.uniqueId} - Old: $oldHash, New: $newHash');

      // IMMEDIATELY clear everything and show initials
      setState(() {
        _cachedBytes = null;
        _showInitials = true;
        _currentBase64Hash = newHash;
        _isLoading = false;
      });

      // Force a rebuild right now
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // This empty setState forces another rebuild to ensure initials show
          });
        }
      });

      // Load new image in the background
      _loadImage(forceRefresh: true);
    }
  }

  Future<void> _loadImage({bool forceRefresh = false}) async {
    // Handle null or empty image
    if (widget.base64Image == null || widget.base64Image!.isEmpty) {
      if (mounted) {
        setState(() {
          _cachedBytes = null;
          _showInitials = true;
          _isLoading = false;
        });
      }
      return;
    }

    final currentHash = widget.base64Image!.hashCode.toString();

    // If we're already showing this hash and have bytes, just show image
    if (!forceRefresh &&
        _currentBase64Hash == currentHash &&
        _cachedBytes != null) {
      if (mounted) {
        setState(() {
          _showInitials = false;
        });
      }
      return;
    }

    // Prevent multiple simultaneous loads
    if (_isLoading) {
      debugPrint('CachedAvatar: Already loading for user ${widget.uniqueId}');
      return;
    }

    _isLoading = true;

    try {
      debugPrint('CachedAvatar: Decoding image for user ${widget.uniqueId}');
      final bytes = base64Decode(widget.base64Image!);

      debugPrint(
          'CachedAvatar: Successfully decoded image for user ${widget.uniqueId}, size: ${bytes.length} bytes');

      if (mounted) {
        setState(() {
          _cachedBytes = bytes;
          _showInitials = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
          'CachedAvatar: Error loading image for user ${widget.uniqueId}: $e');
      if (mounted) {
        setState(() {
          _cachedBytes = null;
          _showInitials = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ALWAYS show initials when _showInitials is true, regardless of _cachedBytes
    if (_showInitials) {
      return _buildInitialsAvatar();
    }

    // Show image if we have cached bytes
    if (_cachedBytes != null) {
      return ClipOval(
        child: Image.memory(
          _cachedBytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          cacheWidth: widget.highQuality ? null : widget.size.toInt(),
          cacheHeight: widget.highQuality ? null : widget.size.toInt(),
          gaplessPlayback: true,
          filterQuality:
              widget.highQuality ? FilterQuality.high : FilterQuality.medium,
          key: ValueKey(
              'avatar_image_${widget.uniqueId}_${_currentBase64Hash}_${widget.highQuality}'),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
                'CachedAvatar: Error displaying image for user ${widget.uniqueId}: $error');
            return _buildInitialsAvatar();
          },
        ),
      );
    }

    // Default to initials
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    // Generate a consistent color based on the user's name
    final color = _getColorFromName(widget.name);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: widget.textColor ?? color,
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getColorFromName(String name) {
    if (name.isEmpty) return Colors.blue;

    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
    ];

    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  void dispose() {
    _cachedBytes = null;
    super.dispose();
  }
}
