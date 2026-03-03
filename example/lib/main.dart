import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web_haptics/web_haptics.dart';

void main() {
  runApp(const WebHapticsDemo());
}

class WebHapticsDemo extends StatelessWidget {
  const WebHapticsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'web_haptics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.grey,
        brightness: Brightness.light,
      ),
      home: const DemoPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Emoji particle data
// ---------------------------------------------------------------------------

class _Particle {
  _Particle({
    required this.icon,
    required this.startX,
    required this.startY,
    required this.dx,
    required this.dy,
    required this.size,
    required this.rotation,
    required this.controller,
  });

  final IconData icon;
  final double startX;
  final double startY;
  final double dx;
  final double dy;
  final double size;
  final double rotation;
  final AnimationController controller;
}

// ---------------------------------------------------------------------------
// Preset definition
// ---------------------------------------------------------------------------

class _Preset {
  const _Preset(this.name, this.icon, this.particleIcons);

  final String name;
  final IconData icon;
  final List<IconData> particleIcons;
}

// ---------------------------------------------------------------------------
// Demo page
// ---------------------------------------------------------------------------

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> with TickerProviderStateMixin {
  late final WebHaptics _haptics;
  String? _activePreset;
  final List<_Particle> _particles = [];
  final _random = Random();

  static const _notificationPresets = [
    _Preset('success', Icons.check_circle_outline,
        [Icons.check, Icons.star_outline, Icons.thumb_up_outlined]),
    _Preset('warning', Icons.warning_amber_rounded,
        [Icons.priority_high, Icons.warning_amber, Icons.report_outlined]),
    _Preset('error', Icons.error_outline,
        [Icons.close, Icons.block, Icons.dangerous_outlined]),
  ];

  static const _impactPresets = [
    _Preset('light', Icons.brightness_low,
        [Icons.light_mode_outlined, Icons.wb_sunny_outlined, Icons.flare]),
    _Preset('medium', Icons.brightness_medium,
        [Icons.circle_outlined, Icons.adjust, Icons.lens_outlined]),
    _Preset('heavy', Icons.brightness_high,
        [Icons.fitness_center, Icons.gavel, Icons.flash_on]),
    _Preset('soft', Icons.cloud_outlined,
        [Icons.cloud_outlined, Icons.spa_outlined, Icons.air]),
    _Preset('rigid', Icons.square_outlined,
        [Icons.square_outlined, Icons.crop_square, Icons.dashboard_outlined]),
  ];

  static const _selectionPresets = [
    _Preset('selection', Icons.touch_app_outlined,
        [Icons.touch_app_outlined, Icons.radio_button_checked, Icons.ads_click]),
  ];

  static const _customPresets = [
    _Preset('nudge', Icons.notifications_active_outlined,
        [Icons.notifications_outlined, Icons.campaign_outlined, Icons.push_pin_outlined]),
    _Preset('buzz', Icons.vibration,
        [Icons.vibration, Icons.waves, Icons.graphic_eq]),
  ];

  @override
  void initState() {
    super.initState();
    _haptics = WebHaptics();
  }

  @override
  void dispose() {
    for (final p in _particles) {
      p.controller.dispose();
    }
    _haptics.destroy();
    super.dispose();
  }

  Future<void> _triggerPreset(String name, Offset globalPosition,
      List<IconData> icons) async {
    setState(() => _activePreset = name);
    _spawnParticles(icons, globalPosition);
    await _haptics.trigger(name);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _activePreset = null);
  }

  void _spawnParticles(List<IconData> icons, Offset position) {
    final count = 5 + _random.nextInt(4);

    for (var i = 0; i < count; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + _random.nextInt(600)),
        vsync: this,
      );

      final particle = _Particle(
        icon: icons[_random.nextInt(icons.length)],
        startX: position.dx - 10 + _random.nextDouble() * 20,
        startY: position.dy - 10,
        dx: (_random.nextDouble() - 0.5) * 120,
        dy: -(80 + _random.nextDouble() * 180),
        size: 16 + _random.nextDouble() * 12,
        rotation: (_random.nextDouble() - 0.5) * 1.2,
        controller: controller,
      );

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() => _particles.remove(particle));
          }
          controller.dispose();
        }
      });

      _particles.add(particle);
      controller.forward();
    }

    setState(() {});
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _buildTitle()),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Haptic feedback for Flutter web',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[500]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(child: _buildStatusChip()),
                      const SizedBox(height: 36),
                      _buildSection('Notification', _notificationPresets),
                      _buildSection('Impact', _impactPresets),
                      _buildSection('Selection', _selectionPresets),
                      _buildSection('Custom', _customPresets),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Dart port of web-haptics by Lochie Axon',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Particle overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final particle in _particles)
                    AnimatedBuilder(
                      animation: particle.controller,
                      builder: (context, _) {
                        final t = particle.controller.value;
                        final ease = Curves.easeOut.transform(t);
                        return Positioned(
                          left: particle.startX + particle.dx * ease,
                          top: particle.startY + particle.dy * ease,
                          child: Opacity(
                            opacity: (1.0 - t).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: particle.rotation * t,
                              child: Icon(
                                particle.icon,
                                size: particle.size,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'web_haptics',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: Colors.grey[900],
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            WebHaptics.isSupported ? Icons.vibration : Icons.phone_iphone,
            size: 14,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            WebHaptics.isSupported
                ? 'Vibration API supported'
                : 'Using iOS haptic fallback',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_Preset> presets) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                _PresetChip(
                  name: preset.name,
                  icon: preset.icon,
                  isActive: _activePreset == preset.name,
                  onTapUp: (globalPos) =>
                      _triggerPreset(preset.name, globalPos, preset.particleIcons),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preset chip
// ---------------------------------------------------------------------------

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.name,
    required this.icon,
    required this.isActive,
    required this.onTapUp,
  });

  final String name;
  final IconData icon;
  final bool isActive;
  final void Function(Offset globalPosition) onTapUp;

  @override
  Widget build(BuildContext context) {
    final displayName = name[0].toUpperCase() + name.substring(1);

    return GestureDetector(
      onTapUp: (details) => onTapUp(details.globalPosition),
      child: AnimatedScale(
        scale: isActive ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.grey[300] : Colors.grey[100],
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isActive ? Colors.grey[500]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
