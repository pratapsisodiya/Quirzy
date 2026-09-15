import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/progress_providers.dart';

/// A vertical, Instagram-Story-proportioned card summarizing progress —
/// captured and shared as an image (PRD §F8 "shareable score card").
/// Solid brand color, no gradient/glass, matching the app's flat style.
class ShareCard extends StatelessWidget {
  final MyPrepStats stats;

  const ShareCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 568,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF6200EA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text(
                'Quirzy',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${stats.streak}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 72,
              height: 1,
            ),
          ),
          Text(
            'day streak',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Level ${stats.level.level} · ${stats.level.title}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('${stats.dailyAnsweredLast7.fold<int>(0, (a, b) => a + b)}', 'this week'),
              _stat('${stats.topicStats.length}', 'topics'),
            ],
          ),
          const Spacer(),
          Text(
            'Practice a little every day →',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
