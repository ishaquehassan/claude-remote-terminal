import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../services/terminal_service.dart';
import '../services/language_service.dart';
import '../l10n.dart';

class TerminalScreen extends StatefulWidget {
  final String sessionId;
  const TerminalScreen({super.key, required this.sessionId});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final TerminalController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    _controller = TerminalController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendRaw(String data) {
    context.read<TerminalService>().sendInput(widget.sessionId, data);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<TerminalService>();
    final s = S(context.watch<LanguageService>().isUrdu);
    final session = svc.sessions[widget.sessionId];

    // Session gone aur reconnect bhi nahi ho raha — wapis jao
    if (session == null && !svc.isReconnecting && !_popping) {
      _popping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        backgroundColor: Color(0xFF080B12),
        body: SizedBox.shrink(),
      );
    }

    // Reconnecting ke dauran bhi terminal dikhao (blank rehti hai lekin overlay upar hai)
    final terminal = session?.terminal ?? Terminal(maxLines: 10000);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          svc.sessionNames[widget.sessionId] ?? session?.cmd ?? '...',
          style: const TextStyle(
            color: Color(0xFFE07845),
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
          ),
        ),
        actions: [
          if (!svc.autoOpenSessions.contains(widget.sessionId))
            IconButton(
              icon: const Icon(Icons.laptop_mac, color: Color(0xFFE07845), size: 20),
              tooltip: s.openInIterm,
              onPressed: svc.isConnected
                  ? () => svc.openInIterm(widget.sessionId)
                  : null,
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            onPressed: svc.isConnected
                ? () => _confirmKill(context, svc, s)
                : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: TerminalView(
                  terminal,
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  textStyle: const TerminalStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
                    fontSize: 11.0,
                    height: 1.2,
                  ),
                  theme: const TerminalTheme(
                    cursor: Color(0xFFE07845),
                    selection: Color(0x44E07845),
                    foreground: Color(0xFFE8E8E8),
                    background: Color(0xFF000000),
                    black: Color(0xFF1E1E1E),
                    red: Color(0xFFFF5555),
                    green: Color(0xFF50FA7B),
                    yellow: Color(0xFFF1FA8C),
                    blue: Color(0xFF6272A4),
                    magenta: Color(0xFFFF79C6),
                    cyan: Color(0xFF8BE9FD),
                    white: Color(0xFFBBBBBB),
                    brightBlack: Color(0xFF555555),
                    brightRed: Color(0xFFFF6E6E),
                    brightGreen: Color(0xFF69FF94),
                    brightYellow: Color(0xFFFFFF87),
                    brightBlue: Color(0xFFD6ACFF),
                    brightMagenta: Color(0xFFFF92DF),
                    brightCyan: Color(0xFFA4FFFF),
                    brightWhite: Color(0xFFFFFFFF),
                    searchHitBackground: Color(0x44FFB86C),
                    searchHitBackgroundCurrent: Color(0x88FFB86C),
                    searchHitForeground: Color(0xFFFFFFFF),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
              ),
              ExcludeFocusTraversal(
                child: _ExtraKeysBar(onKey: _sendRaw, focusNode: _focusNode),
              ),
            ],
          ),

          // Reconnecting overlay
          if (!svc.isConnected)
            Positioned.fill(
              child: _ReconnectingOverlay(isReconnecting: svc.isReconnecting, s: s),
            ),

          // iTerm takeover overlay
          if (svc.itermSessions.contains(widget.sessionId))
            Positioned.fill(
              child: _ItermOverlay(
                s: s,
                onTakeBack: () => svc.attachSession(widget.sessionId),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmKill(BuildContext context, TerminalService svc, S s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(s.killTitle, style: const TextStyle(color: Colors.white)),
        content: Text(s.killBody, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () {
              _popping = true;               // build fire ho to extra pop na ho
              Navigator.pop(context);        // dialog band
              Navigator.of(context).pop();   // terminal screen se wapas
              svc.killSession(widget.sessionId);
            },
            child: Text(s.kill, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ReconnectingOverlay extends StatefulWidget {
  final bool isReconnecting;
  final S s;
  const _ReconnectingOverlay({required this.isReconnecting, required this.s});

  @override
  State<_ReconnectingOverlay> createState() => _ReconnectingOverlayState();
}

class _ReconnectingOverlayState extends State<_ReconnectingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Color(0xFFE07845),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _pulse,
              child: Text(
                widget.isReconnecting ? widget.s.reconnecting : widget.s.disconnected,
                style: const TextStyle(
                  color: Color(0xFFE07845),
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (widget.isReconnecting) ...[
              const SizedBox(height: 6),
              Text(
                widget.s.serverWait,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItermOverlay extends StatelessWidget {
  final S s;
  final VoidCallback onTakeBack;
  const _ItermOverlay({required this.s, required this.onTakeBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(210),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE07845).withAlpha(15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE07845).withAlpha(50), width: 1),
              ),
              child: const Icon(Icons.laptop_mac, color: Color(0xFFE07845), size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              s.itermActive,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.itermActiveHint,
              style: const TextStyle(color: Color(0xFF4A5568), fontSize: 12),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onTakeBack,
              icon: const Icon(Icons.phone_android, size: 16),
              label: Text(s.takeBack),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE07845),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraKeysBar extends StatelessWidget {
  final void Function(String) onKey;
  final FocusNode focusNode;
  const _ExtraKeysBar({required this.onKey, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            _key('Tab', '\t'),
            _key('Ctrl+D', '\x04'),
            _key('Ctrl+L', '\x0C'),
            _key('Ctrl+Z', '\x1A'),
            _key('Esc', '\x1B'),
            _key('↑', '\x1B[A'),
            _key('↓', '\x1B[B'),
            _key('←', '\x1B[D'),
            _key('→', '\x1B[C'),
            _key('Home', '\x1B[H'),
            _key('End', '\x1B[F'),
            _key('PgUp', '\x1B[5~'),
            _key('PgDn', '\x1B[6~'),
          ],
        ),
      ),
    );
  }

  Widget _key(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: GestureDetector(
        onTapDown: (_) {
          onKey(value);
          focusNode.requestFocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ),
      ),
    );
  }
}
