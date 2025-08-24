import 'dart:convert';

class JSBridge {
  /// JavaScript 메시지를 파싱합니다
  Map<String, dynamic> parseMessage(String message) {
    try {
      return json.decode(message) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Failed to parse message: $e'};
    }
  }

  /// 데이터를 JSON 문자열로 인코딩합니다
  String encodeData(Map<String, dynamic> data) {
    try {
      return json.encode(data);
    } catch (e) {
      return json.encode({'error': 'Failed to encode data: $e'});
    }
  }

  /// HTML 문자열을 이스케이프합니다
  String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// JavaScript 문자열을 이스케이프합니다
  String escapeJavaScript(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Color 값을 CSS 색상으로 변환합니다
  String colorToCss(int colorValue) {
    final color = colorValue & 0xFFFFFF;
    return '#${color.toRadixString(16).padLeft(6, '0')}';
  }

  /// 파일 크기를 포맷합니다
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// MIME 타입에서 파일 확장자를 가져옵니다
  String getFileExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/svg+xml':
        return 'svg';
      case 'application/pdf':
        return 'pdf';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'text/plain':
        return 'txt';
      case 'application/rtf':
        return 'rtf';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'application/vnd.ms-powerpoint':
        return 'ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';
      default:
        return 'unknown';
    }
  }

  /// 이미지 파일인지 확인합니다
  bool isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(extension);
  }

  /// 문서 파일인지 확인합니다
  bool isDocumentFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'].contains(extension);
  }

  /// Base64 데이터 URL을 생성합니다
  String createDataUrl(String mimeType, String base64Data) {
    return 'data:$mimeType;base64,$base64Data';
  }

  /// URL에서 파일명을 추출합니다
  String getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.pathSegments.last;
    } catch (e) {
      return 'unknown';
    }
  }

  /// 파일명을 정리합니다
  String sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// 디버그 로그 출력
  void debugLog(String message, [dynamic data]) {
    print('[JSBridge] $message${data != null ? ': $data' : ''}');
  }
}

