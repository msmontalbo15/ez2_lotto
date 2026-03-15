// lib/screens/ticket_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../app_provider.dart';
import '../constants.dart';
import '../helpers.dart';
import '../models.dart';
import '../widgets/common.dart';

// ── Replace with your Anthropic API key ──────────────────────
// In production, proxy this through your Vercel API route instead
// of embedding the key in the app.
const _kAnthropicKey = 'sk-ant-YOUR_KEY_HERE';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _picker = ImagePicker();

  // State
  _Mode _mode = _Mode.idle;
  File? _imageFile;
  Map<String, dynamic>? _ticketInfo;
  List<TicketMatch>? _matches;
  String? _error;

  // Manual entry
  final _ctrlA = TextEditingController();
  final _ctrlB = TextEditingController();
  String _manualDate = 'all';
  String _manualDraw = 'all';

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    super.dispose();
  }

  List<DayResult> get _allRows => context.read<AppProvider>().allRows;

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;

    final file = File(xfile.path);
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    final mime = xfile.mimeType ?? 'image/jpeg';

    setState(() {
      _imageFile = file;
      _mode = _Mode.checking;
      _error = null;
    });

    final info = await ApiService.readTicketImage(base64, mime, _kAnthropicKey);
    if (info == null) {
      setState(() {
        _error = 'Hindi ma-read ang tiket. I-type na lang ang numero.';
        _mode = _Mode.idle;
      });
      return;
    }

    final numbers = info['numbers'] as String?;
    if (numbers == null ||
        numbers == 'null' ||
        !RegExp(r'^\d{2}-\d{2}$').hasMatch(numbers)) {
      setState(() {
        _error = 'Hindi nakita ang numero sa tiket.';
        _mode = _Mode.idle;
      });
      return;
    }

    final date = (info['date'] as String? ?? 'null') == 'null'
        ? 'all'
        : (info['date'] as String? ?? 'all');
    final draw = (info['draw'] as String? ?? 'unknown') == 'unknown'
        ? 'all'
        : (info['draw'] as String? ?? 'all');

    final matches =
        checkTicket(numbers, _allRows, dateFilter: date, drawFilter: draw);
    setState(() {
      _ticketInfo = info;
      _matches = matches;
      _mode = _Mode.result;
    });
  }

  void _manualCheck() {
    final a = _ctrlA.text.trim().padLeft(2, '0');
    final b = _ctrlB.text.trim().padLeft(2, '0');
    final n1 = int.tryParse(a) ?? 0;
    final n2 = int.tryParse(b) ?? 0;
    if (n1 < 1 || n1 > 31 || n2 < 1 || n2 > 31) {
      setState(() => _error = 'Ang mga numero ay 01–31 lamang.');
      return;
    }
    final combo = '${a.padLeft(2, "0")}-${b.padLeft(2, "0")}';
    final matches = checkTicket(combo, _allRows,
        dateFilter: _manualDate, drawFilter: _manualDraw);
    setState(() {
      _ticketInfo = {'numbers': combo};
      _matches = matches;
      _mode = _Mode.result;
      _error = null;
    });
  }

  void _reset() => setState(() {
        _mode = _Mode.idle;
        _imageFile = null;
        _ticketInfo = null;
        _matches = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      _Mode.checking => _CheckingView(imageFile: _imageFile),
      _Mode.result => _ResultView(
          ticketInfo: _ticketInfo!,
          matches: _matches!,
          imageFile: _imageFile,
          onReset: _reset,
        ),
      _Mode.idle => _IdleView(
          error: _error,
          ctrlA: _ctrlA,
          ctrlB: _ctrlB,
          manualDate: _manualDate,
          manualDraw: _manualDraw,
          allRows: _allRows,
          onPickCamera: () => _pickImage(ImageSource.camera),
          onPickGallery: () => _pickImage(ImageSource.gallery),
          onDateChange: (v) => setState(() => _manualDate = v),
          onDrawChange: (v) => setState(() => _manualDraw = v),
          onManualCheck: _manualCheck,
        ),
    };
  }
}

enum _Mode { idle, checking, result }

// ── Checking view ─────────────────────────────────────────────
class _CheckingView extends StatelessWidget {
  final File? imageFile;
  const _CheckingView({this.imageFile});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (imageFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(imageFile!, height: 180, fit: BoxFit.contain),
              ),
              const SizedBox(height: 24),
            ],
            const Text('🔍', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Binabasa ang tiket...',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            const SizedBox(height: 8),
            Text('Sandali lang po...',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary),
          ]),
        ),
      );
}

