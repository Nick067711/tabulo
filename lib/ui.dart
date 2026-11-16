import 'package:flutter/material.dart';

import 'state.dart';

class C {
  static const cream = Color(0xFFFFF7EC);
  static const ink = Color(0xFF1F2544);
  static const inkSoft = Color(0xFF4A5072);
  static const sand = Color(0xFFF0E4CF);
  static const line = Color(0xFFE9DCC6);
  static const paper = Color(0xFFF7EEDD);
  static const green = Color(0xFF1F9D55);
  static const greenD = Color(0xFF15703C);
  static const greenBg = Color(0xFFE6F6EC);
  static const blue = Color(0xFF2F6FED);
  static const blueD = Color(0xFF1F4FB0);
  static const orange = Color(0xFFE8590C);
  static const orangeD = Color(0xFFA83E06);
  static const purple = Color(0xFF7C3AED);
  static const purpleD = Color(0xFF5521B5);
  static const yellow = Color(0xFFFFC531);
  static const yellowD = Color(0xFFD9A21A);
  static const pink = Color(0xFFE0356B);
  static const pinkD = Color(0xFFA51F4B);
  static const red = Color(0xFFC92A2A);
  static const redBg = Color(0xFFFDECEC);
  static const navy2 = Color(0xFF2E3561);
  static const navyD = Color(0xFF151A36);
  static const soft2 = Color(0xFFC5CAE6);

  static const avatars = [yellow, blue, pink, green, purple, orange];
  static const avatarsD = [yellowD, blueD, pinkD, greenD, purpleD, orangeD];

  static Color avatar(int i) => avatars[i % avatars.length];
  static Color avatarText(int i) => i % avatars.length == 0 ? ink : Colors.white;

  static Color op(Op op) => switch (op) {
        Op.add => green,
        Op.sub => blue,
        Op.mul => orange,
        Op.div => purple,
      };

  static Color opD(Op op) => switch (op) {
        Op.add => greenD,
        Op.sub => blueD,
        Op.mul => orangeD,
        Op.div => purpleD,
      };
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, super.notifier, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

TextStyle ts(double size, {Color color = C.ink, FontWeight weight = FontWeight.w900, double? height}) =>
    TextStyle(fontSize: size, color: color, fontWeight: weight, height: height);

/// Text style for digits inside fixed-size boxes: the glyphs sit in the vertical middle.
TextStyle tsBox(double size, {Color color = C.ink}) =>
    ts(size, color: color, height: 1.0).copyWith(leadingDistribution: TextLeadingDistribution.even);

/// A "toy block" button with a solid shadow underneath that sinks when pressed.
class Chunky extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color shadow;
  final Color? border;
  final double borderWidth;
  final double radius;
  final double depth;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry? alignment;

  const Chunky({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.white,
    this.shadow = C.line,
    this.border,
    this.borderWidth = 2,
    this.radius = 20,
    this.depth = 5,
    this.height,
    this.width,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
  });

  @override
  State<Chunky> createState() => _ChunkyState();
}

