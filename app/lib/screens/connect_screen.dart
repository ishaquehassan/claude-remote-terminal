import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/terminal_service.dart';
import '../services/language_service.dart';
import '../services/discovery_service.dart';
import '../l10n.dart';
import 'sessions_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8765');
  final _tokenCtrl = TextEditingController(text: 'xrlabs-remote-terminal-2024');

  bool _scanning = false;
  int _scanDone = 0;
  int _scanTotal = 254;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('host') ?? '';
    setState(() {
      _hostCtrl.text = host;
      _portCtrl.text = prefs.getString('port') ?? '8765';
      _tokenCtrl.text = prefs.getString('token') ?? 'xrlabs-remote-terminal-2024';
    });
    if (host.isNotEmpty && mounted) {
      _connect();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host', _hostCtrl.text.trim());
    await prefs.setString('port', _portCtrl.text.trim());
    await prefs.setString('token', _tokenCtrl.text.trim());
  }

  Future<void> _scan() async {
    final s = S(context.read<LanguageService>().isUrdu);
    setState(() { _scanning = true; _scanDone = 0; });

    final results = await DiscoveryService.scan(
      onProgress: (done, total) {
        if (mounted) setState(() { _scanDone = done; _scanTotal = total; });
      },
    );

    if (!mounted) return;
    setState(() => _scanning = false);

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.noServerFound),
          backgroundColor: const Color(0xFF1E2A3A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (results.length == 1) {
      _hostCtrl.text = results.first.host;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.serverFound} ${results.first.host}'),
          backgroundColor: const Color(0xFFE07845).withAlpha(200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1621),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.pickServer, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((r) => ListTile(
            leading: const Icon(Icons.computer, color: Color(0xFFE07845), size: 18),
            title: Text(r.host, style: const TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () => Navigator.pop(context, r.host),
          )).toList(),
        ),
      ),
    );
    if (picked != null) _hostCtrl.text = picked;
  }

  Future<void> _connect() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8765;
    final token = _tokenCtrl.text.trim();

    if (host.isEmpty) {
      final s = S(context.read<LanguageService>().isUrdu);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.enterHostFirst),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _save();
    if (!mounted) return;
    final svc = context.read<TerminalService>();
    await svc.connect(host, port, token);
    // Navigation build() mein hoti hai jab isConnected true ho
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<TerminalService>();
    final lang = context.watch<LanguageService>();
    final s = S(lang.isUrdu);

    if (svc.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SessionsScreen()),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      body: Stack(
        children: [
          // Background gradient circles
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE07845).withAlpha(12),
              ),
            ),
          ),
          Positioned(
            bottom: 60, left: -80,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withAlpha(15),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Language toggle — top right
                  Align(
                    alignment: Alignment.centerRight,
                    child: LangToggle(lang: lang),
                  ),

                  const SizedBox(height: 16),

                  // Logo + title
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE07845), Color(0xFFBF5530)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE07845).withAlpha(80),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.terminal, color: Colors.black, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Claude Remote',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            s.appSubtitle,
                            style: const TextStyle(color: Color(0xFF4A5568), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1621),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E2A3A), width: 1),
                    ),
                    child: Column(
                      children: [
                        // Scan button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _scanning ? null : _scan,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _scanning
                                    ? const Color(0xFF2D3748)
                                    : const Color(0xFFE07845).withAlpha(180),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: _scanning
                                  ? Colors.transparent
                                  : const Color(0xFFE07845).withAlpha(10),
                            ),
                            icon: _scanning
                                ? SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      value: _scanTotal > 0 ? _scanDone / _scanTotal : null,
                                      color: const Color(0xFFE07845),
                                    ),
                                  )
                                : const Icon(Icons.radar, color: Color(0xFFE07845), size: 18),
                            label: Text(
                              _scanning
                                  ? s.scanning(_scanDone, _scanTotal)
                                  : s.scanBtn,
                              style: TextStyle(
                                color: _scanning
                                    ? const Color(0xFF4A5568)
                                    : const Color(0xFFE07845),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: const Color(0xFF1E2A3A))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(s.orManually, style: const TextStyle(color: Color(0xFF2D3748), fontSize: 11)),
                            ),
                            Expanded(child: Divider(color: const Color(0xFF1E2A3A))),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _field('Mac IP / Host', _hostCtrl, hint: '192.168.x.x'),
                        const SizedBox(height: 10),
                        _field('Port', _portCtrl, hint: '8765', number: true),
                        const SizedBox(height: 10),
                        _field('Auth Token', _tokenCtrl, hint: 'token', obscure: true),
                      ],
                    ),
                  ),

                  if (svc.errorMsg != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              svc.errorMsg!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Connect button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (svc.isConnecting || _scanning) ? null : _connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE07845),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF1A2030),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: svc.isConnecting ? 0 : 8,
                        shadowColor: const Color(0xFFE07845).withAlpha(100),
                      ),
                      child: svc.isConnecting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFE07845),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  s.connecting,
                                  style: const TextStyle(color: Color(0xFF4A5568), fontSize: 15),
                                ),
                              ],
                            )
                          : Text(
                              s.connect,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool number = false,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF2D3748)),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E2A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E2A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE07845), width: 1.5),
        ),
      ),
    );
  }
}
