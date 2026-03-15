// lib/widgets/common.dart

import 'package:flutter/material.dart';
import '../constants.dart';
import '../models.dart';
import '../helpers.dart';

// ── Lotto Ball ────────────────────────────────────────────────
class LottoBall extends StatelessWidget {
  final int number;
  final double size;
  final bool win;

  const LottoBall(
      {super.key, required this.number, this.size = 90, this.win = false});

  @override
  Widget build(BuildContext context) {
    final colors = win
        ? [AppColors.ballGreen1, AppColors.ballGreen2, AppColors.ballGreen3]
        : [AppColors.ballOrange1, AppColors.ballOrange2, AppColors.ballOrange3];
    final borderColor = win ? AppColors.ballGreen3 : AppColors.ballOrangeBorder;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.28, -0.36),
          radius: 0.85,
          colors: colors,
          stops: const [0.0, 0.52, 1.0],
        ),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
              color: borderColor.withValues(alpha: 0.33),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          color: win ? Colors.white : const Color(0xFF3E1000),
          shadows: [
            Shadow(
              color: win ? Colors.black45 : Colors.white30,
              blurRadius: win ? 4 : 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small Ball ────────────────────────────────────────────────
enum BallColor { orange, red, blue }

class SmallBall extends StatelessWidget {
  final String num;
  final BallColor color;

  const SmallBall(
      {super.key, required this.num, this.color = BallColor.orange});

  @override
  Widget build(BuildContext context) {
    late final List<Color> ballColors;
    late final Color borderColor;
    late final Color textColor;

    switch (color) {
      case BallColor.orange:
        ballColors = [
          const Color(0xFFFFFDE7),
          AppColors.ballOrange2,
          AppColors.ballOrange3
        ];
        borderColor = AppColors.ballOrangeBorder;
        textColor = const Color(0xFF3E1000);
      case BallColor.red:
        ballColors = [
          const Color(0xFFFFF8E1),
          const Color(0xFFFF5722),
          AppColors.primary
        ];
        borderColor = AppColors.primary;
        textColor = Colors.white;
      case BallColor.blue:
        ballColors = [
          const Color(0xFFE3F2FD),
          const Color(0xFF42A5F5),
          AppColors.blue
        ];
        borderColor = const Color(0xFF01579B);
        textColor = Colors.white;
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.28, -0.36),
          colors: ballColors,
          stops: const [0.0, 0.52, 1.0],
        ),
        border: Border.all(color: borderColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        num.padLeft(2, '0'),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }
}

// ── App Card ──────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final EdgeInsetsGeometry? padding;

  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderWidth = 2,
    this.radius = 20,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
              color: borderColor ?? AppColors.cardBorder, width: borderWidth),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 3))
          ],
        ),
        child: child,
      );
}

// ── Section heading ───────────────────────────────────────────
class SectionHeading extends StatelessWidget {
  final String text;
  final double fontSize;
  const SectionHeading(this.text, {super.key, this.fontSize = 20});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: AppColors.primary),
      );
}

// ── Primary button ────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton(
      {super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: loading ? Colors.grey[300] : AppColors.primary,
            foregroundColor: loading ? Colors.grey[600] : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: loading ? 0 : 6,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.grey))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900)),
        ),
      );
}

// ── Draw status chip ──────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String text;
  final Color bg;
  const StatusChip({super.key, required this.text, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      );
}

// ── Draw Card ─────────────────────────────────────────────────
class DrawCard extends StatelessWidget {
  final DrawSlot slot;
  final String? combo;
  final DrawStatus status;

  const DrawCard(
      {super.key, required this.slot, this.combo, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color cardBg;
    late final Color cardBorder;
    late final Color chipBg;
    late final String chipLabel;

    switch (status) {
      case DrawStatus.done:
        cardBg = const Color(0xFFF1F8E9);
        cardBorder = const Color(0xFF558B2F);
        chipBg = const Color(0xFF558B2F);
        chipLabel = '✓ May Resulta Na!';
      case DrawStatus.live:
        cardBg = const Color(0xFFFFF8E1);
        cardBorder = const Color(0xFFF9A825);
        chipBg = AppColors.accent;
        chipLabel = '🔴 Nagda-draw...';
      case DrawStatus.upcoming:
        cardBg = const Color(0xFFF9F9F9);
        cardBorder = const Color(0xFFCCCCCC);
        chipBg = const Color(0xFF888888);
        chipLabel = '⏰ Darating pa';
    }

    final parts = combo?.split('-');
    final num1 = parts != null ? int.tryParse(parts[0]) : null;
    final num2 = parts != null ? int.tryParse(parts[1]) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 3),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(slot.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text(slot.label,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
            ]),
            StatusChip(text: chipLabel, bg: chipBg),
          ],
        ),
        const SizedBox(height: 16),
        if (status == DrawStatus.done && num1 != null && num2 != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LottoBall(number: num1, size: 90),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('—',
                    style: TextStyle(
                        fontSize: 36,
                        color: Color(0xFFBBBBBB),
                        fontWeight: FontWeight.w200)),
              ),
              LottoBall(number: num2, size: 90),
            ],
          ),
          const SizedBox(height: 10),
          const Text('WINNING COMBINATION · Premyo: ₱4,000',
              style: TextStyle(
                  color: AppColors.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ] else if (status == DrawStatus.live) ...[
          const Text('🎰', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          const Text('Nagda-draw na ngayon...',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent)),
        ] else ...[
          const Text('⏳', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          const Text('Hindi pa drawn',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight)),
        ],
      ]),
    );
  }
}

// ── Online indicator ──────────────────────────────────────────
class OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  const OnlineIndicator({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isOnline
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOnline ? const Color(0xFF81C784) : const Color(0xFFE57373),
            width: 2,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isOnline ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color:
                  isOnline ? const Color(0xFFB9F6CA) : const Color(0xFFFFCDD2),
            ),
          ),
        ]),
      );
}

// ── Winners badge ─────────────────────────────────────────────
class WinnersBadge extends StatelessWidget {
  final int count;
  const WinnersBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: count == 0 ? const Color(0xFFF5F5F5) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                count == 0 ? const Color(0xFFE0E0E0) : const Color(0xFFA5D6A7),
            width: 1.5,
          ),
        ),
        child: Text(
          '🏅 ${formatWinners(count)}',
          style: TextStyle(
            color: count == 0 ? const Color(0xFF888888) : AppColors.green,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
