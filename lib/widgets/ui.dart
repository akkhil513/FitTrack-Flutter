import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/tokens.dart';

/// Type roles: 12–13 caption, 14 body, 15–16 emphasis, 20 title, 28 display,
/// 40 numeral. Weights 400/500 (600 only for display). Tabular figures for
/// anything that is a number.
TextStyle ftText(
  ThemeProvider t, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  bool tabular = false,
}) {
  final display = size >= 28 && t.displayFont != null;
  return TextStyle(
    fontFamily: display ? t.displayFont : null,
    fontFamilyFallback: display ? const ['serif'] : null,
    fontSize: size,
    fontWeight: weight,
    color: color ?? t.textPrimary,
    height: height ?? (size >= 24 ? 1.15 : 1.4),
    letterSpacing: size >= 28 ? -size * 0.02 : 0,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

/// 76.0 -> "76", 76.5 -> "76.5".
String fmtNum(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Small section label above a field or group. Sentence case, not shouting.
class FtLabel extends StatelessWidget {
  const FtLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: Text(
        text,
        style: ftText(t, size: 13, weight: FontWeight.w500, color: t.textSecondary),
      ),
    );
  }
}

class FtDivider extends StatelessWidget {
  const FtDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Container(height: 1, color: t.border);
  }
}

class FtLoader extends StatelessWidget {
  const FtLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
      ),
    );
  }
}

class FtEmpty extends StatelessWidget {
  const FtEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: t.textTertiary),
            const SizedBox(height: Sp.x4),
            Text(title, style: ftText(t, size: 16, weight: FontWeight.w500)),
            const SizedBox(height: Sp.x1),
            Text(
              body,
              textAlign: TextAlign.center,
              style: ftText(t, size: 14, color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class FtCard extends StatelessWidget {
  const FtCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.x4),
    this.selected = false,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final box = AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.ease,
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? Color.alphaBlend(t.accentLight, t.surface) : t.surface,
        borderRadius: BorderRadius.circular(Rd.card),
        border: Border.all(color: selected ? t.accent : t.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}

class FtButton extends StatefulWidget {
  const FtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.secondary = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool secondary;
  final bool compact;

  @override
  State<FtButton> createState() => _FtButtonState();
}

class _FtButtonState extends State<FtButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final enabled = widget.onPressed != null && !widget.loading;
    final bg = widget.secondary ? t.surface2 : t.accent;
    final fg = widget.secondary ? t.textPrimary : t.accentText;

    final label = widget.loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Text(
            widget.label,
            style: ftText(
              t,
              size: widget.compact ? 13 : 15,
              weight: FontWeight.w500,
              color: fg,
            ),
          );

    final button = AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Motion.ease,
      child: AnimatedOpacity(
        opacity: widget.onPressed == null ? 0.4 : 1,
        duration: Motion.fast,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.compact ? 36 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? Sp.x4 : Sp.x5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Rd.control),
            border: widget.secondary ? Border.all(color: t.border) : null,
          ),
          child: Row(
            mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [label],
          ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: enabled ? widget.onPressed : null,
      child: widget.compact
          ? button
          : SizedBox(width: double.infinity, child: button),
    );
  }
}

/// Full-width single-select row.
class FtChoice extends StatelessWidget {
  const FtChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x2),
      child: FtCard(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.x6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: ftText(t, size: 14))),
              const SizedBox(width: Sp.x3),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: Motion.fast,
                child: Icon(Icons.check, size: 16, color: t.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact select chip for short options and multi-select.
class FtChip extends StatelessWidget {
  const FtChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.ease,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(t.accentLight, t.surface)
              : t.surface,
          borderRadius: BorderRadius.circular(Rd.chip),
          border: Border.all(color: selected ? t.accent : t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(label, style: ftText(t, size: 14))],
        ),
      ),
    );
  }
}

/// Round check used in checklists and the set log.
class FtCheck extends StatelessWidget {
  const FtCheck({super.key, required this.done, this.size = 24});
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.ease,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? t.accent : Colors.transparent,
        border: Border.all(color: done ? t.accent : t.textTertiary),
      ),
      child: AnimatedOpacity(
        opacity: done ? 1 : 0,
        duration: Motion.fast,
        child: Icon(Icons.check, size: size * 0.62, color: t.accentText),
      ),
    );
  }
}