// ── Result view ───────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final Map<String, dynamic> ticketInfo;
  final List<TicketMatch> matches;
  final File? imageFile;
  final VoidCallback onReset;

  const _ResultView(
      {required this.ticketInfo,
      required this.matches,
      this.imageFile,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    final numbers = ticketInfo['numbers'] as String? ?? '??-??';
    final parts = numbers.split('-');
    final num1 = int.tryParse(parts[0]) ?? 0;
    final num2 = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final won = matches.isNotEmpty;
    final totalPrize = matches.fold<int>(0, (sum, m) => sum + m.prize);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ticket display
        AppCard(
          color: won ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA),
          borderColor: won ? AppColors.green : Colors.grey[300],
          borderWidth: 3,
          child: Column(children: [
            Text('INYONG TIKET',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[600],
                    letterSpacing: 2)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              LottoBall(number: num1, size: 90, win: won),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('—',
                    style: TextStyle(
                        fontSize: 38,
                        color: Color(0xFFBBBBBB),
                        fontWeight: FontWeight.w200)),
              ),
              LottoBall(number: num2, size: 90, win: won),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Won / Lost
        if (won) ...[
          AppCard(
            color: const Color(0xFF1B5E20),
            borderColor: const Color(0xFF1B5E20),
            child: Column(children: [
              const Text('🏆', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 10),
              const Text('NANALO KAYO!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                  '₱${totalPrize.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF69F0AE))),
            ]),
          ),
          const SizedBox(height: 12),
          ...matches.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFA5D6A7), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.date} — ${m.draw}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.green)),
                            Text('Resulta: ${m.combo}',
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.textMid)),
                          ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: m.isStraight ? AppColors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          '${m.isStraight ? "Straight" : "Rambolito"}\n₱${m.prize.toString()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
              )),
        ] else ...[
          AppCard(
            borderColor: Colors.grey[300],
            child: Column(children: [
              const Text('😔', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 10),
              const Text('Hindi pa nanalo',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF555555))),
              const SizedBox(height: 6),
              const Text('Huwag sumuko — subukan ulit!',
                  style: TextStyle(fontSize: 16, color: AppColors.textMid)),
            ]),
          ),
        ],
        const SizedBox(height: 16),

        if (imageFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(imageFile!, fit: BoxFit.contain, height: 200),
          ),
          const SizedBox(height: 16),
        ],

        PrimaryButton(
            label: '🔄 Mag-check ng Bagong Tiket', onPressed: onReset),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Idle / entry view ─────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final String? error;
  final TextEditingController ctrlA, ctrlB;
  final String manualDate, manualDraw;
  final List<DayResult> allRows;
  final VoidCallback onPickCamera, onPickGallery, onManualCheck;
  final void Function(String) onDateChange, onDrawChange;

  const _IdleView({
    this.error,
    required this.ctrlA,
    required this.ctrlB,
    required this.manualDate,
    required this.manualDraw,
    required this.allRows,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onManualCheck,
    required this.onDateChange,
    required this.onDrawChange,
  });

  @override
  Widget build(BuildContext context) {
    final dateOptions = allRows
        .where((r) => r.hasAnyResult)
        .map((r) => r.date)
        .toSet()
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
            child: Column(children: [
          SizedBox(height: 8),
          Text('🎫', style: TextStyle(fontSize: 56)),
          SizedBox(height: 8),
          Text('I-check ang Inyong Tiket',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark)),
          SizedBox(height: 4),
          Text('I-upload ang larawan o i-type ang numero',
              style: TextStyle(fontSize: 15, color: AppColors.textMid)),
          SizedBox(height: 20),
        ])),

        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              border: Border.all(color: const Color(0xFFE57373), width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('⚠️ $error',
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 14)),
          ),
          const SizedBox(height: 12),
        ],

        // Camera buttons
        Row(children: [
          Expanded(
            child: _PickButton(
              icon: '📷',
              label: 'Kamera',
              onTap: onPickCamera,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PickButton(
              icon: '🖼️',
              label: 'Gallery',
              onTap: onPickGallery,
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Divider
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('O KAYA',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400])),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 20),

        // Manual entry card
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✏️ I-type ang Numero',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 16),
            Row(children: [
              _BigNumInput(label: 'UNANG NUMERO', ctrl: ctrlA),
              const SizedBox(width: 12),
              _BigNumInput(label: 'PANGALAWANG NUMERO', ctrl: ctrlB),
            ]),
            const SizedBox(height: 16),

            // Date filter
            const Text('PETSA NG TIKET',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMid)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: manualDate,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDDDDD), width: 2)),
              ),
              items: [
                const DropdownMenuItem(
                    value: 'all', child: Text('Lahat ng Petsa')),
                ...dateOptions
                    .map((d) => DropdownMenuItem(value: d, child: Text(d))),
              ],
              onChanged: (v) => onDateChange(v ?? 'all'),
            ),
            const SizedBox(height: 14),

            // Draw time filter
            const Text('DRAW TIME',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMid)),
            const SizedBox(height: 6),
            Row(children: [
              for (final (v, l) in [
                ('all', 'Lahat'),
                ('2pm', '2 PM'),
                ('5pm', '5 PM'),
                ('9pm', '9 PM')
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onDrawChange(v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: manualDraw == v
                            ? AppColors.primary
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(l,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: manualDraw == v
                                  ? Colors.white
                                  : const Color(0xFF555555))),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 18),
            PrimaryButton(
                label: '🎯 I-check ang Tiket', onPressed: onManualCheck),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _PickButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            border: Border.all(
                color: AppColors.amber, width: 3, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent)),
          ]),
        ),
      );
}

class _BigNumInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _BigNumInput({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMid)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3E1000)),
            decoration: InputDecoration(
              hintText: '01–31',
              filled: true,
              fillColor: const Color(0xFFFFFDE7),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.amber, width: 3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 3),
              ),
            ),
          ),
        ]),
      );
}
