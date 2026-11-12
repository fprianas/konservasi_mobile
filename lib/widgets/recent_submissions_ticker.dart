import 'dart:async';
import 'package:flutter/material.dart';
import '../models/recent_submission_item.dart';

class RecentSubmissionsTicker extends StatefulWidget {
  final RecentSubmissionsData? data;
  final bool isLoading;
  final void Function(RecentSubmissionItem item)? onItemTap;

  const RecentSubmissionsTicker({
    super.key,
    required this.data,
    this.isLoading = false,
    this.onItemTap,
  });

  @override
  State<RecentSubmissionsTicker> createState() => _RecentSubmissionsTickerState();
}

class _RecentSubmissionsTickerState extends State<RecentSubmissionsTicker>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  Timer? _scrollTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  @override
  void didUpdateWidget(covariant RecentSubmissionsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data || oldWidget.isLoading != widget.isLoading) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    if (widget.data == null || widget.data!.items.isEmpty || widget.isLoading) return;

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted || _isUserInteracting || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (max <= 0) return;

      if (current >= max) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(current + 0.85);
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String period) {
    switch (period) {
      case 'today':
        return const Color(0xFF10B981); // Emerald Green (Fresh Today)
      case 'week':
        return const Color(0xFF38BDF8); // Sky Blue (This Week)
      case 'month':
        return const Color(0xFFF59E0B); // Warm Amber (This Month)
      default:
        return const Color(0xFF71717A); // Zinc Grey (No input)
    }
  }

  String _getBadgeLabel(String period) {
    switch (period) {
      case 'today':
        return 'HARI INI';
      case 'week':
        return 'MINGGU INI';
      case 'month':
        return 'BULAN INI';
      default:
        return 'INFO';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final period = data?.period ?? 'empty';
    final items = data?.items ?? [];
    final statusColor = _getStatusColor(period);
    final badgeLabel = _getBadgeLabel(period);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Solid Obsidian Black
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Badge with Pulsing Live Dot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Subtle Divider
          Container(
            width: 1,
            height: 16,
            color: const Color(0xFF3F3F46),
          ),

          const SizedBox(width: 8),

          // Right Content: Ticker / Marquee
          Expanded(
            child: widget.isLoading
                ? Row(
                    children: const [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Memeriksa input terbaru...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ],
                  )
                : items.isEmpty
                    ? Row(
                        children: const [
                          Icon(Icons.event_busy, size: 13, color: Color(0xFF71717A)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Belum ada input bulan ini',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFFA1A1AA),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notif) {
                          if (notif is UserScrollNotification) {
                            setState(() => _isUserInteracting = true);
                          } else if (notif is ScrollEndNotification) {
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _isUserInteracting = false);
                            });
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // Loop items 3 times for a seamless continuous flow
                              for (int loop = 0; loop < 3; loop++)
                                for (int i = 0; i < items.length; i++) ...[
                                  _buildTickerItem(items[i]),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'âœ¦',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                        fontSize: 8,
                                      ),
                                    ),
                                  ),
                                ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerItem(RecentSubmissionItem item) {
    return InkWell(
      onTap: () => widget.onItemTap?.call(item),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: item.namaPerusahaan,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              TextSpan(
                text: ' (${item.provinsi} â€¢ ${item.triwulan})',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFFFBBF24), // Soft Amber
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}