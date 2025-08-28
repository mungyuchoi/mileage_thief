import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storage를 사용한 이미지 업로드 유틸리티
class FirebaseImageUploader {
  static const Uuid _uuid = Uuid();
  
  /// 이미지를 Firebase Storage에 업로드하고 다운로드 URL을 반환합니다.
  static Future<String> uploadImage({
    required File imageFile,
    required String postId,
    required String dateString,
  }) async {
    try {
      // iOS에서는 올바른 bucket 사용
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(bucket: 'mileagethief.firebasestorage.app');
      } else {
        storage = FirebaseStorage.instance;
      }
      
      // 파일명 생성
      final String fileName = '${postId}_${_uuid.v4()}.${imageFile.path.split('.').last}';
      
      // Storage 경로 설정
      final Reference ref = storage
          .ref()
          .child('posts')
          .child(dateString)
          .child('posts')
          .child(postId)
          .child('images')
          .child(fileName);

      // 파일 업로드
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      
      // 다운로드 URL 가져오기
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('이미지 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      throw Exception('이미지 업로드에 실패했습니다: $e');
    }
  }
  
  /// 업로드 진행 상황을 모니터링하면서 이미지를 업로드합니다.
  static Future<String> uploadImageWithProgress({
    required File imageFile,
    required String postId,
    required String dateString,
    Function(double progress)? onProgress,
  }) async {
    try {
      // iOS에서는 올바른 bucket 사용
      FirebaseStorage storage;
      if (Platform.isIOS) {
        storage = FirebaseStorage.instanceFor(bucket: 'mileagethief.firebasestorage.app');
      } else {
        storage = FirebaseStorage.instance;
      }
      
      // 파일명 생성
      final String fileName = '${postId}_${_uuid.v4()}.${imageFile.path.split('.').last}';
      
      // Storage 경로 설정
      final Reference ref = storage
          .ref()
          .child('posts')
          .child(dateString)
          .child('posts')
          .child(postId)
          .child('images')
          .child(fileName);

      // 파일 업로드
      final UploadTask uploadTask = ref.putFile(imageFile);
      
      // 진행 상황 모니터링
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      final TaskSnapshot snapshot = await uploadTask;
      
      // 다운로드 URL 가져오기
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('이미지 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      throw Exception('이미지 업로드에 실패했습니다: $e');
    }
  }
  
  /// HTML 내용에서 임시 이미지 경로를 Firebase Storage URL로 교체합니다.
  static Future<String> processImagesInHtml({
    required String htmlContent,
    required String postId,
    required String dateString,
  }) async {
    String processedHtml = htmlContent;
    
    print('HTML 처리 시작, 원본 크기: ${htmlContent.length} 바이트');
    
    // data:image 형태의 base64 이미지 처리 (MIME + DATA 캡처)
    final RegExp base64ImgRegex = RegExp(
      r'<img[^>]*src="data:(image\/[^;]+);base64,([^"]*)"[^>]*>',
      caseSensitive: false,
    );
    final matches = base64ImgRegex.allMatches(processedHtml);
    
    print('발견된 base64 이미지 개수: ${matches.length}');
    
    for (final match in matches) {
      final String fullMatch = match.group(0)!; // 전체 img 태그
      final String mimeType = match.group(1)!;  // 예: image/gif, image/png
      final String base64Data = match.group(2)!; // base64 데이터
      
      try {
        print('base64 이미지 업로드 시작');
        
        // base64를 임시 파일로 저장 (MIME에 맞는 확장자 유지)
        final tempFile = await _createTempFileFromBase64(
          base64Data,
          extension: _extensionFromMime(mimeType),
        );
        
        // Firebase Storage에 업로드
        final String downloadUrl = await uploadImage(
          imageFile: tempFile,
          postId: postId,
          dateString: dateString,
        );
        
        print('base64 이미지 업로드 완료: $downloadUrl');
        
        // HTML에서 base64를 다운로드 URL로 교체
        final String newImgTag = '<img src="$downloadUrl" style="max-width: 100%; border-radius: 8px;" />';
        processedHtml = processedHtml.replaceAll(fullMatch, newImgTag);
        
        // 임시 파일 삭제
        await tempFile.delete();
        
        print('이미지 교체 완료: $downloadUrl');
        
      } catch (e) {
        print('base64 이미지 업로드 실패, 오류: $e');
        // 업로드 실패한 이미지는 제거
        processedHtml = processedHtml.replaceAll(fullMatch, '');
      }
    }
    
    print('HTML 처리 완료, 최종 크기: ${processedHtml.length} 바이트');
    return processedHtml;
  }
  
  /// base64 데이터를 임시 파일로 생성합니다.
  static Future<File> _createTempFileFromBase64(String base64Data, {required String extension}) async {
    final bytes = base64Decode(base64Data);
    final tempDir = Directory.systemTemp;
    final safeExt = extension.startsWith('.') ? extension : '.$extension';
    final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}$safeExt');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  /// MIME 타입에서 파일 확장자를 유추합니다
  static String _extensionFromMime(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/gif':
        return '.gif';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/svg+xml':
        return '.svg';
      case 'image/jpeg':
      case 'image/jpg':
      default:
        return '.jpg';
    }
  }
}
