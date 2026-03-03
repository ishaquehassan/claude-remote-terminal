import 'package:flutter/material.dart';
import 'services/language_service.dart';

/// Animated EN / UR pill toggle — drop anywhere in a header
class LangToggle extends StatelessWidget {
  final LanguageService lang;
  const LangToggle({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: lang.toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2030),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2D3748), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Option('EN', !lang.isUrdu),
            _Option('UR', lang.isUrdu),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool active;
  const _Option(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF00FF88).withAlpha(35) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF00FF88) : const Color(0xFF4A5568),
          fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    );
  }
}

class S {
  final bool ur;
  const S(this.ur);

  // Connect screen
  String get appSubtitle => ur ? 'Mac ka terminal, phone pe' : 'Mac terminal on your phone';
  String get scanBtn => ur ? 'Network pe server dhundo' : 'Scan network for server';
  String get orManually => ur ? 'ya manually' : 'or manually';
  String get noServerFound => ur
      ? 'Koi server nahi mila. Mac pe server.py chal raha hai?'
      : 'No server found. Is server.py running on Mac?';
  String get serverFound => ur ? 'Server mila:' : 'Server found:';
  String get pickServer => ur ? 'Server chuno' : 'Pick a server';
  String get enterHostFirst => ur ? 'Pehle scan karo ya host bharo' : 'Scan first or enter a host';
  String get connecting => 'Connecting...';
  String get connect => 'Connect';

  // Sessions screen
  String get sessions => 'Sessions';
  String get disconnect => 'Disconnect';
  String get reconnectingBanner => ur ? 'Server se reconnect ho raha hoon...' : 'Reconnecting to server...';
  String get disconnectedBanner => ur ? 'Server se connection nahi' : 'Server not connected';
  String get reconnecting => 'Reconnecting...';
  String get waitingForServer => ur ? 'Server wapis aane ka wait kar raha hoon' : 'Waiting for server to come back';
  String get noSessions => ur ? 'Koi session nahi' : 'No sessions';
  String get noSessionsHint => ur ? '+ button se naya session kholo' : 'Tap + to create a new session';

  // Terminal screen
  String get openInIterm => ur ? 'iTerm mein kholo' : 'Open in iTerm';
  String get killTitle => ur ? 'Session kill karo?' : 'Kill session?';
  String get killBody => ur ? 'Ye session band ho jayegi.' : 'This session will be terminated.';
  String get cancel => ur ? 'Nahi' : 'Cancel';
  String get kill => ur ? 'Kill karo' : 'Kill';
  String get serverWait => ur ? 'Server ka wait kar raha hoon' : 'Waiting for server...';
  String get disconnected => 'Disconnected';

  // iTerm takeover
  String get itermActive => ur ? 'Session iTerm mein chal rahi hai' : 'Session is open in iTerm';
  String get itermActiveHint => ur ? 'Mac pe kaam karo, wapas aana ho to lelo' : 'Working on Mac? Take back when done';
  String get takeBack => ur ? 'Phone pe wapas lo' : 'Take Back';

  // Scanning
  String scanning(int done, int total) =>
      ur ? 'Scan ho raha hai... ($done/$total)' : 'Scanning... ($done/$total)';
}
