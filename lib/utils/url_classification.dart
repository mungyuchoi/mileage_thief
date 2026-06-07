class UrlClassification {
  static const List<String> _imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
  ];

  static bool isDirectImageUrl(String url) {
    final decodedUrl = _decodeBasicHtmlEntities(url).trim();
    if (decodedUrl.isEmpty) return false;

    final uri = Uri.tryParse(decodedUrl);
    final host = uri?.host.toLowerCase() ?? '';
    if (host == 'firebasestorage.googleapis.com' ||
        host.endsWith('.firebasestorage.googleapis.com') ||
        host == 'storage.googleapis.com' ||
        host.endsWith('.storage.googleapis.com')) {
      return true;
    }

    final path = _imagePathCandidate(decodedUrl, uri);
    if (path.isEmpty) return false;

    final lowerPath = path.toLowerCase();
    return _imageExtensions.any(lowerPath.endsWith);
  }

  static String _imagePathCandidate(String url, Uri? uri) {
    final rawPath = uri?.path;
    if (rawPath != null && rawPath.isNotEmpty) {
      try {
        return Uri.decodeFull(rawPath);
      } catch (_) {
        return rawPath;
      }
    }

    var path = url;
    final queryIndex = path.indexOf('?');
    final fragmentIndex = path.indexOf('#');
    final cutIndexes = [
      if (queryIndex >= 0) queryIndex,
      if (fragmentIndex >= 0) fragmentIndex,
    ];
    if (cutIndexes.isNotEmpty) {
      cutIndexes.sort();
      path = path.substring(0, cutIndexes.first);
    }

    try {
      return Uri.decodeFull(path);
    } catch (_) {
      return path;
    }
  }

  static String _decodeBasicHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
