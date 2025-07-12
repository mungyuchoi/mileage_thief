import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ImageCompressor {
  /// 이미지를 압축하고 JPG로 변환
  /// 
  /// [file] - 원본 이미지 파일
  /// [maxSize] - 최대 파일 크기 (바이트), 기본값 200KB
  /// [quality] - 압축 품질 (0-100), 기본값 80
  /// 
  /// Returns: 압축된 이미지 파일
  static Future<File> compressImage(
    File file, {
    int maxSize = 200 * 1024, // 200KB
    int quality = 80,
  }) async {
    try {
      // 원본 파일 크기 확인
      final originalSize = await file.length();
      print('원본 이미지 크기: ${(originalSize / 1024).toStringAsFixed(2)}KB');
      
      // 이미 충분히 작으면 압축하지 않음
      if (originalSize <= maxSize) {
        print('이미 충분히 작은 파일입니다. 압축을 건너뜁니다.');
        return file;
      }
      
      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;
      final fileName = path.basename(file.path);
      final extension = path.extension(fileName);
      final nameWithoutExtension = path.basenameWithoutExtension(fileName);
      
      // 압축된 파일 경로 생성
      final compressedPath = path.join(tempPath, '${nameWithoutExtension}_compressed.jpg');
      
      // 이미지 압축 및 JPG 변환
      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        compressedPath,
        quality: quality,
        format: CompressFormat.jpeg,
        minWidth: 1024, // 최소 너비 제한
        minHeight: 1024, // 최소 높이 제한
        rotate: 0, // 회전 없음
      );
      
      if (compressedXFile == null) {
        throw Exception('이미지 압축에 실패했습니다.');
      }
      
      // XFile을 File로 변환
      final compressedFile = File(compressedXFile.path);
      
      // 압축된 파일 크기 확인
      final compressedSize = await compressedFile.length();
      print('압축된 이미지 크기: ${(compressedSize / 1024).toStringAsFixed(2)}KB');
      
      // 압축 후에도 여전히 크다면 더 강하게 압축
      if (compressedSize > maxSize) {
        print('첫 번째 압축 후에도 크기가 큽니다. 더 강하게 압축합니다.');
        final strongerCompressedXFile = await FlutterImageCompress.compressAndGetFile(
          compressedXFile.path,
          compressedPath.replaceAll('_compressed.jpg', '_compressed_strong.jpg'),
          quality: quality ~/ 2, // 품질을 절반으로
          format: CompressFormat.jpeg,
          minWidth: 800, // 더 작은 크기로
          minHeight: 800,
          rotate: 0,
        );
        
        if (strongerCompressedXFile != null) {
          // XFile을 File로 변환
          final strongerFile = File(strongerCompressedXFile.path);
          final strongerSize = await strongerFile.length();
          print('강화 압축된 이미지 크기: ${(strongerSize / 1024).toStringAsFixed(2)}KB');
          return strongerFile;
        }
      }
      
      return compressedFile;
      
    } catch (e) {
      print('이미지 압축 오류: $e');
      // 압축 실패 시 원본 파일 반환
      return file;
    }
  }
  
  /// 이미지 파일의 메타데이터 정보 출력 (디버깅용)
  static Future<void> printImageInfo(File file) async {
    try {
      final size = await file.length();
      final path = file.path;
      final extension = path.split('.').last.toLowerCase();
      
      print('=== 이미지 정보 ===');
      print('경로: $path');
      print('확장자: $extension');
      print('크기: ${(size / 1024).toStringAsFixed(2)}KB');
      print('==================');
    } catch (e) {
      print('이미지 정보 출력 오류: $e');
    }
  }
} 