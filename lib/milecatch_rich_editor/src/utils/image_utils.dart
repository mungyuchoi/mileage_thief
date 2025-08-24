import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'file_utils.dart';

class ImageUtils {
  static final ImagePicker _picker = ImagePicker();

  /// 갤러리에서 이미지를 선택합니다
  static Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      print('Failed to pick image from gallery: $e');
      return null;
    }
  }

  /// 카메라에서 이미지를 촬영합니다
  static Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      print('Failed to pick image from camera: $e');
      return null;
    }
  }

  /// 여러 이미지를 선택합니다
  static Future<List<XFile>> pickMultipleImages() async {
    try {
      // image_picker 최신 버전에서는 pickMultipleImages가 제거됨
      // 대신 단일 이미지 선택으로 대체하거나 file_picker 사용
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image != null ? [image] : [];
    } catch (e) {
      print('Failed to pick multiple images: $e');
      return [];
    }
  }

  /// 이미지를 Base64로 변환합니다
  static Future<String?> imageToBase64(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Failed to convert image to base64: $e');
      return null;
    }
  }

  /// Base64를 이미지 파일로 변환합니다
  static Future<String?> base64ToImageFile(
    String base64String, 
    String fileName, 
    String directoryPath
  ) async {
    try {
      final bytes = base64Decode(base64String);
      return await FileUtils.saveFileFromBytes(bytes, fileName, directoryPath);
    } catch (e) {
      print('Failed to convert base64 to image file: $e');
      return null;
    }
  }

  /// 이미지를 Data URL로 변환합니다
  static Future<String?> imageToDataUrl(String imagePath) async {
    try {
      final base64 = await imageToBase64(imagePath);
      if (base64 == null) return null;

      final mimeType = getMimeTypeFromPath(imagePath);
      return 'data:$mimeType;base64,$base64';
    } catch (e) {
      print('Failed to convert image to data url: $e');
      return null;
    }
  }

  /// 파일 경로에서 MIME 타입을 가져옵니다
  static String getMimeTypeFromPath(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      default:
        return 'image/jpeg';
    }
  }

  /// 유효한 이미지 파일인지 확인합니다
  static Future<bool> isValidImageFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final extension = FileUtils.getFileExtension(filePath);
      if (!FileUtils.isSupportedImageFormat(filePath)) {
        return false;
      }

      // 파일 크기 확인
      final size = await file.length();
      return size > 0 && size <= 10 * 1024 * 1024; // 10MB 제한
    } catch (e) {
      return false;
    }
  }

  /// 이미지 메타데이터를 가져옵니다
  static Future<Map<String, dynamic>> getImageMetadata(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return {};
      }

      final stat = await file.stat();
      final extension = FileUtils.getFileExtension(imagePath);
      
      return {
        'size': stat.size,
        'extension': extension,
        'mimeType': getMimeTypeFromPath(imagePath),
        'modified': stat.modified.toIso8601String(),
        'created': stat.changed.toIso8601String(),
      };
    } catch (e) {
      print('Failed to get image metadata: $e');
      return {};
    }
  }

  /// 이미지 크기를 조정합니다 (플레이스홀더 - 실제 구현은 flutter_image_compress 사용)
  static Future<String?> resizeImage(
    String imagePath, 
    int maxWidth, 
    int maxHeight, 
    {int quality = 85}
  ) async {
    try {
      // 실제 구현에서는 flutter_image_compress 패키지를 사용할 수 있습니다
      // 여기서는 원본 파일을 그대로 반환합니다
      return imagePath;
    } catch (e) {
      print('Failed to resize image: $e');
      return null;
    }
  }

  /// 이미지를 압축합니다 (플레이스홀더 - 실제 구현은 flutter_image_compress 사용)
  static Future<String?> compressImage(String imagePath, {int quality = 85}) async {
    try {
      // 실제 구현에서는 flutter_image_compress 패키지를 사용할 수 있습니다
      // 여기서는 원본 파일을 그대로 반환합니다
      return imagePath;
    } catch (e) {
      print('Failed to compress image: $e');
      return null;
    }
  }

  /// 썸네일을 생성합니다
  static Future<String?> generateThumbnail(String imagePath, {int size = 150}) async {
    try {
      // 실제 구현에서는 이미지 리사이징 라이브러리를 사용할 수 있습니다
      // 여기서는 원본 파일을 그대로 반환합니다
      return imagePath;
    } catch (e) {
      print('Failed to generate thumbnail: $e');
      return null;
    }
  }

  /// 이미지를 회전합니다
  static Future<String?> rotateImage(String imagePath, int degrees) async {
    try {
      // 실제 구현에서는 이미지 처리 라이브러리를 사용할 수 있습니다
      // 여기서는 원본 파일을 그대로 반환합니다
      return imagePath;
    } catch (e) {
      print('Failed to rotate image: $e');
      return null;
    }
  }

  /// 임시 이미지들을 정리합니다
  static Future<void> cleanupTempImages() async {
    try {
      final tempDir = await FileUtils.getTempDirectoryPath();
      final tempImageDir = path.join(tempDir, 'milecatch_images');
      await FileUtils.cleanupTempFiles(tempImageDir);
    } catch (e) {
      print('Failed to cleanup temp images: $e');
    }
  }
}
