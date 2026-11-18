import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/photo_picker.dart';
import '../services/progress_photo.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

String _today() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Private progress photos: add, view, delete and compare two side by side.
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  List<ProgressPhoto>? _photos;
  bool _failed = false;
  bool _busy = false;
  bool _comparing = false;
  final List<ProgressPhoto> _selected = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _userId => context.read<AuthProvider>().userId;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final raw = await ApiService.listPhotos(userId);
      if (!mounted) return;
      setState(() {
        _photos = ProgressPhoto.parseList(raw);
        _failed = false;
        _selected.clear();
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _add() async {
    final userId = _userId;
    if (userId == null || _busy) return;
    final angle = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.read<ThemeProvider>().surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: Text(
                'Which angle?',
                style: ftText(context.read<ThemeProvider>(), size: 16, weight: FontWeight.w600),
              ),
            ),
            for (final a in ProgressPhoto.angles)
              ListTile(
                title: Text(ProgressPhoto.angleLabel(a)),
                onTap: () => Navigator.pop(ctx, a),
              ),
            const SizedBox(height: Sp.x2),
          ],
        ),
      ),
    );
    if (angle == null || !mounted) return;

    try {
      final bytes = await pickJpegPhoto();
      if (bytes == null) return; // cancelled, or not supported on this platform
      setState(() => _busy = true);
      final target = await ApiService.requestPhotoUpload(
        userId,
        date: _today(),
        angle: angle,
        size: bytes.length,
      );
      await ApiService.putPhotoBytes(target.uploadUrl, bytes);
      await _load();
      _toast('Photo saved');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ProgressPhoto p) async {
    final userId = _userId;
    if (userId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('This removes it permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deletePhoto(userId, p.key);
      await _load();
    } catch (_) {
      _toast('Could not delete the photo. Try again.');
    }
  }

  void _tap(ProgressPhoto p) {
    if (_comparing) {
      setState(() {
        final i = _selected.indexWhere((s) => s.key == p.key);
        if (i >= 0) {
          _selected.removeAt(i);
        } else if (_selected.length < 2) {
          _selected.add(p);
        }
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ViewerScreen(photo: p, onDelete: () => _delete(p)),
      ),
    );
  }

  void _openCompare() {
    final pair = compareOrder(_selected[0], _selected[1]);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CompareScreen(before: pair[0], after: pair[1])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final photos = _photos;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textSecondary),
        title: Text('Photos', style: ftText(t, size: 17, weight: FontWeight.w600)),
        actions: [
          if (photos != null && photos.length >= 2)
            TextButton(
              onPressed: () => setState(() {
                _comparing = !_comparing;
                _selected.clear();
              }),
              child: Text(_comparing ? 'Done' : 'Compare'),
            ),
        ],
      ),
      body: SafeArea(
        child: photos == null
            ? (_failed
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FtEmpty(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load photos',
                        body: 'Check your connection and try again.',
                      ),
                      FtButton(label: 'Retry', secondary: true, onPressed: _load),
                    ],
                  )
                : const FtLoader())
            : ListView(
                padding: const EdgeInsets.all(Sp.x5),
                children: [
                  FtButton(label: 'Add photo', loading: _busy, onPressed: _add),
                  const SizedBox(height: Sp.x2),
                  Text(
                    'Only you can see these. Location data is removed before upload.',
                    style: ftText(t, size: 12, color: t.textTertiary),
                  ),
                  if (_comparing) ...[
                    const SizedBox(height: Sp.x3),
                    FtCard(
                      selected: true,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selected.length < 2
                                  ? 'Pick ${2 - _selected.length} more photo${_selected.length == 1 ? '' : 's'} to compare'
                                  : 'Ready to compare',
                              style: ftText(t, size: 14),
                            ),
                          ),
                          if (_selected.length == 2)
                            FtButton(label: 'Compare', compact: true, onPressed: _openCompare),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Sp.x5),
                  if (photos.isEmpty)
                    const FtEmpty(
                      icon: Icons.photo_camera_outlined,
                      title: 'No photos yet',
                      body: 'Take a front, side and back photo each week to see the change.',
                    )
                  else
                    for (final day in groupByDate(photos)) ...[
                      FtLabel(day.date),
                      Row(
                        children: [
                          for (final angle in ProgressPhoto.angles)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: Sp.x2),
                                child: _Thumb(
                                  photo: day.photos.where((p) => p.angle == angle).firstOrNull,
                                  angle: angle,
                                  selected: _selected.any(
                                    (s) => day.photos.any((p) => p.angle == angle && p.key == s.key),
                                  ),
                                  onTap: _tap,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Sp.x4),
                    ],
                ],
              ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.angle,
    required this.selected,
    required this.onTap,
  });

  final ProgressPhoto? photo;
  final String angle;
  final bool selected;
  final void Function(ProgressPhoto) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    final p = photo;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: p == null ? null : () => onTap(p),
        child: Container(
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(Rd.control),
            border: Border.all(color: selected ? t.accent : t.border, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: p == null
              ? Center(
                  child: Text(
                    ProgressPhoto.angleLabel(angle),
                    style: ftText(t, size: 12, color: t.textTertiary),
                  ),
                )
              : Image.network(
                  p.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(Icons.broken_image_outlined, color: t.textTertiary),
                  ),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
        ),
      ),
    );
  }
}

class _ViewerScreen extends StatelessWidget {
  const _ViewerScreen({required this.photo, required this.onDelete});

  final ProgressPhoto photo;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textSecondary),
        title: Text(
          '${ProgressPhoto.angleLabel(photo.angle)} · ${photo.date}',
          style: ftText(t, size: 16, weight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete photo',
            icon: Icon(Icons.delete_outline, color: t.negative),
            onPressed: () async {
              await onDelete();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          child: Center(
            child: Image.network(
              photo.url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const FtEmpty(
                icon: Icons.broken_image_outlined,
                title: 'Could not show the photo',
                body: 'Go back and refresh the list.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareScreen extends StatelessWidget {
  const _CompareScreen({required this.before, required this.after});

  final ProgressPhoto before;
  final ProgressPhoto after;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    Widget side(ProgressPhoto p, String label) => Expanded(
          child: Column(
            children: [
              Text(label, style: ftText(t, size: 12, color: t.textTertiary)),
              Text(p.date, style: ftText(t, size: 14, weight: FontWeight.w600, tabular: true)),
              const SizedBox(height: Sp.x2),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Rd.control),
                  child: Image.network(
                    p.url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => Container(
                      color: t.surface2,
                      child: Center(child: Icon(Icons.broken_image_outlined, color: t.textTertiary)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Sp.x1),
              Text(ProgressPhoto.angleLabel(p.angle), style: ftText(t, size: 12, color: t.textSecondary)),
            ],
          ),
        );

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: t.textSecondary),
        title: Text('Compare', style: ftText(t, size: 17, weight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x5),
          child: Row(
            children: [
              side(before, 'Before'),
              const SizedBox(width: Sp.x3),
              side(after, 'After'),
            ],
          ),
        ),
      ),
    );
  }
}
