import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileUtils {
  /// 임시 디렉토리 경로를 가져옵니다
  static Future<String> getTempDirectoryPath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// 문서 디렉토리 경로를 가져옵니다
  static Future<String> getDocumentsDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// 디렉토리를 생성합니다
  static Future<bool> createDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return true;
    } catch (e) {
      print('Failed to create directory: $e');
      return false;
    }
  }

  /// 파일 크기를 가져옵니다
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      print('Failed to get file size: $e');
      return 0;
    }
  }

  /// 파일이 존재하는지 확인합니다
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 파일을 삭제합니다
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print('Failed to delete file: $e');
      return false;
    }
  }

  /// 파일을 복사합니다
  static Future<String?> copyFile(String sourcePath, String targetDirectory) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final fileName = path.basename(sourcePath);
      final targetPath = path.join(targetDirectory, fileName);
      
      await createDirectory(targetDirectory);
      await sourceFile.copy(targetPath);
      
      return targetPath;
    } catch (e) {
      print('Failed to copy file: $e');
      return null;
    }
  }

  /// 파일을 바이트 배열로 읽습니다
  static Future<Uint8List?> readFileAsBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (e) {
      print('Failed to read file as bytes: $e');
      return null;
    }
  }

  /// 바이트 배열을 파일로 저장합니다
  static Future<String?> saveFileFromBytes(
    Uint8List bytes, 
    String fileName, 
    String directoryPath
  ) async {
    try {
      await createDirectory(directoryPath);
      
      final filePath = path.join(directoryPath, fileName);
      final file = File(filePath);
      
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      print('Failed to save file from bytes: $e');
      return null;
    }
  }

  /// 파일 확장자를 가져옵니다
  static String getFileExtension(String fileName) {
    return path.extension(fileName).toLowerCase().replaceFirst('.', '');
  }

  /// 확장자 없는 파일명을 가져옵니다
  static String getFileNameWithoutExtension(String fileName) {
    return path.basenameWithoutExtension(fileName);
  }

  /// 고유한 파일명을 생성합니다
  static String generateUniqueFileName(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = getFileExtension(originalFileName);
    final baseName = getFileNameWithoutExtension(originalFileName);
    
    return '${baseName}_$timestamp${extension.isNotEmpty ? '.$extension' : ''}';
  }

  /// 지원되는 이미지 형식인지 확인합니다
  static bool isSupportedImageFormat(String fileName) {
    final extension = getFileExtension(fileName);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(extension);
  }

  /// 지원되는 문서 형식인지 확인합니다
  static bool isSupportedDocumentFormat(String fileName) {
    final extension = getFileExtension(fileName);
    return ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'].contains(extension);
  }

  /// 파일 크기가 유효한지 확인합니다
  static bool isFileSizeValid(int fileSize, String fileName) {
    if (isSupportedImageFormat(fileName)) {
      return fileSize <= 10 * 1024 * 1024; // 10MB
    } else if (isSupportedDocumentFormat(fileName)) {
      return fileSize <= 50 * 1024 * 1024; // 50MB
    }
    return false;
  }

  /// 디렉토리 내의 모든 파일을 가져옵니다
  static Future<List<File>> getFilesInDirectory(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return [];
      }

      final entities = await directory.list().toList();
      return entities.whereType<File>().toList();
    } catch (e) {
      print('Failed to get files in directory: $e');
      return [];
    }
  }

  /// 디렉토리의 총 크기를 계산합니다
  static Future<int> getDirectorySize(String directoryPath) async {
    try {
      final files = await getFilesInDirectory(directoryPath);
      int totalSize = 0;
      
      for (final file in files) {
        totalSize += await file.length();
      }
      
      return totalSize;
    } catch (e) {
      print('Failed to get directory size: $e');
      return 0;
    }
  }

  /// 임시 파일들을 정리합니다
  static Future<void> cleanupTempFiles(String directoryPath) async {
    try {
      final files = await getFilesInDirectory(directoryPath);
      final now = DateTime.now();
      
      for (final file in files) {
        final stat = await file.stat();
        final ageInHours = now.difference(stat.modified).inHours;
        
        // 24시간 이상된 파일들을 삭제
        if (ageInHours >= 24) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Failed to cleanup temp files: $e');
    }
  }

  /// 파일 크기를 포맷팅합니다
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

