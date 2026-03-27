// lib/screens/ticket_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api_service.dart';
import '../app_provider.dart';
import '../constants.dart';
import '../helpers.dart' show checkTicket;
import '../models.dart';
import '../widgets/common.dart';
import '../responsive.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _picker = ImagePicker();

  _Mode _mode = _Mode.idle;
  File? _imageFile;
  Map<String, dynamic>? _ticketInfo;
  List<TicketMatch>? _matches;
  String? _error;

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
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;

      final file = File(xfile.path);
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = xfile.mimeType ?? 'image/jpeg';

      setState(() {
        _imageFile = file;
        _mode = _Mode.checking;
        _error = null;
      });

      final info = await ApiService.readTicketImage(b64, mime);
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

      setState(() {
        _ticketInfo = info;
        _matches =
            checkTicket(numbers, _allRows, dateFilter: date, drawFilter: draw);
        _mode = _Mode.result;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _mode = _Mode.idle;
      });
    }
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
    setState(() {
      _ticketInfo = {'numbers': combo};
      _matches = checkTicket(combo, _allRows,
          dateFilter: _manualDate, drawFilter: _manualDraw);
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F0E8),
      body: SafeArea(
        child: switch (_mode) {
          _Mode.checking => _CheckingView(imageFile: _imageFile),
          _Mode.result => _ResultView(
              ticketInfo: _ticketInfo!,
              matches: _matches!,
              imageFile: _imageFile,
              onReset: _reset),
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
        },
      ),
    );
  }
}

enum _Mode { idle, checking, result }

// ── Shared header — matches other screens ─────────────────────
class _ScreenHeader extends StatelessWidget {
  final String title, subtitle;
  final Color color;
  const _ScreenHeader(
      {required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: color,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        context.headerPaddingTop,
        context.horizontalPadding,
        context.headerPaddingBottom,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: Colors.white,
                fontSize: context.titleFontSize,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: context.subtitleFontSize)),
      ]),
    );
  }
}

// ── Checking view ─────────────────────────────────────────────
class _CheckingView extends StatelessWidget {
  final File? imageFile;
  const _CheckingView({this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ScreenHeader(
          title: 'TSEK ANG TIKET',
          subtitle: 'Sinusuri ang iyong tiket...',
          color: const Color(0xFF784212)),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (imageFile != null) ...[
                ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(imageFile!,
                        height: 160, fit: BoxFit.contain)),
                const SizedBox(height: 24),
              ],
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF784212).withValues(alpha: 0.1)),
                child: const Center(
                    child: Text('🔍', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 20),
              const Text('Binabasa ang tiket...',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF784212))),
              const SizedBox(height: 8),
              Text('Sandali lang po...',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
              const SizedBox(height: 28),
              const CircularProgressIndicator(color: Color(0xFF784212)),
            ]),
          ),
        ),
      ),
    ]);
  }
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorder =
        isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey.shade200;

    final numbers = ticketInfo['numbers'] as String? ?? '??-??';
    final parts = numbers.split('-');
    final num1 = int.tryParse(parts[0]) ?? 0;
    final num2 = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final won = matches.isNotEmpty;
    final total = matches.fold<int>(0, (s, m) => s + m.prize);

    return Column(children: [
      _ScreenHeader(
        title: won ? 'NANALO KAYO! 🏆' : 'RESULTA NG TIKET',
        subtitle: won
            ? 'Congratulations! Pumunta sa PCSO para i-claim.'
            : 'Tingnan ang resulta ng inyong tiket',
        color: won ? const Color(0xFF1B5E20) : const Color(0xFF784212),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Ticket balls
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: won ? const Color(0xFF4CAF50) : cardBorder,
                    width: won ? 2 : 1),
              ),
              child: Column(children: [
                Text('INYONG TIKET',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                        letterSpacing: 2)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  LottoBall(number: num1, size: 90, win: won),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('—',
                          style: TextStyle(
                              fontSize: 38,
                              color: isDarkMode
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                              fontWeight: FontWeight.w200))),
                  LottoBall(number: num2, size: 90, win: won),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Win/loss result
            if (won) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  const Text('NANALO KAYO!',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('₱${_fmtPrize(total)}',
                      style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF69F0AE))),
                ]),
              ),
              const SizedBox(height: 12),
              ...matches.map((m) => _WinRow(match: m)),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder)),
                child: Column(children: [
                  const Text('😔', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('Hindi pa nanalo',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDarkMode
                              ? Colors.grey.shade300
                              : Color(0xFF555555))),
                  const SizedBox(height: 6),
                  Text('Huwag sumuko — subukan ulit!',
                      style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade500)),
                ]),
              ),
            ],

            if (imageFile != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child:
                      Image.file(imageFile!, fit: BoxFit.contain, height: 180)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('MAG-CHECK NG BAGONG TIKET',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF784212),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ]);
  }

  static String _fmtPrize(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _WinRow extends StatelessWidget {
  final TicketMatch match;
  const _WinRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: const Color(0xFFA5D6A7), width: 2),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(match.date,
<<<<<<< HEAD
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(match.drawLabel,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
=======
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : Colors.black)),
            Text(match.draw,
                style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600)),
