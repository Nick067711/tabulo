import 'dart:math';

import 'package:flutter/material.dart';

import '../logic.dart';
import '../ui.dart';

/// Asks a parent to type a number written in words. Returns true when solved.
class ParentGate extends StatefulWidget {
  const ParentGate({super.key});

  static Future<bool> ask(BuildContext context) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ParentGate()));
    return r == true;
  }

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  final _r = Random();
  late int _target;
  String _val = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newTarget();
  }

  void _newTarget() {
    int n;
    do {
      n = 101 + _r.nextInt(898);
    } while (n % 10 == 0 || (n % 100) ~/ 10 == 0);
    _target = n;
  }

  void _ok() {
    if (_val.isEmpty) return;
    if (int.tryParse(_val) == _target) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _wrong = true;
        _val = '';
        _newTarget();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final words = numberWords(_target, app.lang == 'pl' ? 'pl' : 'en');
    return Scaffold(
      backgroundColor: C.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(app.t('gate_parent_only'), style: ts(15, color: C.soft2, weight: FontWeight.w800))),
                  IconBox(icon: Icons.close_rounded, dark: true, onTap: () => Navigator.of(context).pop(false)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.family_restroom_rounded, color: C.yellow, size: 56),
              const SizedBox(height: 10),
              Text(app.t('gate_title'), style: ts(26, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(app.t('gate_type'), style: ts(16, color: C.soft2, weight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(words, style: ts(24, color: C.yellow), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(minWidth: 170),
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.navy2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _wrong ? const Color(0xFFFF8A8A) : C.yellow, width: 3),
                ),
                child: Text(_val.isEmpty ? '_ _ _' : _val, style: ts(38, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 22,
                child: _wrong
                    ? Text(app.t('gate_wrong'), style: ts(15, color: const Color(0xFFFFB4B4), weight: FontWeight.w800))
                    : null,
              ),
              const Spacer(),
              Keypad(
                dark: true,
                keyHeight: 60,
                okEnabled: _val.isNotEmpty,
                onDigit: (d) => setState(() {
                  if (_val.length < 4) _val += d;
                  _wrong = false;
                }),
                onDelete: () => setState(() {
                  if (_val.isNotEmpty) _val = _val.substring(0, _val.length - 1);
                }),
                onOk: _ok,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
