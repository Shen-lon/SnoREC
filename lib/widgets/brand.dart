import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Shared geometric mark for the UI and the launcher asset renderer.
class SnorecMark extends StatelessWidget {
  final double size;
  const SnorecMark({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: const SnorecMarkPainter(),
    ),
  );
}

class SnorecMarkPainter extends CustomPainter {
  const SnorecMarkPainter({this.monochrome = false});
  final bool monochrome;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(const Rect.fromLTWH(14, 12, 70, 76)),
      Path()..addOval(const Rect.fromLTWH(40, 2, 65, 68)),
    );
    canvas.drawPath(moon, Paint()..color = AppColors.ink);
    canvas.drawCircle(
      const Offset(73, 65),
      14,
      Paint()..color = monochrome ? AppColors.ink : AppColors.record,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SnorecMarkPainter oldDelegate) =>
      monochrome != oldDelegate.monochrome;
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SnorecMark(size: 30),
      SizedBox(width: 9),
      Text(
        'SnoREC',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class ScreenHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const ScreenHeading({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.8,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
    ),
  );
}