>>>>>>> 040d0d8d8116ae221e5f6e6341a7441b44ce6370
            Text('Resulta: ${match.combo}',
                style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade500)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: match.isStraight ? AppColors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(match.isStraight ? 'Straight' : 'Rambolito',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            Text('₱${match.prize}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }
}

// ── Idle view ─────────────────────────────────────────────────
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorder =
        isDarkMode ? const Color(0xFF3E3E3E) : Colors.grey.shade200;

    final dateOptions = allRows
        .where((r) => r.hasAnyResult)
        .map((r) => r.date)
        .toSet()
        .toList();

    return Column(children: [
      // Header — uniform with other screens
      _ScreenHeader(
          title: 'TSEK ANG TIKET',
          subtitle: 'Suriin kung nanalo ka sa EZ2',
          color: const Color(0xFF784212)),

      Expanded(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              context.horizontalPadding, 16, context.horizontalPadding, 32),
          children: [
            // Error banner
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    border:
                        Border.all(color: const Color(0xFFE57373), width: 2),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.warning_rounded,
                      color: Color(0xFFC62828), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(error!,
                          style: const TextStyle(
                              color: Color(0xFFC62828), fontSize: 14))),
                ]),
              ),
              const SizedBox(height: 14),
            ],

            // Camera / Gallery buttons
            Row(children: [
              Expanded(
                  child: _ActionCard(
                      icon: Icons.camera_alt_rounded,
                      label: 'I-scan ang\nTiket',
                      color: const Color(0xFF784212),
                      onTap: onPickCamera)),
              const SizedBox(width: 12),
              Expanded(
                  child: _ActionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'Pumili sa\nGallery',
                      color: const Color(0xFF5D4037),
                      onTap: onPickGallery)),
            ]),
            const SizedBox(height: 20),

            // Divider
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('O I-TYPE',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400))),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 20),

            // Manual entry card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkMode ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Number inputs
                    const Text('NUMERO NG TIKET',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF784212),
                            letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: _NumBox(label: 'UNANG NUMERO', ctrl: ctrlA)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('—',
                              style: TextStyle(
                                  fontSize: 32,
                                  color: Colors.grey.shade300,
                                  fontWeight: FontWeight.w200))),
                      Expanded(
                          child: _NumBox(
                              label: 'PANGALAWANG NUMERO', ctrl: ctrlB)),
                    ]),
                    const SizedBox(height: 20),

                    // Date filter
                    const Text('PETSA NG TIKET',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF784212),
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: manualDate,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFFFF8F5),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDDDDD))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD), width: 1.5)),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('Lahat ng Petsa')),
                        ...dateOptions.take(60).map(
                            (d) => DropdownMenuItem(value: d, child: Text(d))),
                      ],
                      onChanged: (v) => onDateChange(v ?? 'all'),
                    ),
                    const SizedBox(height: 16),

                    // Draw time filter
                    const Text('DRAW TIME',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF784212),
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final entry in [
                        ('all', 'Lahat'),
                        ('2pm', '2 PM'),
                        ('5pm', '5 PM'),
                        ('9pm', '9 PM')
                      ]) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onDrawChange(entry.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: manualDraw == entry.$1
                                    ? const Color(0xFF784212)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(entry.$2,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: manualDraw == entry.$1
                                          ? Colors.white
                                          : const Color(0xFF666666))),
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onManualCheck,
                        icon: const Icon(Icons.search_rounded, size: 22),
                        label: const Text('I-CHECK ANG TIKET',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF784212),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                          shadowColor:
                              const Color(0xFF784212).withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ]),
            ),

            const SizedBox(height: 20),
            // Help note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded,
                    size: 18,
                    color: isDarkMode
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Ang mga resulta ay base sa data mula sa Supabase database. I-type ang numero ng iyong tiket para malaman kung nanalo ka.',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                            height: 1.5))),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ── Action card (camera/gallery) ──────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.3)),
        ]),
      ),
    );
  }
}

// ── Number input box ──────────────────────────────────────────
class _NumBox extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _NumBox({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF999999),
              letterSpacing: 0.5)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Color(0xFF3E1000)),
        decoration: InputDecoration(
          hintText: '01–31',
          hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade400),
          filled: true,
          fillColor: const Color(0xFFFFF8F5),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0C9BF), width: 2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF784212), width: 2.5)),
        ),
      ),
    ]);
  }
}