class _ChunkyState extends State<Chunky> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final shift = _down ? widget.depth - 1 : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.depth),
        child: Transform.translate(
          offset: Offset(0, shift),
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: widget.padding,
            alignment: widget.alignment,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.radius),
              border: widget.border == null ? null : Border.all(color: widget.border!, width: widget.borderWidth),
              boxShadow: [
                BoxShadow(color: widget.shadow, offset: Offset(0, _down ? 1 : widget.depth)),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Square button with an icon, used in top bars.
class IconBox extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;
  final String? tooltip;
  const IconBox({super.key, required this.icon, this.onTap, this.dark = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: dark ? C.navy2 : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: dark ? null : Border.all(color: C.line, width: 2),
          ),
          child: Icon(icon, color: dark ? Colors.white : C.ink, size: 24),
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> actions;
  final bool dark;
  final IconData backIcon;
  final VoidCallback? onBack;
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
    this.dark = false,
    this.backIcon = Icons.chevron_left_rounded,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : C.ink;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconBox(
            icon: backIcon,
            dark: dark,
            tooltip: 'back',
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          if (badge != null) ...[badge!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(22, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: ts(14, color: dark ? C.soft2 : C.inkSoft, weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class OpBadge extends StatelessWidget {
  final Op op;
  final double size;
  const OpBadge({super.key, required this.op, this.size = 46});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: C.op(op),
        borderRadius: BorderRadius.circular(size * 0.33),
        boxShadow: [BoxShadow(color: C.opD(op), offset: const Offset(0, 4))],
      ),
      child: Text(app.sign(op), style: ts(size * 0.62, color: Colors.white, height: 1.0)),
    );
  }
}

class Avatar extends StatelessWidget {
  final Profile p;
  final double size;
  const Avatar({super.key, required this.p, this.size = 46});
  @override
  Widget build(BuildContext context) {
    final initial = p.name.isEmpty ? '?' : String.fromCharCode(p.name.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: C.avatar(p.color), shape: BoxShape.circle),
      child: Text(initial, style: ts(size * 0.45, color: C.avatarText(p.color))),
    );
  }
}

/// Selectable chip button (on = filled).
class Pick extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color color;
  final Color dark;
  final double height;
  final double fontSize;
  final Widget? child;
  const Pick({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
    this.color = C.orange,
    this.dark = C.orangeD,
    this.height = 50,
    this.fontSize = 18,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Chunky(
      onTap: onTap,
      height: height,
      depth: 4,
      radius: 15,
      color: on ? color : Colors.white,
      shadow: on ? dark : C.line,
      border: on ? color : C.line,
      child: child ??
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(label, style: ts(fontSize, color: on ? Colors.white : C.ink)),
            ),
          ),
    );
  }
}

/// Row of equally wide children with gaps.
class Gap extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const Gap({super.key, required this.children, this.gap = 10});
  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(SizedBox(width: gap));
      out.add(Expanded(child: children[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SectionLabel(this.text, {super.key, this.color = C.ink});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: ts(17, color: color)));
}

class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color == Colors.white ? C.sand : color, width: 2),
        ),
        child: child,
      );
}

