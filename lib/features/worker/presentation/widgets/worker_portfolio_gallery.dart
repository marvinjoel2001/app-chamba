import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/worker_portfolio_photo.dart';

class WorkerPortfolioGallery extends StatelessWidget {
  const WorkerPortfolioGallery({
    required this.photos,
    this.onDelete,
    super.key,
  });

  final List<WorkerPortfolioPhoto> photos;
  final ValueChanged<WorkerPortfolioPhoto>? onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .78,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Material(
                      color: AppTheme.colorSurfaceSoft,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WorkerPortfolioViewer(
                              photos: photos,
                              initialIndex: index,
                            ),
                          ),
                        ),
                        child: Semantics(
                          label: 'Ver trabajo ${index + 1}',
                          button: true,
                          child: _WorkPhoto(url: photo.url, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filled(
                        tooltip: 'Eliminar foto',
                        onPressed: () => onDelete!(photo),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade700,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: Text(
                photo.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        );
      },
    );
  }
}

class WorkerPortfolioViewer extends StatefulWidget {
  const WorkerPortfolioViewer({
    required this.photos,
    required this.initialIndex,
    super.key,
  });

  final List<WorkerPortfolioPhoto> photos;
  final int initialIndex;

  @override
  State<WorkerPortfolioViewer> createState() => _WorkerPortfolioViewerState();
}

class _WorkerPortfolioViewerState extends State<WorkerPortfolioViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.photos[_index].caption;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Trabajo ${_index + 1} de ${widget.photos.length}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.photos.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (_, index) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: _WorkPhoto(
                        url: widget.photos[index].url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  caption,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkPhoto extends StatelessWidget {
  const _WorkPhoto({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, color: AppTheme.colorMuted),
      ),
    );
  }
}
