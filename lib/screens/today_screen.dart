// lib/screens/today_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../constants.dart';
import '../helpers.dart';
import '../models.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final ph = getPHTime();
    final today = prov.liveToday;
    final timeStr = DateFormat('hh:mm:ss a').format(prov.currentTime);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(ph);

    final nextDraw = getNextDrawInfo();
    final hasResult = today.hasAnyResult;

    // Last drawn slot
    final latestSlot = ['9pm', '5pm', '2pm'].firstWhere(
      (s) => today.resultFor(s) != null,
      orElse: () => '',
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => prov.fetchToday(triggerCron: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Results card ──────────────────────────────────
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESULTA NGAYON',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[600],
                              letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24)),
                  child: const Text('🎱 EZ2 / 2D',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 16),
              if (!hasResult) ...[
                Center(
                    child: Column(children: [
                  const SizedBox(height: 16),
                  const Text('⏳', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 10),
                  Text(
                    prov.isRefreshing
                        ? 'Hinahanap ang resulta...'
                        : 'Wala pang resulta ngayon.',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight),
                  ),
                  const SizedBox(height: 6),
                  const Text('I-refresh para suriin.',
                      style:
                          TextStyle(fontSize: 15, color: AppColors.textLight)),
                  const SizedBox(height: 16),
                ])),
              ] else ...[
                for (final slot in kDrawSchedule) ...[
                  if (today.resultFor(slot.key) != null)
                    _DrawResultRow(
                      slot: slot,
                      combo: today.resultFor(slot.key)!,
                      winners: today.winnersFor(slot.key),
                      isLatest: slot.key == latestSlot,
                    ),
                ],
              ],
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Text('🏆 Jackpot: ',
                      style: TextStyle(color: AppColors.green, fontSize: 15)),
                  Text('₱4,000',
                      style: TextStyle(
                          color: AppColors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  Text('  |  Rambolito: ',
                      style: TextStyle(color: AppColors.green, fontSize: 15)),
                  Text('₱2,000',
                      style: TextStyle(
                          color: AppColors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Pending draw status cards ─────────────────────
          for (final slot in kDrawSchedule) ...[
            Builder(builder: (context) {
              final status = getDrawStatus(slot.drawHour);
              final combo = today.resultFor(slot.key);
              if (status == DrawStatus.done && combo != null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DrawCard(slot: slot, combo: combo, status: status),
              );
            }),
          ],

          // ── Refresh button ────────────────────────────────
          PrimaryButton(
            label: prov.isRefreshing
                ? '⏳ Hinahanap ang Resulta...'
                : '🔄 I-refresh ang Resulta',
            loading: prov.isRefreshing,
            onPressed: () => prov.fetchToday(triggerCron: true),
          ),
          const SizedBox(height: 8),
          if (prov.lastUpdate != null)
            Center(
              child: Text(
                'Na-update: ${DateFormat('hh:mm:ss a').format(prov.lastUpdate!)}  ·  PH Time: $timeStr',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
          if (prov.fetchError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                border: Border.all(color: const Color(0xFFFFCDD2), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('⚠️ ${prov.fetchError}',
                  style:
                      const TextStyle(color: Color(0xFFC62828), fontSize: 14)),
            ),
          ],
          const SizedBox(height: 16),

          // ── Next draw countdown ───────────────────────────
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SUSUNOD NA DRAW',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                      letterSpacing: 1.5)),
              const SizedBox(height: 14),
              if (nextDraw != null) ...[
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${nextDraw.emoji} ${nextDraw.label}',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            const Text('Jackpot: ₱4,000',
                                style: TextStyle(
                                    fontSize: 15, color: AppColors.textMid)),
                          ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: nextDraw.minsUntil <= 30
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFF9FBE7),
                          border: Border.all(
                            color: nextDraw.minsUntil <= 30
                                ? AppColors.amber
                                : const Color(0xFFAED581),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          Text(
                            nextDraw.minsUntil <= 30
                                ? '⚡ MALAPIT NA!'
                                : '⏰ COUNTDOWN',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: nextDraw.minsUntil <= 30
                                    ? AppColors.accent
                                    : const Color(0xFF558B2F),
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCountdown(nextDraw.minsUntil),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: nextDraw.minsUntil <= 30
                                    ? AppColors.primary
                                    : const Color(0xFF33691E)),
                          ),
                        ]),
                      ),
                    ]),
              ] else
                const Text(
                    '🌅 Tapos na ang lahat ng draw ngayon.\nBumalik bukas!',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.textMid, height: 1.8)),
            ]),
          ),
          const SizedBox(height: 16),

          // ── How to play ───────────────────────────────────
          const _HowToPlay(),
          const SizedBox(height: 24),

          // ── Footer ────────────────────────────────────────
          Center(
              child: Column(children: [
            const Text('Manaya nang responsable · 18 taon pataas lamang',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('Para sa opisyal na resulta: pcso.gov.ph',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
            const SizedBox(height: 4),
            Text('Developed by Mark Spencer D. Montalbo',
                style: TextStyle(
                    color: Colors.purple[200],
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Individual draw result row ────────────────────────────────
class _DrawResultRow extends StatelessWidget {
  final DrawSlot slot;
  final String combo;
  final int? winners;
  final bool isLatest;

  const _DrawResultRow(
      {required this.slot,
      required this.combo,
      this.winners,
      required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final parts = combo.split('-');
    final num1 = int.tryParse(parts[0]) ?? 0;
    final num2 = int.tryParse(parts[1]) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLatest ? const Color(0xFFFFF8E1) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isLatest ? AppColors.amber : const Color(0xFFEEEEEE),
            width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(slot.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DRAW',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600])),
              Text(slot.label,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
            ]),
          ]),
          Row(children: [
            LottoBall(number: num1, size: 60),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('–',
                  style: TextStyle(fontSize: 18, color: Color(0xFFCCCCCC))),
            ),
            LottoBall(number: num2, size: 60),
          ]),
        ]),
        if (winners != null) ...[
          const SizedBox(height: 8),
          WinnersBadge(count: winners!),
        ],
      ]),
    );
  }
}