/// Signature element: one tick per challenge day. Elapsed days are filled,
/// today is taller, the rest are an outline of what is left.
class TickStripPainter extends CustomPainter {
  TickStripPainter({
    required this.total,
    required this.done,
    required this.today,
    required this.accent,
    required this.track,
  });
  final int total;
  final int done;
  final int today; // 1-based, 0 for none
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    const gap = 2.0;
    final w = ((size.width - gap * (total - 1)) / total).clamp(1.0, 8.0);
    final span = w * total + gap * (total - 1);
    final startX = (size.width - span) / 2;
    final paint = Paint();
    for (var i = 0; i < total; i++) {
      final day = i + 1;
      final isToday = day == today;
      final isDone = day <= done;
      final h = isToday ? size.height : size.height * 0.6;
      final y = (size.height - h) / 2;
      paint.color = isToday
          ? accent
          : isDone
              ? accent.withValues(alpha: 0.55)
              : track;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX + i * (w + gap), y, w, h),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TickStripPainter old) =>
      old.total != total ||
      old.done != done ||
      old.today != today ||
      old.accent != accent ||
      old.track != track;
}

class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final today = current.clamp(0, total);
    return SizedBox(
      height: 20,
      width: double.infinity,
      child: CustomPaint(
        painter: TickStripPainter(
          total: total,
          done: today > 0 ? today - 1 : 0,
          today: today,
          accent: t.accent,
          track: t.textTertiary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// The challenge as a grid: one cell per day. Elapsed days are filled, and
/// today's cell fills from the bottom as the checklist is completed.
class ChallengeGrid extends StatelessWidget {
  const ChallengeGrid({
    super.key,
    required this.total,
    required this.current,
    required this.todayFill,
  });
  final int total;
  final int current; // 1-based day, 0 if not started
  final double todayFill; // 0..1

  int get _cols => total <= 21
      ? 7
      : total <= 45
          ? 9
          : total <= 75
              ? 15
              : 10;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 4.0;
        final cols = _cols;
        final cell = (box.maxWidth - gap * (cols - 1)) / cols;
        final rows = (total / cols).ceil();
        final height = rows * cell + (rows - 1) * gap;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: todayFill.clamp(0.0, 1.0)),
          duration: Motion.base,
          curve: Motion.ease,
          builder: (context, fill, _) => SizedBox(
            width: box.maxWidth,
            height: height,
            child: CustomPaint(
              painter: _GridPainter(
                total: total,
                current: current.clamp(0, total),
                fill: fill,
                cols: cols,
                gap: gap,
                accent: t.accent,
                track: t.surface2,
                line: t.border,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.total,
    required this.current,
    required this.fill,
    required this.cols,
    required this.gap,
    required this.accent,
    required this.track,
    required this.line,
  });
  final int total;
  final int current;
  final double fill;
  final int cols;
  final double gap;
  final Color accent;
  final Color track;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.width - gap * (cols - 1)) / cols;
    final radius = Radius.circular(cell * 0.25);
    final paint = Paint();
    for (var i = 0; i < total; i++) {
      final day = i + 1;
      final x = (i % cols) * (cell + gap);
      final y = (i ~/ cols) * (cell + gap);
      final rect = Rect.fromLTWH(x, y, cell, cell);
      final rrect = RRect.fromRectAndRadius(rect, radius);

      if (day < current) {
        paint
          ..style = PaintingStyle.fill
          ..color = accent.withValues(alpha: 0.6);
        canvas.drawRRect(rrect, paint);
      } else if (day == current) {
        paint
          ..style = PaintingStyle.fill
          ..color = track;
        canvas.drawRRect(rrect, paint);
        if (fill > 0) {
          canvas.save();
          canvas.clipRRect(rrect);
          paint.color = accent;
          canvas.drawRect(
            Rect.fromLTWH(x, y + cell * (1 - fill), cell, cell * fill),
            paint,
          );
          canvas.restore();
        }
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent;
        canvas.drawRRect(rrect.deflate(0.75), paint);
      } else {
        paint
          ..style = PaintingStyle.fill
          ..color = track;
        canvas.drawRRect(rrect, paint);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = line;
        canvas.drawRRect(rrect.deflate(0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.total != total ||
      old.current != current ||
      old.fill != fill ||
      old.cols != cols ||
      old.accent != accent ||
      old.track != track ||
      old.line != line;
}
