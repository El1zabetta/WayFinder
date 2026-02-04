import 'package:flutter/material.dart';
import 'glass_container.dart';
import 'ai_animations.dart';

/// HUD Info Display - Premium Iron Man Style
class HUDInfoDisplay extends StatelessWidget {
  final String? distance;
  final String? direction;
  final int? objectCount;
  final double? batteryLevel;
  final bool isScanning;
  final bool isDanger;
  final bool isThinking;
  
  const HUDInfoDisplay({
    super.key,
    this.distance,
    this.direction,
    this.objectCount,
    this.batteryLevel,
    this.isScanning = true,
    this.isDanger = false,
    this.isThinking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Data Streams (Left & Right)
        Positioned(
          top: 100,
          left: 10,
          child: _buildDataStream(isLeft: true),
        ),
        Positioned(
          top: 100,
          right: 10,
          child: _buildDataStream(isLeft: false),
        ),

        // 2. Corner Reticles
        const Positioned(top: 40, left: 10, child: ScanningReticle()),
        const Positioned(top: 40, right: 10, child: ScanningReticle()),
        const Positioned(bottom: 100, left: 10, child: ScanningReticle()),
        const Positioned(bottom: 100, right: 10, child: ScanningReticle()),

        // 3. Main Info Banner
        Positioned(
          top: 50,
          left: 15,
          right: 15,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(10),
            decoration: isDanger ? BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 2),
            ) : null,
            child: Column(
              children: [
                if (isThinking)
                  _buildThinkingIndicator(),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side: Status & Objects
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (objectCount != null)
                          _buildPremiumItem(
                            icon: Icons.visibility_outlined,
                            label: 'VISION',
                            value: '$objectCount OBJ',
                            color: isDanger ? Colors.redAccent : const Color(0xFF00D4FF),
                            isCritical: isDanger || (objectCount ?? 0) > 10,
                          ),
                        const SizedBox(height: 10),
                        if (batteryLevel != null)
                          _buildPremiumItem(
                            icon: Icons.bolt,
                            label: 'POWER',
                            value: '${(batteryLevel! * 100).toInt()}%',
                            color: batteryLevel! < 0.2 ? Colors.redAccent : const Color(0xFF00E676),
                          ),
                      ],
                    ),
                    
                    // Right Side: Navigation
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (distance != null)
                          _buildPremiumItem(
                            icon: Icons.straighten,
                            label: 'DIST',
                            value: distance!,
                            color: const Color(0xFF00D4FF),
                          ),
                        const SizedBox(height: 10),
                        if (direction != null)
                          _buildPremiumItem(
                            icon: Icons.explore_outlined,
                            label: 'HDG',
                            value: direction!,
                            color: const Color(0xFFFFB800),
                          ),
                      ],
                    ),
                  ],
                ),
                
                if (isScanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: ScanningLine(),
                  ),
                
                if (isDanger)
                  PulseAnimation(
                    duration: const Duration(milliseconds: 800),
                    minScale: 1.0,
                    maxScale: 1.05,
                    child: Container(
                      margin: const EdgeInsets.only(top: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
                        ],
                      ),
                      child: const Text(
                        'WARNING: OBSTACLE DETECTED',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataStream({required bool isLeft}) {
    return const SizedBox(
      width: 60,
      height: 200,
      child: TelemetryStream(),
    );
  }

  Widget _buildThinkingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AITypingIndicator(size: 10),
          const SizedBox(width: 15),
          Text(
             'AI ANALYZING...',
             style: TextStyle(
               color: Colors.white.withOpacity(0.8),
               fontSize: 10,
               letterSpacing: 3,
               fontWeight: FontWeight.w900,
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isCritical = false,
  }) {
    Widget content = GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: BorderRadius.circular(12),
      blur: 15,
      opacity: isCritical ? 0.3 : 0.15,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              if (isCritical)
                PulseAnimation(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.5), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isCritical) {
      return ShakeAnimation(
        trigger: true,
        child: content,
      );
    }
    return content;
  }
}

class TelemetryStream extends StatefulWidget {
  const TelemetryStream({super.key});

  @override
  State<TelemetryStream> createState() => _TelemetryStreamState();
}

class _TelemetryStreamState extends State<TelemetryStream> {
  late Timer _timer;
  final List<String> _data = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (mounted) {
        setState(() {
          _data.insert(0, _generateRandomData());
          if (_data.length > 15) _data.removeLast();
        });
      }
    });
  }

  String _generateRandomData() {
    int r = _random.nextInt(4);
    switch (r) {
      case 0: return "X:${_random.nextInt(1000)}";
      case 1: return "Y:${_random.nextInt(1000)}";
      case 2: return "CONF:${(_random.nextDouble() * 100).toStringAsFixed(1)}";
      default: return "OBJ:0x${_random.nextInt(255).toRadixString(16).padLeft(2, '0')}";
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _data.map((text) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 8,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class ScanningReticle extends StatefulWidget {
  const ScanningReticle({super.key});

  @override
  State<ScanningReticle> createState() => _ScanningReticleState();
}

class _ScanningReticleState extends State<ScanningReticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3), width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 2,
                height: 10,
                color: const Color(0xFF00D4FF).withOpacity(0.5),
              ),
            ),
            Center(
              child: Container(
                width: 10,
                height: 2,
                color: const Color(0xFF00D4FF).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ScanningLine extends StatefulWidget {
  const ScanningLine({super.key});

  @override
  State<ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (_controller.value - 0.5)),
          child: Opacity(
            opacity: 0.5,
            child: Container(
              width: double.infinity,
              height: 2,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF00D4FF).withOpacity(0.4),
                    const Color(0xFF00D4FF),
                    const Color(0xFF00D4FF).withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

