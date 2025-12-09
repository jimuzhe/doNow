import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../data/models/task.dart';
import '../../data/localization.dart';
import '../../data/providers.dart';
import '../../utils/haptic_helper.dart';
import '../../data/services/sound_effect_service.dart';
import '../../data/services/camera_service.dart';
import '../screens/camera_screen.dart'; // Custom camera UI
import 'video_player_dialog.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class TaskCompletionSheet extends ConsumerStatefulWidget {
  final Task task;
  final Duration actualDuration;

  const TaskCompletionSheet({
    super.key,
    required this.task,
    required this.actualDuration,
  });

  @override
  ConsumerState<TaskCompletionSheet> createState() => _TaskCompletionSheetState();
}

class _TaskCompletionSheetState extends ConsumerState<TaskCompletionSheet> 
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();
  String? _imagePath;
  String? _videoPath;
  String? _location;
  bool _isLocating = false;
  bool _showRecordOptions = false;
  bool _isRecordingVideo = false;
  bool _showNoteInput = false;
  bool _isGeneratingThumbnail = false; // Track thumbnail generation
  
  late AnimationController _checkAnimController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.easeOutBack,
    );
    
    // Play sound and start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundEffectServiceProvider).playSuccess();
      _checkAnimController.forward();
      
      // Auto-fetch location by default
      _fetchLocationOnStart();
      
      // Pre-warm camera in background for instant camera open
      if (!kIsWeb) {
        CameraService().prewarm();
      }
    });
  }

  
  // Auto-fetch location when sheet opens
  Future<void> _fetchLocationOnStart() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        return; // Don't show error, just skip
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      String addressText = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude, 
            position.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final List<String> addressParts = [];
            
            if (p.street != null && p.street!.isNotEmpty && p.street != p.name) {
              addressParts.add(p.street!);
            }
            if (p.name != null && p.name!.isNotEmpty && !addressParts.contains(p.name)) {
              if (!RegExp(r'^\d+$').hasMatch(p.name!)) {
                addressParts.add(p.name!);
              }
            }
            if (p.subLocality != null && p.subLocality!.isNotEmpty) {
              if (!addressParts.contains(p.subLocality)) {
                addressParts.add(p.subLocality!);
              }
            }
            if (p.locality != null && p.locality!.isNotEmpty) {
              if (!addressParts.contains(p.locality)) {
                addressParts.add(p.locality!);
              }
            }
            
            if (addressParts.isNotEmpty) {
              addressText = addressParts.take(3).join(", ");
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _location = addressText);
      }
    } catch (_) {
      // Silently ignore errors on auto-fetch
    }
  }

  @override
  void dispose() {
    _checkAnimController.dispose();
    _noteController.dispose();
    // Release prewarmed camera if not used
    CameraService().release();
    super.dispose();
  }

  Future<void> _generateThumbnail(String videoPath) async {
    // Web platform: VideoThumbnail doesn't work, just mark as not generating
    // The UI will show a video icon placeholder instead
    if (kIsWeb) {
      // On web, we can't generate thumbnails, so leave _imagePath as null
      // The UI will handle this by showing a video icon
      return;
    }
    
    setState(() => _isGeneratingThumbnail = true);
    
    try {
      final fileName = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 1080,
        maxHeight: 1920,
        quality: 85,
      );
      if (fileName != null && mounted) {
        setState(() {
          _imagePath = fileName;
          _isGeneratingThumbnail = false;
        });
      } else {
        if (mounted) setState(() => _isGeneratingThumbnail = false);
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      if (mounted) setState(() => _isGeneratingThumbnail = false);
    }
  }

  // Calculate time difference info
  Map<String, dynamic> _getTimeDiffInfo() {
    final planned = widget.task.totalDuration.inMinutes;
    final actual = widget.actualDuration.inMinutes;
    final diff = actual - planned;
    
    if (diff > 0) {
      return {
        'text': '+$diff min',
        'label': 'slower',
        'color': Colors.orange,
      };
    } else if (diff < 0) {
      return {
        'text': '-${diff.abs()} min',
        'label': 'faster',
        'color': Colors.green,
      };
    } else {
      return {
        'text': 'Perfect!',
        'label': 'on time',
        'color': Colors.blue,
      };
    }
  }

  // Open custom camera screen
  Future<void> _openCustomCamera() async {
    HapticHelper(ref).selectionClick();
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
    
    if (result != null && result is Map) {
      final path = result['path'];
      final type = result['type'];
      final thumbnail = result['thumbnail']; // Pre-generated thumbnail from camera
      
      if (path != null) {
        setState(() {
          if (type == 'video') {
            _videoPath = path;
            // Use pre-generated thumbnail if available
            _imagePath = thumbnail;
          } else {
            _imagePath = path;
            _videoPath = null;
          }
        });
        
        // Only generate thumbnail if not provided (fallback)
        if (type == 'video' && thumbnail == null) {
          _generateThumbnail(path as String);
        }
      }
    }
  }

  // Deprecated direct methods, redirecting to custom camera
  Future<void> _takePhoto() async => _openCustomCamera();
  Future<void> _recordVideo() async => _openCustomCamera();

  // Pick from gallery (image or video)
  Future<void> _pickFromGallery() async {
    HapticHelper(ref).selectionClick();
    
    // Show choice dialog
    final locale = ref.read(localeProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: Text(AppStrings.get('pick_photo', locale)),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: Text(AppStrings.get('pick_video', locale)),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    
    if (choice == 'photo') {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imagePath = image.path;
          _videoPath = null;
        });
      }
    } else if (choice == 'video') {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _videoPath = video.path;
          _imagePath = null;
        });
        _generateThumbnail(video.path);
      }
    }
  }

  Future<void> _toggleLocation() async {
    HapticHelper(ref).selectionClick();
    
    if (_location != null) {
      setState(() => _location = null);
      return;
    }

    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission denied");
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError("Location permissions are permanently denied.");
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // Default to coordinates if geocoding fails
      String addressText = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      
      // Try to get human-readable address (not supported on web)
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude, 
            position.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            
            // Build detailed address with multiple components
            // Priority: Street -> SubLocality -> Locality -> SubAdministrativeArea -> AdministrativeArea
            final List<String> addressParts = [];
            
            // Street name (most specific)
            if (p.street != null && p.street!.isNotEmpty && p.street != p.name) {
              addressParts.add(p.street!);
            }
            
            // Name/POI
            if (p.name != null && p.name!.isNotEmpty && !addressParts.contains(p.name)) {
              // Only add if it's not just a number (street number)
              if (!RegExp(r'^\d+$').hasMatch(p.name!)) {
                addressParts.add(p.name!);
              }
            }
            
            // SubLocality (neighborhood/district)
            if (p.subLocality != null && p.subLocality!.isNotEmpty) {
              if (!addressParts.contains(p.subLocality)) {
                addressParts.add(p.subLocality!);
              }
            }
            
            // Locality (city)
            if (p.locality != null && p.locality!.isNotEmpty) {
              if (!addressParts.contains(p.locality)) {
                addressParts.add(p.locality!);
              }
            }
            
            // SubAdministrativeArea (county/prefecture)
            if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) {
              if (!addressParts.contains(p.subAdministrativeArea)) {
                addressParts.add(p.subAdministrativeArea!);
              }
            }
            
            // Construct final address
            if (addressParts.isNotEmpty) {
              // Limit to 3 most relevant parts for cleaner display
              addressText = addressParts.take(3).join(", ");
            }
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
          // Keep the coordinates as fallback
        }
      }

      setState(() => _location = addressText);
      HapticHelper(ref).mediumImpact();
    } catch (e) {
      _showError("Could not get location: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _onAddRecord() {
    HapticHelper(ref).mediumImpact();
    setState(() => _showRecordOptions = true);
  }

  void _onSaveWithRecord() {
    HapticHelper(ref).heavyImpact();
    
    final repo = ref.read(taskRepositoryProvider);
    final completedTask = widget.task.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
      actualDuration: widget.actualDuration,
      journalImagePath: _imagePath,
      journalVideoPath: _videoPath,
      journalLocation: _location,
      journalNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );
    repo.updateTask(completedTask);
    
    Navigator.of(context).pop(true);
  }

  void _onSkip() {
    HapticHelper(ref).mediumImpact();
    final repo = ref.read(taskRepositoryProvider);
    final completedTask = widget.task.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
      actualDuration: widget.actualDuration,
    );
    repo.updateTask(completedTask);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String key) => AppStrings.get(key, locale);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black;
    final timeDiff = _getTimeDiffInfo();

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Checkmark Animation
          AnimatedBuilder(
            animation: _checkAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _checkAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: Colors.green,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Task Title
          Text(
            widget.task.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: txtColor,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Time Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Planned
                _TimeStatItem(
                  label: locale == 'zh' ? '计划' : 'Planned',
                  value: '${widget.task.totalDuration.inMinutes}m',
                  isDark: isDark,
                ),
                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                // Actual
                _TimeStatItem(
                  label: locale == 'zh' ? '实际' : 'Actual',
                  value: '${widget.actualDuration.inMinutes}m',
                  isDark: isDark,
                ),
                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                // Difference
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (timeDiff['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeDiff['text'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: timeDiff['color'] as Color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeDiff['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Record Options (expandable)
          if (_showRecordOptions) ...[
            // Media Preview
            if (_imagePath != null || _videoPath != null)
              GestureDetector(
                onTap: () {
                  if (_videoPath != null) {
                    showDialog(
                      context: context, 
                      builder: (_) => VideoPlayerDialog(videoPath: _videoPath!)
                    );
                  }
                },
                child: Container(
                  height: 240,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black,
                  ),
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Thumbnail or loading indicator or web placeholder
                      if (_imagePath != null)
                        Positioned.fill(
                          child: kIsWeb
                              ? Image.network(_imagePath!, fit: BoxFit.cover)
                              : Image.file(File(_imagePath!), fit: BoxFit.cover),
                        )
                      else if (_isGeneratingThumbnail)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white54),
                        )
                      else if (_videoPath != null)
                        // Web fallback: show video icon when no thumbnail available
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam, size: 48, color: Colors.white.withOpacity(0.5)),
                              const SizedBox(height: 8),
                              Text(
                                kIsWeb ? 'Video selected' : 'Loading...',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      
                      // Video play button
                      if (_videoPath != null && !_isGeneratingThumbnail && _imagePath != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _imagePath = null;
                              _videoPath = null;
                            });
                            HapticHelper(ref).mediumImpact();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      // Video duration badge
                      if (_videoPath != null)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '≤10s',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // Three buttons: Capture (photo/video), Gallery, Location
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Capture button (tap=photo, long press=video)
                _CaptureButton(
                  onTap: _takePhoto,
                  onLongPress: _recordVideo,
                  isRecording: _isRecordingVideo,
                  isDark: isDark,
                  locale: locale,
                ),
                // Gallery button
                _CompactActionButton(
                  icon: Icons.photo_library,
                  label: locale == 'zh' ? '相册' : 'Gallery',
                  onTap: _pickFromGallery,
                  isDark: isDark,
                ),
                // Location button
                _CompactActionButton(
                  icon: _location != null ? Icons.location_on : Icons.location_off,
                  label: locale == 'zh' ? (_location != null ? '已定位' : '位置') : (_location != null ? 'On' : 'Location'),
                  onTap: _toggleLocation,
                  isDark: isDark,
                  isActive: _location != null,
                  isLoading: _isLocating,
                ),
                // Note button
                _CompactActionButton(
                  icon: _noteController.text.isNotEmpty ? Icons.edit_note : Icons.notes,
                  label: locale == 'zh' ? '文字' : 'Note',
                  onTap: () => setState(() => _showNoteInput = !_showNoteInput),
                  isDark: isDark,
                  isActive: _noteController.text.isNotEmpty,
                ),
              ],
            ),

            // Note input field
            if (_showNoteInput)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: locale == 'zh' ? '写点什么...' : 'Write something...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    counterStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  ),
                  style: TextStyle(color: txtColor, fontSize: 14),
                  onChanged: (_) => setState(() {}),
                ),
              ),

            // Location display
            if (_location != null && !_showNoteInput)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 12, color: txtColor.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _location!,
                        style: TextStyle(color: txtColor.withOpacity(0.6), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSaveWithRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t('journal_save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ] else ...[
            // Initial buttons: Add Record / Skip
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white54 : Colors.grey[600],
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(t('journal_skip'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _onAddRecord,
                    icon: const Icon(Icons.add_photo_alternate, size: 20),
                    label: Text(t('journal_add_record'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
        ],
        ),
      ),
    );
  }
}

class _TimeStatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _TimeStatItem({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// Capture button: tap for photo, long press for video
class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isRecording;
  final bool isDark;
  final String locale;

  const _CaptureButton({
    required this.onTap,
    required this.onLongPress,
    required this.isRecording,
    required this.isDark,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isRecording 
                  ? Colors.red 
                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRecording ? Icons.stop : Icons.camera_alt,
              color: isRecording ? Colors.white : (isDark ? Colors.white : Colors.black87),
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            locale == 'zh' ? '拍摄' : 'Capture',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isActive;
  final bool isLoading;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isActive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isActive
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white : Colors.black87),
                    size: 22,
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
