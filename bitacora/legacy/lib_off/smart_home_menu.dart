import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/gridnote_theme.dart';
import '../services/smart_turbo.dart';

class SmartHomeMenu extends StatefulWidget {
  const SmartHomeMenu({
    super.key,
    required this.theme,
    required this.photosLoader,
    this.onOpenPhoto,
    this.maxItems = 120,
  });

  final GridnoteThemeController theme;
  final Future<List<File>> Function() photosLoader;
  final void Function(File file)? onOpenPhoto;
  final int maxItems;

  @override
  State<SmartHomeMenu> createState() => _SmartHomeMenuState();
}

class _SmartHomeMenuState extends State<SmartHomeMenu> {
  List<File> _files = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SmartTurbo.registerPhotosLoader(widget.photosLoader);
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.photosLoader();
      if (!mounted) return;
      setState(() {
        _files = all.take(widget.maxItems).toList();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) SmartTurbo.precacheThumbnails(context);
      });
      SmartTurbo.trackOpenGallery();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header sin overflow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Galería reciente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? _SkeletonGrid(t: t)
              : _files.isEmpty
              ? _Empty(t: t)
              : _Grid(t: t, files: _files, onTap: widget.onOpenPhoto),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.t, required this.files, this.onTap});
  final GridnoteTheme t;
  final List<File> files;
  final void Function(File file)? onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: files.length,
      itemBuilder: (_, i) {
        final f = files[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Image(
                  image: ResizeImage(FileImage(f), width: 512, height: 512),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0x22000000),
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, size: 18),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child:
                InkWell(onTap: onTap == null ? null : () => onTap!(f)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({required this.t});
  final GridnoteTheme t;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _ShimmerTile(color: t.surface),
      ),
    );
  }
}

class _ShimmerTile extends StatefulWidget {
  const _ShimmerTile({required this.color});
  final Color color;

  @override
  State<_ShimmerTile> createState() => _ShimmerTileState();
}

class _ShimmerTileState extends State<_ShimmerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c.drive(Tween(begin: .45, end: .85)),
      child: ColoredBox(color: widget.color.withValues(alpha: .25)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.t});
  final GridnoteTheme t;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Sin fotos recientes',
        style: TextStyle(color: t.text.withValues(alpha: .7)),
      ),
    );
  }
}