// ── How to play ───────────────────────────────────────────────
class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeading('📖 Paano Laruin ang EZ2 / 2D Lotto',
              fontSize: 19),
          const SizedBox(height: 14),
          const Text(
            'Ang 2D Lotto ay may tatlong draw bawat araw — 2PM, 5PM, at 9PM. '
            'Pumili ng dalawang numero mula 1 hanggang 31 at itugma ang mga ito '
            'sa tamang pagkakasunod para manalo.',
            style:
                TextStyle(fontSize: 16, color: AppColors.textMid, height: 1.8),
          ),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(
                child: _PlayTypeCard(
                    icon: '🎯',
                    name: 'Straight',
                    desc: 'Eksaktong pagkakasunod',
                    prize: '₱4,000 / ₱10 taya')),
            SizedBox(width: 12),
            Expanded(
                child: _PlayTypeCard(
                    icon: '🔄',
                    name: 'Rambolito',
                    desc: 'Kahit anong pagkakasunod',
                    prize: '₱2,000 / ₱10 taya')),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              border: Border.all(color: const Color(0xFFFFCC02), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Odds: 1 sa 961 (Straight) · 1 sa 465 (Rambolito)',
                      style: TextStyle(fontSize: 14, color: AppColors.textMid)),
                  SizedBox(height: 4),
                  Text('Presyo ng taya: ₱10 bawat kombinasyon',
                      style: TextStyle(fontSize: 14, color: AppColors.textMid)),
                ]),
          ),
        ]),
      );
}

class _PlayTypeCard extends StatelessWidget {
  final String icon, name, desc, prize;
  const _PlayTypeCard(
      {required this.icon,
      required this.name,
      required this.desc,
      required this.prize});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(name,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(fontSize: 13, color: AppColors.textMid)),
          const SizedBox(height: 8),
          Text(prize,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ]),
      );
}
