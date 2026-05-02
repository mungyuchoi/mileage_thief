import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTag;

  const ImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTag,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToNext() {
    if (_currentIndex >= widget.imageUrls.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showArrows = widget.imageUrls.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: widget.imageUrls.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: const TextStyle(color: Colors.white),
              )
            : null,
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.imageUrls.length == 1
                ? PhotoView(
                    imageProvider: NetworkImage(widget.imageUrls[0]),
                    heroAttributes: widget.heroTag != null
                        ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                        : null,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    initialScale: PhotoViewComputedScale.contained,
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    loadingBuilder: (context, event) => const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '이미지를 불러올 수 없습니다',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                : PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: NetworkImage(widget.imageUrls[index]),
                        heroAttributes: widget.heroTag != null
                            ? PhotoViewHeroAttributes(
                                tag: '${widget.heroTag}_$index',
                              )
                            : null,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        initialScale: PhotoViewComputedScale.contained,
                      );
                    },
                    itemCount: widget.imageUrls.length,
                    loadingBuilder: (context, event) => const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    pageController: _pageController,
                    onPageChanged: (int index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
          ),
          if (showArrows && _currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ViewerArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _goToPrevious,
                ),
              ),
            ),
          if (showArrows && _currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ViewerArrowButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _goToNext,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LocalImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const LocalImageViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  @override
  State<LocalImageViewer> createState() => _LocalImageViewerState();
}

class _LocalImageViewerState extends State<LocalImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToNext() {
    if (_currentIndex >= widget.imagePaths.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showArrows = widget.imagePaths.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: widget.imagePaths.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.imagePaths.length}',
                style: const TextStyle(color: Colors.white),
              )
            : null,
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.imagePaths.length == 1
                ? PhotoView(
                    imageProvider: FileImage(File(widget.imagePaths[0])),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    initialScale: PhotoViewComputedScale.contained,
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    loadingBuilder: (context, event) => const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '이미지를 불러올 수 없습니다',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                : PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider:
                            FileImage(File(widget.imagePaths[index])),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        initialScale: PhotoViewComputedScale.contained,
                      );
                    },
                    itemCount: widget.imagePaths.length,
                    loadingBuilder: (context, event) => const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    pageController: _pageController,
                    onPageChanged: (int index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
          ),
          if (showArrows && _currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ViewerArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _goToPrevious,
                ),
              ),
            ),
          if (showArrows && _currentIndex < widget.imagePaths.length - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ViewerArrowButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _goToNext,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewerArrowButton extends StatelessWidget {
  const _ViewerArrowButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

// 단일 이미지 뷰어 (간단한 버전)
class SingleImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const SingleImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          heroAttributes:
              heroTag != null ? PhotoViewHeroAttributes(tag: heroTag!) : null,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: PhotoViewComputedScale.contained,
          backgroundDecoration: const BoxDecoration(
            color: Colors.black,
          ),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
