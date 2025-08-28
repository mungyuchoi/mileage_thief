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
    int maxSize = 300 * 1024, // 300KB
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
  
  /// 주어진 파일을 목표 용량 이하(기본 1MB)로 반복 압축합니다.
  ///
  /// - JPEG: 품질을 낮추며 필요 시 해상도도 점진적으로 낮춤
  /// - PNG: 포맷 유지. 해상도를 단계적으로 낮춤 (품질 파라미터 영향 제한적)
  /// - 그 외: 원본 반환
  static Future<File> compressToUnderSize(
    File file, {
    int targetBytes = 1024 * 1024, // 1MB
  }) async {
    try {
      final originalSize = await file.length();
      if (originalSize <= targetBytes) return file;

      final tempDir = await getTemporaryDirectory();
      final basename = path.basenameWithoutExtension(file.path);
      final ext = path.extension(file.path).toLowerCase();

      // JPEG / PNG만 처리
      if (ext != '.jpg' && ext != '.jpeg' && ext != '.png') {
        return file; // GIF 등은 그대로 반환
      }

      int quality = 90;
      int minWidth = 1920;
      int minHeight = 1920;
      int attempts = 0;
      const int maxAttempts = 8;
      File current = file;

      while (attempts < maxAttempts) {
        attempts += 1;
        final outPath = path.join(
          tempDir.path,
          '${basename}_under_${targetBytes}_a$attempts${ext}',
        );

        final format = (ext == '.png')
            ? CompressFormat.png
            : CompressFormat.jpeg;

        final XFile? out = await FlutterImageCompress.compressAndGetFile(
          current.path,
          outPath,
          quality: (ext == '.png') ? 100 : quality, // png 품질 영향 적음
          format: format,
          minWidth: minWidth,
          minHeight: minHeight,
          keepExif: true,
        );

        if (out == null) break;
        final outFile = File(out.path);
        final outSize = await outFile.length();
        if (outSize <= targetBytes) {
          return outFile;
        }

        // 실패 시 더 강하게 압축: 해상도, 품질 단계적 하향
        if (ext == '.png') {
          // PNG는 주로 해상도만 낮춤
          minWidth = (minWidth * 0.75).toInt().clamp(480, minWidth);
          minHeight = (minHeight * 0.75).toInt().clamp(480, minHeight);
        } else {
          // JPEG는 품질 우선 하향, 필요 시 해상도도 하향
          quality = (quality - 20).clamp(30, 90);
          if (quality <= 50) {
            minWidth = (minWidth * 0.8).toInt().clamp(640, minWidth);
            minHeight = (minHeight * 0.8).toInt().clamp(640, minHeight);
          }
        }

        current = outFile;
      }

      // 목표치 달성 못했으면 가장 최근 결과 반환
      return current;
    } catch (e) {
      print('compressToUnderSize error: $e');
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