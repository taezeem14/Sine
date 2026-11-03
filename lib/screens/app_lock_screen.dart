import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_lock_service.dart';
import '../theme/ember_theme.dart';

enum AppLockMode {
  unlock,
  setupNew,
  changeOld,
}

class AppLockScreen extends StatefulWidget {
  final AppLockMode mode;
  final VoidCallback? onUnlocked;
  final ValueChanged<bool>? onSetupComplete;

  const AppLockScreen({
    super.key,
    this.mode = AppLockMode.unlock,
    this.onUnlocked,
    this.onSetupComplete,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _firstEnteredPin; // Used during setup confirmation
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      _handleSubmitPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleSubmitPin() async {
    final pin = _enteredPin;

    if (widget.mode == AppLockMode.unlock) {
      final isValid = await AppLockService.verifyPin(pin);
      if (isValid) {
        HapticFeedback.mediumImpact();
        AppLockService.isUnlockedThisSession = true;
        if (widget.onUnlocked != null) {
          widget.onUnlocked!();
        } else if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _triggerError('Incorrect passcode');
      }
    } else if (widget.mode == AppLockMode.setupNew) {
      if (_firstEnteredPin == null) {
        // First entry done, prompt confirmation
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
        });
      } else {
        if (_firstEnteredPin == pin) {
          await AppLockService.setPin(pin);
          HapticFeedback.mediumImpact();
          if (widget.onSetupComplete != null) {
            widget.onSetupComplete!(true);
          } else if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          _triggerError('Passcodes did not match');
          setState(() {
            _firstEnteredPin = null;
          });
        }
      }
    }
  }

  void _triggerError(String msg) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = msg;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  String get _title {
    if (widget.mode == AppLockMode.unlock) {
      return 'Enter Passcode';
    }
    if (_firstEnteredPin == null) {
      return 'Set 4-Digit Passcode';
    }
    return 'Confirm Passcode';
  }

  String get _subtitle {
    if (widget.mode == AppLockMode.unlock) {
      return 'Enter your passcode to unlock Sine';
    }
    if (_firstEnteredPin == null) {
      return 'Choose a 4-digit PIN to secure your app';
    }
    return 'Re-enter your 4-digit PIN to confirm';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.mode != AppLockMode.unlock,
      child: Scaffold(
        backgroundColor: EmberColors.obsidianBase,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Glowing Sine Wave Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                  border: Border.all(color: EmberColors.primaryBlue.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: EmberColors.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.lock,
                    color: EmberColors.primaryBlue,
                    size: 26,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title & Subtitle
              Text(
                _title,
                style: const TextStyle(
                  color: EmberColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                style: const TextStyle(
                  color: EmberColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),

              const SizedBox(height: 32),

              // Animated 4-dot PIN indicator
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = (_shakeController.isAnimating)
                      ? (12.0 * (_shakeAnimation.value * 2 - 1).abs() * (_enteredPin.isEmpty ? 1 : 0))
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? EmberColors.primaryBlue : Colors.transparent,
                        border: Border.all(
                          color: isFilled
                              ? EmberColors.primaryBlue
                              : EmberColors.textMuted.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: EmberColors.primaryBlue.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              // Error feedback message
              Container(
                height: 36,
                alignment: Alignment.center,
                child: _errorMessage != null
                    ? Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: EmberColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),

              const Spacer(flex: 1),

              // Number Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Left Utility Key (Cancel if in modal mode)
                        widget.mode != AppLockMode.unlock
                            ? SizedBox(
                                width: 72,
                                height: 72,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted, fontSize: 13)),
                                ),
                              )
                            : const SizedBox(width: 72, height: 72),

                        // Zero Key
                        _buildNumberKey('0'),

                        // Backspace Key
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(36),
                            onTap: _onBackspace,
                            child: const Center(
                              child: Icon(Icons.backspace_outlined, color: EmberColors.textSecondary, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberKey(d)).toList(),
    );
  }

  Widget _buildNumberKey(String digit) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EmberColors.surfaceContainerLow,
        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          splashColor: EmberColors.primaryBlue.withValues(alpha: 0.2),
          onTap: () => _onKeyPress(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                color: EmberColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
