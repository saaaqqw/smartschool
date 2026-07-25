import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';

/// ──────────────────────────────────────────────────────────────
/// شريط تنبيه Offline — يظهر تلقائياً عند انقطاع الإنترنت
/// ويختفي عند الاتصال مع رسالة تأكيد.
/// ──────────────────────────────────────────────────────────────
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnim;

  bool _isOnline = true;
  bool _showReconnected = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _isOnline = ConnectivityService.isOnlineNotifier.value;

    ConnectivityService.isOnlineNotifier.addListener(_onConnectivityChange);
  }

  void _onConnectivityChange() {
    final online = ConnectivityService.isOnlineNotifier.value;
    if (!mounted) return;

    if (!online) {
      // انقطع الاتصال
      setState(() {
        _isOnline = false;
        _showReconnected = false;
      });
      _animController.forward();
    } else if (!_isOnline) {
      // عاد الاتصال
      setState(() {
        _isOnline = true;
        _showReconnected = true;
      });
      _animController.reverse().then((_) {
        if (!mounted) return;
        // أظهر رسالة "تم الاتصال" لمدة 3 ثوانٍ
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showReconnected = false);
        });
      });
    }
  }

  @override
  void dispose() {
    ConnectivityService.isOnlineNotifier.removeListener(_onConnectivityChange);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── شريط Offline (يظهر/يختفي بانيميشن) ──────────────────
        SizeTransition(
          sizeFactor: _slideAnim,
          axisAlignment: -1,
          child: _OfflineStrip(),
        ),

        // ── شريط "تم الاتصال" ─────────────────────────────────────
        if (_showReconnected) _ReconnectedStrip(),

        // ── المحتوى الأصلي ────────────────────────────────────────
        Expanded(child: widget.child),
      ],
    );
  }
}

// ── شريط Offline ─────────────────────────────────────────────────
class _OfflineStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      color: const Color(0xFFB71C1C),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'أنت غير متصل — تعمل بالبيانات المحفوظة',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── شريط "تم الاتصال" ────────────────────────────────────────────
class _ReconnectedStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      color: const Color(0xFF1B5E20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'تم الاتصال بالإنترنت ✅',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
