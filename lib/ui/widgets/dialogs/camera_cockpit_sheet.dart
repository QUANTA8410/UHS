import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/real_iot_controller.dart';
import '../../../theme/apple_glass_theme.dart';

class CameraCockpitSheet extends StatefulWidget {
  final RealSmartDevice device;
  final RealIotController iot;
  final VoidCallback onStateChanged;

  const CameraCockpitSheet({
    super.key,
    required this.device,
    required this.iot,
    required this.onStateChanged,
  });

  @override
  State<CameraCockpitSheet> createState() => _CameraCockpitSheetState();
}

class _CameraCockpitSheetState extends State<CameraCockpitSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  String? _ptzStatus;

  Player? _player;
  VideoController? _videoController;

  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isMuted = true;
  bool _useSubStream = false;
  String? _playerError;
  String? _streamTelemetry;

  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _videoParamsSub;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _initRtsPlayer();
  }

  void _initRtsPlayer() {
    try {
      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 2 * 1024 * 1024,
          protocolWhitelist: [
            'rtsp',
            'rtp',
            'tcp',
            'udp',
            'tls',
            'data',
            'file',
            'http',
            'https',
            'crypto',
          ],
        ),
      );

      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      _player = player;
      _videoController = controller;

      _playingSub = player.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlaying = playing);
      });

      _bufferingSub = player.stream.buffering.listen((buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      });

      _errorSub = player.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          setState(() => _playerError = error);
        }
      });

      _videoParamsSub = player.stream.videoParams.listen((params) {
        if (mounted && params.w != null && params.h != null) {
          setState(() {
            _streamTelemetry = '${params.w}x${params.h} • 30 FPS • H.264';
          });
        }
      });

      _startStreamPlayback();
    } catch (e) {
      debugPrint('RTSP player initialization note: $e');
    }
  }

  String _getActiveStreamUrl() {
    final rtspUrl = widget.device.credentials['rtspUrl'] ?? '';
    if (rtspUrl.isEmpty) return '';

    if (_useSubStream) {
      final sub = widget.device.credentials['subStreamUrl'] ??
          widget.device.credentials['rtspSubUrl'];
      if (sub != null && sub.toString().isNotEmpty) {
        return sub.toString();
      }
      if (rtspUrl.contains('/stream1')) {
        return rtspUrl.replaceAll('/stream1', '/stream2');
      } else if (rtspUrl.contains('/ch0')) {
        return rtspUrl.replaceAll('/ch0', '/ch1');
      } else if (rtspUrl.contains('/live/0')) {
        return rtspUrl.replaceAll('/live/0', '/live/1');
      } else if (rtspUrl.contains('/onvif1')) {
        return rtspUrl.replaceAll('/onvif1', '/onvif2');
      } else if (rtspUrl.contains('/h264Preview_01_main')) {
        return rtspUrl.replaceAll('/h264Preview_01_main', '/h264Preview_01_sub');
      }
    }
    return rtspUrl;
  }

  Future<void> _startStreamPlayback() async {
    final isPrivacy = !widget.device.isOn;
    if (_player == null || isPrivacy || !widget.device.isOnline) {
      try {
        await _player?.stop();
      } catch (_) {}
      return;
    }

    final url = _getActiveStreamUrl();
    if (url.isEmpty) return;

    try {
      await _player?.setVolume(_isMuted ? 0.0 : 100.0);
      await _player?.open(Media(url));
    } catch (e) {
      if (mounted) setState(() => _playerError = '$e');
    }
  }

  Future<void> _toggleStreamProfile() async {
    HapticFeedback.lightImpact();
    setState(() {
      _useSubStream = !_useSubStream;
      _playerError = null;
      _streamTelemetry = _useSubStream
          ? '640x360 • 15 FPS • 512 Kbps'
          : '1080P • 30 FPS • 2.4 Mbps • H.264';
    });
    await _startStreamPlayback();
  }

  Future<void> _toggleAudioMute() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });
    try {
      await _player?.setVolume(_isMuted ? 0.0 : 100.0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scanController.dispose();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _videoParamsSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _handlePtz(String direction) async {
    HapticFeedback.mediumImpact();
    setState(() => _ptzStatus = 'Moving ${direction.toUpperCase()}...');
    try {
      await widget.iot.sendCameraPtzCommand(widget.device, direction);
      widget.onStateChanged();
      if (mounted) {
        setState(() {
          final pan = (widget.device.liveAttributes['panAngle'] as num?)?.toDouble() ?? 0.0;
          final tilt = (widget.device.liveAttributes['tiltAngle'] as num?)?.toDouble() ?? 0.0;
          _ptzStatus = 'Pan: ${pan.round()}° • Tilt: ${tilt.round()}°';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _ptzStatus = 'PTZ Error: $e');
      }
    }
  }

  Future<void> _launchStream() async {
    final rtspUrl = _getActiveStreamUrl();
    if (rtspUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No RTSP stream URL configured for this camera.')),
      );
      return;
    }

    HapticFeedback.selectionClick();
    final uri = Uri.parse(rtspUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch external player for $rtspUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stream player error: $e')),
        );
      }
    }
  }

  Future<void> _toggleHardwareFeature(String featureKey) async {
    HapticFeedback.lightImpact();
    final attrs = Map<String, dynamic>.from(widget.device.liveAttributes);

    if (featureKey == 'privacyMask') {
      final currentPrivacy = !widget.device.isOn;
      final targetPrivacy = !currentPrivacy;
      widget.device.isOn = !targetPrivacy;
      attrs['privacyMode'] = targetPrivacy;
      widget.device.liveAttributes = attrs;
      widget.iot.computeDeviceLiveWattage(widget.device);
      try {
        await widget.iot.setPower(widget.device, !targetPrivacy);
      } catch (_) {}
      await _startStreamPlayback();
    } else {
      final current = attrs[featureKey] == true;
      attrs[featureKey] = !current;
      widget.device.liveAttributes = attrs;
    }

    widget.onStateChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final isOnline = device.isOnline;
    final isPrivacy = !device.isOn;
    final attrs = device.liveAttributes;
    final rtspUrl = _getActiveStreamUrl();
    final brand = device.credentials['brand']?.toString().toUpperCase() ?? 'SMART CAM';

    final pan = (attrs['panAngle'] as num?)?.toDouble() ?? 0.0;
    final tilt = (attrs['tiltAngle'] as num?)?.toDouble() ?? 0.0;

    final nightVision = attrs['nightVision'] == true;
    final motionTrack = attrs['motionTrack'] == true || attrs['motionTracking'] == true;
    final patrol360 = attrs['patrol360'] == true;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF070B18),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 40, spreadRadius: 10),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pull Indicator
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isPrivacy
                        ? const Color(0xFFFF9F0A).withValues(alpha: 0.25)
                        : const Color(0xFFFF453A).withValues(alpha: 0.25),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: isPrivacy ? const Color(0xFFFF9F0A) : const Color(0xFFFF453A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$brand • ${device.room} • ${device.liveWatts.toStringAsFixed(1)} W',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Live 16:9 Viewfinder Window
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isPrivacy
                          ? const Color(0xFFFF9F0A).withValues(alpha: 0.5)
                          : const Color(0xFF30D158).withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPrivacy
                            ? const Color(0xFFFF9F0A).withValues(alpha: 0.15)
                            : const Color(0xFF30D158).withValues(alpha: 0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Hardware-accelerated Video Stream
                        if (!isPrivacy && _videoController != null && _isPlaying && _playerError == null)
                          Positioned.fill(
                            child: Video(
                              controller: _videoController!,
                              controls: NoVideoControls,
                              fit: BoxFit.cover,
                              fill: Colors.black,
                            ),
                          ),

                        // Animated scanning reticle & corner bracket painter
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _scanController,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: _CockpitReticlePainter(
                                  scanProgress: _scanController.value,
                                  isPrivacy: isPrivacy,
                                  hasLiveVideo: !isPrivacy && _isPlaying && _playerError == null,
                                ),
                              );
                            },
                          ),
                        ),

                        if (isPrivacy)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFF9F0A), width: 1.1),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.privacy_tip_rounded, color: Color(0xFFFF9F0A), size: 32),
                                  SizedBox(height: 6),
                                  Text(
                                    'Privacy Mask Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Hardware Sensor Powered Down (2.0 W)',
                                    style: TextStyle(color: Colors.white60, fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          // Center loading / buffering / crosshair indicator
                          if (_isBuffering)
                            const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00D4FF),
                              ),
                            )
                          else if (!_isPlaying)
                            Center(
                              child: Icon(
                                Icons.center_focus_weak_rounded,
                                color: Colors.white.withValues(alpha: 0.35),
                                size: 44,
                              ),
                            ),

                          // HUD Overlay Top Bar
                          Positioned(
                            top: 10,
                            left: 12,
                            right: 12,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // LIVE RTSP Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF453A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(radius: 3, backgroundColor: Colors.white),
                                      SizedBox(width: 5),
                                      Text(
                                        'LIVE RTSP',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Top Right HUD Action Controls
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Main HD vs Sub-Stream Toggle Pill
                                    InkWell(
                                      onTap: _toggleStreamProfile,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _useSubStream
                                                ? const Color(0xFFFF9F0A)
                                                : const Color(0xFF00D4FF),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _useSubStream ? Icons.sd_rounded : Icons.hd_rounded,
                                              size: 13,
                                              color: _useSubStream
                                                  ? const Color(0xFFFF9F0A)
                                                  : const Color(0xFF00D4FF),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _useSubStream ? 'SUB' : 'MAIN HD',
                                              style: TextStyle(
                                                color: _useSubStream
                                                    ? const Color(0xFFFF9F0A)
                                                    : const Color(0xFF00D4FF),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Audio Mute/Unmute Pill
                                    InkWell(
                                      onTap: _toggleAudioMute,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _isMuted ? Colors.white24 : const Color(0xFF30D158),
                                          ),
                                        ),
                                        child: Icon(
                                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                          size: 13,
                                          color: _isMuted ? Colors.white60 : const Color(0xFF30D158),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Resolution / FPS Telemetry Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Text(
                                        _streamTelemetry ??
                                            (_useSubStream
                                                ? '640x360 • 15 FPS • 512 Kbps'
                                                : '1080P • 30 FPS • 2.4 Mbps • H.264'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Bottom HUD status
                          Positioned(
                            bottom: 10,
                            left: 12,
                            right: 12,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$brand • PAN ${pan.round()}° / TILT ${tilt.round()}°',
                                  style: const TextStyle(
                                    color: Color(0xFF00D4FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (motionTrack)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFBF5AF2).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBF5AF2)),
                                    ),
                                    child: const Text(
                                      'AI TRACK',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Launch Fullscreen Hardware Stream Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  label: const Text(
                    'Launch Fullscreen Hardware Stream',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onPressed: !isOnline || isPrivacy || rtspUrl.isEmpty ? null : _launchStream,
                ),
              ),
              const SizedBox(height: 18),

              // 5. 360° PTZ Gimbal Joystick Pad
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.threed_rotation_rounded, color: Color(0xFFFFB800), size: 18),
                            SizedBox(width: 8),
                            Text(
                              '360° PTZ Gimbal Pad',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _ptzStatus ?? 'Pan: ${pan.round()}° • Tilt: ${tilt.round()}°',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00D4FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Directional Gimbal Controls
                    Column(
                      children: [
                        _buildGimbalButton(Icons.arrow_upward_rounded, 'up', isOnline && !isPrivacy),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGimbalButton(Icons.arrow_back_rounded, 'left', isOnline && !isPrivacy),
                            const SizedBox(width: 14),
                            _buildGimbalButton(
                              Icons.filter_center_focus_rounded,
                              'center',
                              isOnline && !isPrivacy,
                              isCenter: true,
                            ),
                            const SizedBox(width: 14),
                            _buildGimbalButton(Icons.arrow_forward_rounded, 'right', isOnline && !isPrivacy),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildGimbalButton(Icons.arrow_downward_rounded, 'down', isOnline && !isPrivacy),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 6. 4 Apple Glass Hardware Toggle Pills
              const Text(
                'Hardware Features',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTogglePill(
                      label: 'Night Vision (IR)',
                      icon: Icons.nights_stay_rounded,
                      isActive: nightVision,
                      activeColor: const Color(0xFF30D158),
                      onTap: () => _toggleHardwareFeature('nightVision'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTogglePill(
                      label: 'AI Motion Track',
                      icon: Icons.person_search_rounded,
                      isActive: motionTrack,
                      activeColor: const Color(0xFFBF5AF2),
                      onTap: () => _toggleHardwareFeature('motionTrack'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTogglePill(
                      label: '360° Patrol',
                      icon: Icons.rotate_right_rounded,
                      isActive: patrol360,
                      activeColor: const Color(0xFF00D4FF),
                      onTap: () => _toggleHardwareFeature('patrol360'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTogglePill(
                      label: 'Privacy Mask',
                      icon: Icons.privacy_tip_rounded,
                      isActive: isPrivacy,
                      activeColor: const Color(0xFFFF9F0A),
                      onTap: () => _toggleHardwareFeature('privacyMask'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGimbalButton(
    IconData icon,
    String dir,
    bool enabled, {
    bool isCenter = false,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isCenter
            ? const Color(0xFFFFB800).withValues(alpha: enabled ? 0.25 : 0.08)
            : Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCenter
              ? const Color(0xFFFFB800).withValues(alpha: enabled ? 0.7 : 0.2)
              : Colors.white.withValues(alpha: enabled ? 0.25 : 0.08),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          color: isCenter
              ? (enabled ? const Color(0xFFFFB800) : Colors.white30)
              : (enabled ? Colors.white : Colors.white30),
          size: isCenter ? 22 : 20,
        ),
        onPressed: enabled ? () => _handlePtz(dir) : null,
      ),
    );
  }

  Widget _buildTogglePill({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isActive: isActive,
      activeTint: activeColor,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: isActive ? activeColor : Colors.white60),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CockpitReticlePainter extends CustomPainter {
  final double scanProgress;
  final bool isPrivacy;
  final bool hasLiveVideo;

  const _CockpitReticlePainter({
    required this.scanProgress,
    required this.isPrivacy,
    this.hasLiveVideo = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isPrivacy) return;

    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: hasLiveVideo ? 0.4 : 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Viewfinder Corner Brackets
    const corner = 18.0;
    const pad = 14.0;

    // Top-Left
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + corner, pad), bracketPaint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + corner), bracketPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - corner, pad), bracketPaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + corner), bracketPaint);

    // Bottom-Left
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + corner, size.height - pad), bracketPaint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - corner), bracketPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - corner, size.height - pad), bracketPaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - corner), bracketPaint);

    // Scanning Line (only when not showing live video to avoid visual distraction)
    if (!hasLiveVideo) {
      final scanY = pad + (size.height - (pad * 2)) * scanProgress;
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF00D4FF).withValues(alpha: 0.4),
            const Color(0xFF00D4FF).withValues(alpha: 0.8),
            const Color(0xFF00D4FF).withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, scanY, size.width, 2.0))
        ..strokeWidth = 1.5;

      canvas.drawLine(Offset(pad, scanY), Offset(size.width - pad, scanY), scanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CockpitReticlePainter oldDelegate) =>
      oldDelegate.scanProgress != scanProgress ||
      oldDelegate.isPrivacy != isPrivacy ||
      oldDelegate.hasLiveVideo != hasLiveVideo;
}
