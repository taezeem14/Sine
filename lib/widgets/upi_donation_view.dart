import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/ember_theme.dart';

class UpiDonationView extends StatefulWidget {
  final ScrollController? scrollController;

  const UpiDonationView({super.key, this.scrollController});

  @override
  State<UpiDonationView> createState() => _UpiDonationViewState();
}

class _UpiDonationViewState extends State<UpiDonationView> {
  static const String upiId = '7006616470@fam';
  static const String payeeName = 'Muhammad Taezeem Tariq';

  final List<int> _presetAmounts = [21, 50, 100, 250, 500];
  int? _selectedAmount = 100;
  final TextEditingController _customAmountController = TextEditingController();
  bool _isCustomAmount = false;

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  String get _currentAmountString {
    if (_isCustomAmount) {
      final custom = _customAmountController.text.trim();
      if (custom.isNotEmpty && double.tryParse(custom) != null && double.parse(custom) > 0) {
        return custom;
      }
      return '100';
    }
    return (_selectedAmount ?? 100).toString();
  }

  String _buildUpiUri({String scheme = 'upi'}) {
    final amount = _currentAmountString;
    final encodedPayee = Uri.encodeComponent(payeeName);
    final note = Uri.encodeComponent('Donation for Sine Music');
    return '$scheme://pay?pa=$upiId&pn=$encodedPayee&tn=$note&am=$amount&cu=INR';
  }

