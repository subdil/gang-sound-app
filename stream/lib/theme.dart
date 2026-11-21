import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBg = Color(0xFF07050D), kPink = Color(0xFFFF2BD6), kCyan = Color(0xFF00F0FF), kAcid = Color(0xFFD7FF1F), kPanel = Color(0xFF130E22);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: c, width: 1.5));
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(primary: kPink, secondary: kCyan, surface: kPanel),
    textTheme: GoogleFonts.rajdhaniTextTheme(base.textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFF0E0A1A), labelStyle: const TextStyle(color: kCyan),
      border: b(kCyan.withOpacity(.5)), enabledBorder: b(kCyan.withOpacity(.5)), focusedBorder: b(kPink),
    ),
  );
}

TextStyle graffiti(double s, {Color c = Colors.white}) => GoogleFonts.bungee(
    fontSize: s, color: c, shadows: [Shadow(color: kPink.withOpacity(.9), blurRadius: 14), const Shadow(color: kCyan, offset: Offset(2.5, 2.5))]);

/// Spray splatter + neon road grid + a neon muscle car on the horizon.
class SprayBg extends StatelessWidget {
  final Widget child;
  const SprayBg({super.key, required this.child});
  @override
  Widget build(BuildContext c) => Stack(children: [Positioned.fill(child: CustomPaint(painter: _Spray())), child]);
}

class _Spray extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = Random(7);
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B0716), Color(0xFF1B0A2E)]).createShader(Offset.zero & s));
    for (final col in [kPink, kCyan, kAcid]) {
      final cx = r.nextDouble() * s.width, cy = r.nextDouble() * s.height * .6;
      for (var i = 0; i < 160; i++) {
        final a = r.nextDouble() * 2 * pi, d = (pow(r.nextDouble(), 2) * 150).toDouble();
        c.drawCircle(Offset(cx + cos(a) * d, cy + sin(a) * d), r.nextDouble() * 2.2 + .3, Paint()..color = col.withOpacity(.08 + r.nextDouble() * .22));
      }
    }
    final hz = s.height * .8, gp = Paint()..color = kCyan.withOpacity(.16)..strokeWidth = 1;
    for (var i = -10; i <= 10; i++) { c.drawLine(Offset(s.width / 2, hz), Offset(s.width / 2 + i * s.width * .18, s.height), gp); }
    for (var i = 1; i < 8; i++) { final y = hz + ((s.height - hz) * pow(i / 8, 2)).toDouble(); c.drawLine(Offset(0, y), Offset(s.width, y), gp); }
    // car
    final w = min(s.width * .7, 520.0), k = w / 100;
    final car = Path()
      ..moveTo(2, 22)..lineTo(6, 16)..lineTo(22, 14)..lineTo(32, 6)..lineTo(58, 6)..lineTo(72, 14)..lineTo(94, 17)..lineTo(98, 22)..lineTo(98, 26)..lineTo(2, 26)..close()
      ..addOval(Rect.fromCircle(center: const Offset(24, 26), radius: 5))
      ..addOval(Rect.fromCircle(center: const Offset(76, 26), radius: 5));
    final p = car.transform(Matrix4.diagonal3Values(k, k, 1).storage).shift(Offset((s.width - w) / 2, hz - 26 * k));
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = kPink.withOpacity(.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = kPink);
  }
  @override
  bool shouldRepaint(_) => false;
}

class NeonBtn extends StatelessWidget {
  final String t; final VoidCallback? onTap; final Color color; final IconData? icon;
  const NeonBtn(this.t, this.onTap, {super.key, this.color = kPink, this.icon});
  @override
  Widget build(BuildContext c) => Opacity(
        opacity: onTap == null ? .4 : 1,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(color: color.withOpacity(.14), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: color.withOpacity(.45), blurRadius: 14)]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, color: color), const SizedBox(width: 10)],
              Flexible(child: Text(t, style: GoogleFonts.bungee(fontSize: 15, color: color), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );
}

class Panel extends StatelessWidget {
  final Widget child; final Color color; final EdgeInsets pad;
  const Panel({super.key, required this.child, this.color = kCyan, this.pad = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: pad,
        decoration: BoxDecoration(color: kPanel.withOpacity(.88), border: Border.all(color: color.withOpacity(.7)), borderRadius: BorderRadius.circular(4)),
        child: child,
      );
}

class Eq extends StatefulWidget {
  final bool active;
  const Eq({super.key, required this.active});
  @override
  State<Eq> createState() => _EqState();
}
class _EqState extends State<Eq> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
        animation: a,
        builder: (_, __) => SizedBox(
          height: 70,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 18; i++)
              Container(
                width: 8, margin: const EdgeInsets.symmetric(horizontal: 2),
                height: widget.active ? 8 + 60 * (.5 + .5 * sin(a.value * 2 * pi * (1 + i % 4) + i)).abs() : 6,
                color: i.isEven ? kPink : kCyan,
              ),
          ]),
        ),
      );
}
