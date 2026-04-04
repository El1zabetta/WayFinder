/// WayFinder 2.0 — Search Screen
/// Object search using RynnBrain-Plan with voice input

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/spatial_audio_service.dart';
import '../widgets/glass_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  SearchResult? _result;
  bool _isSearching = false;
  String? _error;

  CameraController? _cameraController;
  bool _cameraReady = false;

  final _audio = SpatialAudioService();

  // Quick search presets
  final _presets = ['Keys', 'Door', 'Exit', 'Free space', 'Chair', 'Phone', 'Bag'];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _search(String target) async {
    if (target.isEmpty || _isSearching || !_cameraReady) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _result = null;
    });

    try {
      // Record 3s video
      await _cameraController!.startVideoRecording();
      await Future.delayed(const Duration(seconds: 3));
      final video = await _cameraController!.stopVideoRecording();

      final result = await WayFinderApi.searchObject(File(video.path), target);
      setState(() => _result = result);

      // Audio feedback
      if (result.found && result.location != null) {
        await _audio.announceObjectFound(target, result.location!.azimuth);
        await _audio.playCues(result.audioCues);
      } else {
        await _audio.speak('$target not found in current view. $result.instructions', azimuth: 0);
      }

    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.bgGlow)),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.textPrimary, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Text('Find Object',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'RynnBrain-Plan',
                          style: TextStyle(
                            color: AppTheme.accentTeal,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.glassBorder),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search_rounded, color: AppTheme.accentPrimary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17),
                            decoration: const InputDecoration(
                              hintText: 'What are you looking for?',
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 17),
                              border: InputBorder.none,
                            ),
                            onSubmitted: _search,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.close_rounded,
                                  color: AppTheme.textSecondary, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Quick presets
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text('Quick Search',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () {
                        _searchController.text = _presets[i];
                        _search(_presets[i]);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.accentTeal.withOpacity(0.3)),
                        ),
                        child: Text(
                          _presets[i],
                          style: const TextStyle(
                            color: AppTheme.accentTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Search button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: _isSearching
                        ? null
                        : () => _search(_searchController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppTheme.accentTeal,
                      disabledBackgroundColor: AppTheme.textMuted,
                    ),
                    child: _isSearching
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 12),
                              Text('Analyzing with RynnBrain...'),
                            ],
                          )
                        : const Text('Search Now'),
                  ),
                ),

                const SizedBox(height: 24),

                // Result
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.danger),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(color: AppTheme.danger))),
                        ],
                      ),
                    ),
                  ),

                if (_result != null) _buildResult(_result!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(SearchResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.found ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: result.found ? AppTheme.safe : AppTheme.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  result.found ? '${result.target} Found!' : '${result.target} Not Visible',
                  style: TextStyle(
                    color: result.found ? AppTheme.safe : AppTheme.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            if (result.found && result.location != null) ...[
              const SizedBox(height: 12),
              _DirectionIndicator(azimuth: result.location!.azimuth),
            ],

            const SizedBox(height: 12),
            Text(result.instructions, style: Theme.of(context).textTheme.bodyMedium),

            const SizedBox(height: 8),
            Text(
              '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }
}

/// Visual direction indicator showing where the object is
class _DirectionIndicator extends StatelessWidget {
  final double azimuth;
  const _DirectionIndicator({required this.azimuth});

  @override
  Widget build(BuildContext context) {
    final clampedAzi = azimuth.clamp(-90.0, 90.0);
    final t = (clampedAzi + 90) / 180; // 0..1

    String dirText;
    if (clampedAzi < -30) dirText = '← Left';
    else if (clampedAzi > 30) dirText = 'Right →';
    else dirText = 'Ahead ↑';

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Direction bar
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.safeGradient,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Text(
            dirText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
