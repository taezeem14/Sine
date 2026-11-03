import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/passkey_service.dart';
import '../theme/ember_theme.dart';
import 'pulsepipe_shell_screen.dart';

class PasskeyGateScreen extends StatefulWidget {
  const PasskeyGateScreen({super.key});

  @override
  State<PasskeyGateScreen> createState() => _PasskeyGateScreenState();
}

class _PasskeyGateScreenState extends State<PasskeyGateScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _shakeController;
  String? _errorMessage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final ok = await PasskeyService.activate(code);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PulsePipeShellScreen()),
      );
    } else {
      setState(() {
        _loading = false;
        _errorMessage = 'Invalid passkey — please check and retry';
      });
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Flame Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0x40F59E0B),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: EmberColors.primaryAmber.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.fireFlameCurved,
                      color: EmberColors.primaryAmber,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Brand Header
                Text(
                  'SINE',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: EmberColors.primaryAmberHi,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'high-fidelity audio experience',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: EmberColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 36),

                // Passkey Card
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: EmberColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: EmberColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Enter Activation Passkey',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: EmberColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'One-time verification to unlock full playback',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: EmberColors.textMuted,
                              fontSize: 11,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Input with shake animation
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final offset = _shakeController.isAnimating
                              ? math.sin(_shakeController.value * math.pi * 6) * 10 * (1 - _shakeController.value)
                              : 0.0;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.0,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: 'EMBR-XXXX',
                            hintStyle: TextStyle(
                              color: EmberColors.textMuted.withValues(alpha: 0.5),
                              letterSpacing: 3.0,
                            ),
                            filled: true,
                            fillColor: EmberColors.surfaceContainerHigh,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: EmberColors.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: EmberColors.primaryAmber,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: EmberColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Activate Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EmberColors.primaryAmber,
                            foregroundColor: EmberColors.obsidianBase,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: EmberColors.obsidianBase,
                                  ),
                                )
                              : const Text(
                                  'Activate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Author Credit
                Text(
                  'crafted with ♥ by Muhammad Taezeem Tariq • @taezeem14',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: EmberColors.textMuted.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
