import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/youtube_importer_service.dart';
import '../theme/ember_theme.dart';

class SineQrScannerScreen extends StatefulWidget {
  const SineQrScannerScreen({super.key});

  @override
  State<SineQrScannerScreen> createState() => _SineQrScannerScreenState();
}

class _SineQrScannerScreenState extends State<SineQrScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanLineAnim;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );

    _scanLineAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    _processCode(code.trim());
  }

  Future<void> _processCode(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    final player = context.read<PlayerProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Sine Scannable URI: sine://track?id=...&title=...&artist=...
      if (rawCode.startsWith('sine://track')) {
        final uri = Uri.parse(rawCode);
        final id = uri.queryParameters['id'] ?? '';
        final title = uri.queryParameters['title'] ?? 'Unknown Track';
        final artist = uri.queryParameters['artist'] ?? 'Unknown Artist';

        if (id.isNotEmpty) {
          final song = Song(
            id: id,
            title: title,
            artist: artist,
            duration: const Duration(minutes: 3, seconds: 30),
            artworkUrl: 'https://img.youtube.com/vi/${id.replaceFirst('yt_', '')}/hqdefault.jpg',
            streamUrl: 'https://www.youtube.com/watch?v=${id.replaceFirst('yt_', '')}',
          );

          if (mounted) Navigator.of(context).pop();
          await player.playSong(song);
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: EmberColors.surfaceContainerHigh,
              content: Text('Playing "$title" from scanned Sine Code!', style: const TextStyle(color: EmberColors.primaryBlueHi)),
            ),
          );
          return;
        }
      }

      // 2. YouTube URL or Video ID
      final videoId = YouTubeImporterService.extractVideoId(rawCode);
      if (videoId != null && videoId.isNotEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Resolving YouTube link...'),
            duration: Duration(seconds: 1),
          ),
        );

        final importResult = await YouTubeImporterService.importFromUrl(rawCode);
        if (importResult.song != null) {
          final resolvedSong = importResult.song!;
          if (mounted) Navigator.of(context).pop();
          await player.playSong(resolvedSong);
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: EmberColors.surfaceContainerHigh,
              content: Text('Playing "${resolvedSong.title}" from QR code!', style: const TextStyle(color: EmberColors.primaryBlueHi)),
            ),
          );
          return;
        }
      }

      // 3. Fallback: Search text query
      if (mounted) Navigator.of(context).pop(rawCode);
    } catch (e) {
      debugPrint('[SineQrScanner] Scan error: $e');
      setState(() => _isProcessing = false);
    }
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmberColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Code or Link', style: TextStyle(color: EmberColors.textPrimary)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: EmberColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste YouTube link or Sine Code...',
            hintStyle: const TextStyle(color: EmberColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EmberColors.primaryBlue),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (textController.text.trim().isNotEmpty) {
                _processCode(textController.text.trim());
              }
            },
            child: const Text('Open', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan Sine Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.bolt, color: Colors.white, size: 18),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.cameraRotate, color: Colors.white, size: 18),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // Dark Viewfinder Vignette Overlay
          LayoutBuilder(
            builder: (context, constraints) {
              const boxSize = 250.0;
              final left = (constraints.maxWidth - boxSize) / 2;
              final top = (constraints.maxHeight - boxSize) / 2 - 40;

              return Stack(
                children: [
                  // Viewfinder Frame
                  Positioned(
                    left: left,
                    top: top,
                    width: boxSize,
                    height: boxSize,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: EmberColors.primaryBlue, width: 2.5),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: EmberColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Animated Scanning Laser
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (context, child) {
                      return Positioned(
                        left: left + 10,
                        top: top + 10 + (_scanLineAnim.value * (boxSize - 20)),
                        width: boxSize - 20,
                        height: 2.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                EmberColors.secondaryCyan,
                                EmberColors.primaryBlue,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: EmberColors.secondaryCyan.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Helper Instruction Text
                  Positioned(
                    top: top + boxSize + 28,
                    left: 20,
                    right: 20,
                    child: const Text(
                      'Point camera at a Sine Code or YouTube QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Bottom Manual Link Button
          Positioned(
            bottom: 36,
            left: 32,
            right: 32,
            child: ElevatedButton.icon(
              onPressed: _showManualInputDialog,
              icon: const FaIcon(FontAwesomeIcons.keyboard, size: 14, color: Colors.white),
              label: const Text('Paste Link or Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: EmberColors.surfaceContainerLow.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: EmberColors.outlineVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