  Future<void> _launchPayment({String scheme = 'upi', String? appName}) async {
    final uriString = _buildUpiUri(scheme: scheme);
    final uri = Uri.parse(uriString);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: try raw upi scheme if a specific app scheme failed
        if (scheme != 'upi') {
          final fallbackUri = Uri.parse(_buildUpiUri(scheme: 'upi'));
          final fallbackLaunched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          if (fallbackLaunched) return;
        }
        _handleLaunchFailure(appName);
      }
    } catch (_) {
      _handleLaunchFailure(appName);
    }
  }

  void _handleLaunchFailure(String? appName) {
    _copyUpiId();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EmberColors.surfaceContainerHigh,
        duration: const Duration(seconds: 4),
        content: Text(
          appName != null
              ? 'Could not open $appName. UPI ID ($upiId) copied to clipboard!'
              : 'No UPI app responded. UPI ID ($upiId) copied to clipboard!',
          style: TextStyle(color: EmberColors.textPrimary, fontSize: 13),
        ),
      ),
    );
  }

  void _copyUpiId() {
    Clipboard.setData(const ClipboardData(text: upiId));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EmberColors.primaryAmber.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: EmberColors.obsidianBase, size: 20),
            SizedBox(width: 10),
            Text(
              'UPI ID ($upiId) copied to clipboard! ✨',
              style: TextStyle(color: EmberColors.obsidianBase, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {


    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ==========================================
        // HERO DONATION BANNER
        // ==========================================
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EmberColors.primaryAmber.withValues(alpha: 0.22),
                EmberColors.surfaceContainerHigh.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: EmberColors.primaryAmber.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: EmberColors.primaryAmber.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EmberColors.primaryAmber,
                      boxShadow: [
                        BoxShadow(
                          color: EmberColors.primaryAmber.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.heart,
                        color: EmberColors.obsidianBase,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Sine Development',
                          style: TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Direct UPI Transfer • 100% Goes to Dev',
                          style: TextStyle(
                            color: EmberColors.primaryAmberHi,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Sine has zero ads, no subscriptions, and zero tracking. If you enjoy uninterrupted high-fidelity music, consider chipping in to support ongoing server and development costs!',
                style: TextStyle(
                  color: EmberColors.textSecondary.withValues(alpha: 0.92),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ==========================================
        // UPI ID TAP-TO-COPY CARD
        // ==========================================
        InkWell(
          onTap: _copyUpiId,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: EmberColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EmberColors.primaryAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.qrcode,
                    color: EmberColors.primaryAmber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECIPIENT UPI ID',
                        style: TextStyle(
                          color: EmberColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        upiId,
                        style: TextStyle(
                          color: EmberColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Muhammad Taezeem Tariq (@fam / FamPay)',
                        style: TextStyle(
                          color: EmberColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EmberColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EmberColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: EmberColors.primaryAmber),
                      SizedBox(width: 5),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: EmberColors.primaryAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ==========================================
        // SELECT AMOUNT SECTION
        // ==========================================
        const Text(
          'SELECT CONTRIBUTION AMOUNT',
          style: TextStyle(
            color: EmberColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._presetAmounts.map((amount) {
              final isSelected = !_isCustomAmount && _selectedAmount == amount;
              return InkWell(
                onTap: () {
                  setState(() {
                    _isCustomAmount = false;
                    _selectedAmount = amount;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? EmberColors.primaryAmber
                        : EmberColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? EmberColors.primaryAmberHi
                          : EmberColors.outlineVariant.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '₹$amount',
                    style: TextStyle(
                      color: isSelected
                          ? EmberColors.obsidianBase
                          : EmberColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
            InkWell(
              onTap: () {
                setState(() {
                  _isCustomAmount = true;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _isCustomAmount
                      ? EmberColors.primaryAmber
                      : EmberColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isCustomAmount
                        ? EmberColors.primaryAmberHi
                        : EmberColors.outlineVariant.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  'Custom',
                  style: TextStyle(
                    color: _isCustomAmount
                        ? EmberColors.obsidianBase
                        : EmberColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_isCustomAmount) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(color: EmberColors.primaryAmber, fontSize: 18, fontWeight: FontWeight.bold),
              hintText: 'Enter amount (e.g. 150)',
              hintStyle: TextStyle(color: EmberColors.textMuted, fontSize: 14),
              filled: true,
              fillColor: EmberColors.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EmberColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: EmberColors.primaryAmber, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],

        const SizedBox(height: 22),

        // ==========================================
        // PRIMARY ACTION: PAY VIA UPI
        // ==========================================
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _launchPayment(scheme: 'upi'),
            icon: const FaIcon(FontAwesomeIcons.bolt, size: 18),
            label: Text(
              'Transfer ₹$_currentAmountString via UPI',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: EmberColors.primaryAmber,
              foregroundColor: EmberColors.obsidianBase,
              elevation: 4,
              shadowColor: EmberColors.primaryAmber.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ==========================================
        // DIRECT APP SHORTCUTS
        // ==========================================
        const Text(
          'OR PAY VIA SPECIFIC APP',
          style: TextStyle(
            color: EmberColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _UpiAppShortcut(
                label: 'FamPay',
                icon: FontAwesomeIcons.wallet,
                color: const Color(0xFFFF9800),
                onTap: () => _launchPayment(scheme: 'upi', appName: 'FamPay'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _UpiAppShortcut(
                label: 'GPay',
                icon: FontAwesomeIcons.google,
                color: const Color(0xFF4285F4),
                onTap: () => _launchPayment(scheme: 'gpay', appName: 'Google Pay'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _UpiAppShortcut(
                label: 'PhonePe',
                icon: FontAwesomeIcons.p,
                color: const Color(0xFF673AB7),
                onTap: () => _launchPayment(scheme: 'phonepe', appName: 'PhonePe'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _UpiAppShortcut(
                label: 'Paytm',
                icon: FontAwesomeIcons.moneyBillWave,
                color: const Color(0xFF00B9F1),
                onTap: () => _launchPayment(scheme: 'paytmmp', appName: 'Paytm'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ==========================================
        // QR CODE SCANNER SECTION
        // ==========================================
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EmberColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.camera, size: 14, color: EmberColors.primaryAmber),
                  SizedBox(width: 8),
                  Text(
                    'Scan with Any UPI App',
                    style: TextStyle(
                      color: EmberColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 200,
                  height: 200,
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: _buildUpiUri(scheme: 'upi'),
                    version: QrVersions.auto,
                    size: 184,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Point camera from GPay, PhonePe, Paytm, or FamPay',
                style: TextStyle(color: EmberColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _UpiAppShortcut extends StatelessWidget {
  final String label;
  final FaIconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UpiAppShortcut({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: EmberColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 16, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: EmberColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