/// Number keypad: 1–9, delete, 0, OK.
class Keypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onOk;
  final bool okEnabled;
  final bool dark;
  final double keyHeight;
  final bool wide; // 6 columns x 2 rows
  final String okLabel;
  final IconData? extraIcon;
  final VoidCallback? onExtra;

  const Keypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.onOk,
    this.okEnabled = true,
    this.dark = false,
    this.keyHeight = 66,
    this.wide = false,
    this.okLabel = 'OK',
    this.extraIcon,
    this.onExtra,
  });

  Widget _key(String label, VoidCallback onTap, {bool del = false}) {
    final bg = dark ? (del ? const Color(0xFF3A4272) : C.navy2) : (del ? C.paper : Colors.white);
    return Chunky(
      onTap: onTap,
      height: keyHeight,
      depth: 5,
      radius: 20,
      color: bg,
      shadow: dark ? C.navyD : C.line,
      border: dark ? null : C.line,
      child: Text(label, textScaler: TextScaler.noScaling, style: tsBox(keyHeight * 0.5, color: dark ? Colors.white : C.ink)),
    );
  }

  Widget _iconKey(IconData icon, VoidCallback onTap) {
    return Chunky(
      onTap: onTap,
      height: keyHeight,
      depth: 5,
      radius: 20,
      color: dark ? const Color(0xFF3A4272) : C.paper,
      shadow: dark ? C.navyD : C.line,
      border: dark ? null : C.line,
      child: Icon(icon, size: keyHeight * 0.45, color: dark ? Colors.white : C.ink),
    );
  }

  Widget _ok() {
    final on = okEnabled;
    return Chunky(
      onTap: onOk,
      height: keyHeight,
      depth: 5,
      radius: 20,
      color: on ? C.green : (dark ? const Color(0xFF2C5E46) : const Color(0xFFA9D8BC)),
      shadow: on ? C.greenD : (dark ? const Color(0xFF1C3F2E) : const Color(0xFF8CC3A3)),
      child: Text(okLabel, textScaler: TextScaler.noScaling, style: tsBox(keyHeight * 0.4, color: on ? Colors.white : Colors.white70)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    final keys = <Widget>[
      for (final d in digits.take(9)) _key(d, () => onDigit(d)),
    ];
    final del = _iconKey(Icons.backspace_outlined, onDelete);
    final zero = _key('0', () => onDigit('0'));
    if (wide) {
      final extra = extraIcon != null && onExtra != null ? _iconKey(extraIcon!, onExtra!) : null;
      final row1 = <Widget>[...keys.take(5), del];
      final row2 = <Widget>[...keys.skip(5), zero, extra ?? _ok()];
      return Column(children: [Gap(gap: 8, children: row1), const SizedBox(height: 6), Gap(gap: 8, children: row2)]);
    }
    return Column(
      children: [
        Gap(children: keys.sublist(0, 3)),
        const SizedBox(height: 6),
        Gap(children: keys.sublist(3, 6)),
        const SizedBox(height: 6),
        Gap(children: keys.sublist(6, 9)),
        const SizedBox(height: 6),
        Gap(children: [del, zero, _ok()]),
      ],
    );
  }
}

/// Short ✓ / ✗ feedback drawn over the task card.
class FeedbackOverlay extends StatelessWidget {
  final bool ok;
  final String? text;
  final bool dark;
  final double radius;
  const FeedbackOverlay({super.key, required this.ok, this.text, this.dark = false, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? (ok ? const Color(0xEB1F6E46) : const Color(0xEB7A2230))
        : (ok ? const Color(0xF0E6F6EC) : const Color(0xF0FDECEC));
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(color: ok ? C.green : C.red, shape: BoxShape.circle),
              child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 76),
            ),
            if (text != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text!,
                    style: ts(30, color: dark ? Colors.white : (ok ? C.greenD : const Color(0xFFA61E1E))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LockDot extends StatelessWidget {
  final Color color;
  const LockDot({super.key, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(Icons.lock_rounded, size: 17, color: color),
      );
}

Future<bool> confirmDialog(BuildContext context, String title, String text, String yes, String no,
    {bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(title, style: ts(21)),
      content: Text(text, style: ts(15, color: C.inkSoft, weight: FontWeight.w700, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(no, style: ts(16))),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(yes, style: ts(16, color: danger ? C.red : C.green)),
        ),
      ],
    ),
  );
  return r == true;
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text, style: ts(15, color: Colors.white, weight: FontWeight.w700))),
  );
}

/// Shows "a op b = ?" with an answer box in the right place.
class TaskLine extends StatelessWidget {
  final Task task;
  final String typed;
  final double size;
  final Color color;
  final Color boxColor;
  final Color signColor;
  const TaskLine({
    super.key,
    required this.task,
    required this.typed,
    this.size = 54,
    this.color = C.ink,
    this.boxColor = C.orange,
    this.signColor = C.orange,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final style = ts(size, color: color);
    Widget box() => Container(
          constraints: BoxConstraints(minWidth: size * 1.7),
          height: size * 1.55,
          padding: EdgeInsets.symmetric(horizontal: size * 0.2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: boxColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(size * 0.4),
            border: Border.all(color: boxColor, width: 4),
          ),
          child: Text(typed.isEmpty ? '?' : typed,
              textScaler: TextScaler.noScaling, style: ts(size, color: boxColor, height: 1.0).copyWith(leadingDistribution: TextLeadingDistribution.even)),
        );
    Text txt(String v, TextStyle st) => Text(v, textScaler: TextScaler.noScaling, style: st);
    final parts = <Widget>[
      txt('${task.a}', style),
      txt(' ${app.sign(task.op)} ', ts(size, color: signColor)),
      task.missing ? box() : txt('${task.b}', style),
      txt(' = ', style),
      task.missing ? txt('${task.result}', style) : box(),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
  }
}
