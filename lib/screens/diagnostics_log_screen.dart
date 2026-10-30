import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/log_service.dart';
import '../theme/ember_theme.dart';

class DiagnosticsLogScreen extends StatefulWidget {
  const DiagnosticsLogScreen({super.key});

  @override
  State<DiagnosticsLogScreen> createState() => _DiagnosticsLogScreenState();
}

class _DiagnosticsLogScreenState extends State<DiagnosticsLogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _testQueryController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  LogLevel? _selectedFilter;
  bool _isTestingStream = false;
  StreamTestResult? _testResult;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Pre-populate tester with active track ID or Rick Astley test ID
    final activeId = LogService.instance.activeSongId;
    _testQueryController.text = activeId.isNotEmpty ? activeId : 'dQw4w9WgXcQ';

    LogService.instance.addListener(_handleLogsChanged);
  }

  void _handleLogsChanged() {
    if (_autoScroll && _logScrollController.hasClients && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients && mounted) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    LogService.instance.removeListener(_handleLogsChanged);
    _tabController.dispose();
    _testQueryController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _copyReport() async {
    try {
      await LogService.instance.copyReportToClipboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: EmberColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              FaIcon(FontAwesomeIcons.circleCheck, color: EmberColors.primaryAmber, size: 16),
              SizedBox(width: 10),
              Text(
                'Diagnostic report copied to clipboard!',
                style: TextStyle(color: EmberColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: EmberColors.error,
          content: Text('Failed to copy: $e'),
        ),
      );
    }
  }

  void _runStreamTest() async {
    final query = _testQueryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isTestingStream = true;
      _testResult = null;
    });

    try {
      final res = await LogService.instance.runExtractionTest(query);

      if (mounted) {
        setState(() {
          _isTestingStream = false;
          _testResult = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingStream = false;
        });
      }
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return const Color(0xFFFF5252);
      case LogLevel.warning:
        return EmberColors.primaryAmber;
      case LogLevel.stream:
        return const Color(0xFF00E5FF);
      case LogLevel.exoplayer:
        return const Color(0xFFB388FF);
      case LogLevel.info:
        return const Color(0xFF69F0AE);
      case LogLevel.debug:
        return EmberColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      appBar: AppBar(
        backgroundColor: EmberColors.obsidianBase,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18, color: EmberColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diagnostics & Log Extractor',
              style: TextStyle(
                color: EmberColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'ExoPlayer Telemetry & Stream Traces',
              style: TextStyle(
                color: EmberColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Markdown Report',
            icon: const FaIcon(FontAwesomeIcons.copy, size: 16, color: EmberColors.primaryAmber),
            onPressed: _copyReport,
          ),
          IconButton(
            tooltip: 'Clear Logs',
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: EmberColors.textMuted),
            onPressed: () {
              LogService.instance.clearLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Diagnostic logs cleared.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: EmberColors.primaryAmber,
          labelColor: EmberColors.primaryAmber,
          unselectedLabelColor: EmberColors.textMuted,
          tabs: const [
            Tab(icon: FaIcon(FontAwesomeIcons.terminal, size: 14), text: 'Logs'),
            Tab(icon: FaIcon(FontAwesomeIcons.circleInfo, size: 14), text: 'Playback'),
            Tab(icon: FaIcon(FontAwesomeIcons.vial, size: 14), text: 'Stream Tester'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogsTab(),
          _buildPlaybackTab(),
          _buildTesterTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: REAL-TIME LOGCAT & EXTRACTOR TRACE
  // ==========================================
  Widget _buildLogsTab() {
    return AnimatedBuilder(
      animation: LogService.instance,
      builder: (context, _) {
        final allLogs = LogService.instance.logs;
        final filteredLogs = _selectedFilter == null
            ? allLogs
            : allLogs.where((l) => l.level == _selectedFilter).toList();

        return Column(
          children: [
            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All (${allLogs.length})', null),
                  const SizedBox(width: 6),
                  _buildFilterChip('Errors', LogLevel.error),
                  const SizedBox(width: 6),
                  _buildFilterChip('Streams', LogLevel.stream),
                  const SizedBox(width: 6),
                  _buildFilterChip('ExoPlayer', LogLevel.exoplayer),
                  const SizedBox(width: 6),
                  _buildFilterChip('Info', LogLevel.info),
                  const SizedBox(width: 12),
                  // Auto scroll toggle
                  InkWell(
                    onTap: () => setState(() => _autoScroll = !_autoScroll),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _autoScroll
                            ? EmberColors.primaryAmber.withValues(alpha: 0.2)
                            : EmberColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _autoScroll ? EmberColors.primaryAmber : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.arrowDown,
                            size: 10,
                            color: _autoScroll ? EmberColors.primaryAmber : EmberColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Auto-scroll',
                            style: TextStyle(
                              fontSize: 11,
                              color: _autoScroll ? EmberColors.primaryAmber : EmberColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Log List
            Expanded(
              child: filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.fileLines, size: 36, color: EmberColors.textMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'No logs recorded yet.',
                            style: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _logScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        final entry = filteredLogs[index];
                        final color = _getLevelColor(entry.level);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EmberColors.surfaceContainerLow.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: entry.level == LogLevel.error
                                  ? const Color(0xFFFF5252).withValues(alpha: 0.4)
                                  : EmberColors.outlineVariant.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.levelLabel,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.formattedTime,
                                    style: const TextStyle(
                                      color: EmberColors.textMuted,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.tag,
                                      style: const TextStyle(
                                        color: EmberColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                entry.message,
                                style: TextStyle(
                                  color: entry.level == LogLevel.error ? const Color(0xFFFF8A80) : EmberColors.textPrimary,
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (entry.error != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: SelectableText(
                                    entry.error!,
                                    style: const TextStyle(
                                      color: Color(0xFFFF5252),
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, LogLevel? level) {
    final isSelected = _selectedFilter == level;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = level),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? EmberColors.primaryAmber : EmberColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? EmberColors.obsidianBase : EmberColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: ACTIVE PLAYBACK TELEMETRY
  // ==========================================
  Widget _buildPlaybackTab() {
    return AnimatedBuilder(
      animation: LogService.instance,
      builder: (context, _) {
        final log = LogService.instance;
        final player = context.watch<PlayerProvider>();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // One-Tap Quick Export Action
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: EmberColors.primaryAmber,
                foregroundColor: EmberColors.obsidianBase,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _copyReport,
              icon: const FaIcon(FontAwesomeIcons.clipboardCheck, size: 16),
              label: const Text(
                'Copy Full Markdown Diagnostic Report',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Active Track Card
            _buildCard(
              title: 'CURRENT TRACK',
              icon: FontAwesomeIcons.music,
              children: [
                _buildInfoRow('Title', log.activeSongTitle),
                _buildInfoRow('Artist', log.activeSongArtist),
                _buildInfoRow('Song ID', log.activeSongId.isNotEmpty ? log.activeSongId : 'None'),
                _buildInfoRow('Player State', log.exoplayerState),
                _buildInfoRow('Is Playing', player.isPlaying ? 'YES' : 'NO'),
                _buildInfoRow('Stream Loading', player.isLoadingStream ? 'YES (Buffering)' : 'NO'),
                _buildInfoRow('Failures in Row', '${log.consecutiveFailures}'),
              ],
            ),
            const SizedBox(height: 14),

            // Resolved Candidate Streams
            _buildCard(
              title: 'RESOLVED STREAM CANDIDATES (${log.lastCandidates.length})',
              icon: FontAwesomeIcons.link,
              children: log.lastCandidates.isEmpty
                  ? [
                      const Text(
                        'No direct stream candidates resolved yet.',
                        style: TextStyle(color: EmberColors.textMuted, fontSize: 11.5),
                      ),
                    ]
                  : log.lastCandidates.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final url = entry.value;
                      final isAac = url.contains('mime=audio%2Fmp4') || url.contains('itag=140');
                      final isOpus = url.contains('mime=audio%2Fwebm') || url.contains('itag=251');
                      final codec = isAac ? 'AAC / MP4 (DSP Fast)' : (isOpus ? 'Opus / WebM' : 'Audio');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Candidate #$idx: ',
                                  style: const TextStyle(
                                    color: EmberColors.primaryAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: EmberColors.primaryAmber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    codec,
                                    style: const TextStyle(
                                      color: EmberColors.primaryAmber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              url,
                              maxLines: 2,
                              style: const TextStyle(
                                color: EmberColors.textMuted,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
            const SizedBox(height: 14),

            // Last Error Card (if any)
            if (log.lastError != null) ...[
              _buildCard(
                title: 'LAST PLAYBACK EXCEPTION',
                icon: FontAwesomeIcons.triangleExclamation,
                borderColor: const Color(0xFFFF5252),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      log.lastError!,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (log.lastStackTrace != null && log.lastStackTrace!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Stack Trace:', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        log.lastStackTrace!,
                        style: const TextStyle(
                          color: EmberColors.textMuted,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
            ],

            // System Environment Card
            _buildCard(
              title: 'SYSTEM & HARDWARE ENVIRONMENT',
              icon: FontAwesomeIcons.microchip,
              children: [
                _buildInfoRow('Operating System', log.osInfo),
                _buildInfoRow('App Version', 'Sine 1.0.9 (Build 11)'),
                _buildInfoRow('Audio Decoder', 'ExoPlayer / MediaCodec DSP Hardware Accelerated'),
                _buildInfoRow('Architecture', 'NewPipe-Direct InnerTube Extractor'),
              ],
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 3: STREAM TEST EXTRACTION SANDBOX
  // ==========================================
  Widget _buildTesterTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EmberColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  FaIcon(FontAwesomeIcons.flask, size: 14, color: EmberColors.primaryAmber),
                  SizedBox(width: 8),
                  Text(
                    'Live Stream Extraction Sandbox',
                    style: TextStyle(
                      color: EmberColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Test YouTube stream manifest resolution, container bitrates, and HTTP reachability for any video ID or search query.',
                style: TextStyle(color: EmberColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testQueryController,
                      style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: EmberColors.surfaceContainerHigh,
                        hintText: 'e.g. dQw4w9WgXcQ or song name',
                        hintStyle: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmberColors.primaryAmber,
                      foregroundColor: EmberColors.obsidianBase,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isTestingStream ? null : _runStreamTest,
                    child: _isTestingStream
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: EmberColors.obsidianBase),
                          )
                        : const Text('Test', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_testResult != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EmberColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _testResult!.success ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        FaIcon(
                          _testResult!.success ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleXmark,
                          color: _testResult!.success ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _testResult!.success ? 'EXTRACTION SUCCESS' : 'EXTRACTION FAILED',
                          style: TextStyle(
                            color: _testResult!.success ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_testResult!.durationMs} ms',
                      style: const TextStyle(
                        color: EmberColors.primaryAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const Divider(color: EmberColors.outlineVariant, height: 20),
                ...List.generate(_testResult!.steps.length, (i) {
                  final step = _testResult!.steps[i];
                  final isErr = step.contains('ERROR') || step.contains('FAIL');
                  final isSuccess = step.contains('SUCCESS');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Text(
                      step,
                      style: TextStyle(
                        color: isErr
                            ? const Color(0xFFFF5252)
                            : (isSuccess ? const Color(0xFF69F0AE) : EmberColors.textPrimary),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required FaIconData icon,
    required List<Widget> children,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? EmberColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 13, color: EmberColors.primaryAmber),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: EmberColors.primaryAmber,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: EmberColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: EmberColors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
