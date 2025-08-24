import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/attachment_file.dart';
import '../utils/image_utils.dart';
import '../utils/file_utils.dart';

class AttachmentController extends ChangeNotifier {
  final List<AttachmentFile> _attachments = [];
  bool _isProcessing = false;
  String? _lastError;

  static const int maxAttachmentCount = 20;
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSize = 50 * 1024 * 1024; // 50MB

  // Getters
  List<AttachmentFile> get attachments => List.unmodifiable(_attachments);
  
  List<AttachmentFile> get imageAttachments => 
      _attachments.where((file) => file.type == AttachmentType.image).toList();
  
  List<AttachmentFile> get documentAttachments => 
      _attachments.where((file) => file.type == AttachmentType.document).toList();
  
  bool get isProcessing => _isProcessing;
  String? get lastError => _lastError;
  
  int get totalSize => _attachments.fold(0, (sum, file) => sum + file.size);
  
  int get uploadedCount => 
      _attachments.where((file) => file.isUploaded).length;
  
  int get uploadingCount => 
      _attachments.where((file) => !file.isUploaded && file.uploadProgress > 0).length;
  
  bool get hasAttachments => _attachments.isNotEmpty;
  
  bool get canAddMore => _attachments.length < maxAttachmentCount;

  /// 갤러리에서 이미지를 선택합니다
  Future<AttachmentFile?> pickImageFromGallery() async {
    if (!canAddMore) {
      _setError('최대 $maxAttachmentCount개까지만 첨부할 수 있습니다.');
      return null;
    }

    _setProcessing(true);
    _clearError();

    try {
      final XFile? image = await ImageUtils.pickImageFromGallery();
      if (image == null) {
        _setProcessing(false);
        return null;
      }

      final attachment = await _createAttachmentFromFile(
        image.path, 
        image.name,
        AttachmentType.image,
      );

      if (attachment != null) {
        if (addAttachment(attachment)) {
          await _simulateUpload(attachment);
          return attachment;
        }
      }

      return null;
    } catch (e) {
      _setError('이미지 선택 중 오류가 발생했습니다: $e');
      return null;
    } finally {
      _setProcessing(false);
    }
  }

  /// 카메라에서 이미지를 촬영합니다
  Future<AttachmentFile?> pickImageFromCamera() async {
    if (!canAddMore) {
      _setError('최대 $maxAttachmentCount개까지만 첨부할 수 있습니다.');
      return null;
    }

    _setProcessing(true);
    _clearError();

    try {
      final XFile? image = await ImageUtils.pickImageFromCamera();
      if (image == null) {
        _setProcessing(false);
        return null;
      }

      final attachment = await _createAttachmentFromFile(
        image.path, 
        image.name,
        AttachmentType.image,
      );

      if (attachment != null) {
        if (addAttachment(attachment)) {
          await _simulateUpload(attachment);
          return attachment;
        }
      }

      return null;
    } catch (e) {
      _setError('카메라 촬영 중 오류가 발생했습니다: $e');
      return null;
    } finally {
      _setProcessing(false);
    }
  }

  /// 여러 이미지를 선택합니다
  Future<List<AttachmentFile>> pickMultipleImages() async {
    if (!canAddMore) {
      _setError('최대 $maxAttachmentCount개까지만 첨부할 수 있습니다.');
      return [];
    }

    _setProcessing(true);
    _clearError();

    try {
      final List<XFile> images = await ImageUtils.pickMultipleImages();
      if (images.isEmpty) {
        _setProcessing(false);
        return [];
      }

      final List<AttachmentFile> attachments = [];
      final remainingSlots = maxAttachmentCount - _attachments.length;
      final imagesToProcess = images.take(remainingSlots).toList();

      for (final image in imagesToProcess) {
        final attachment = await _createAttachmentFromFile(
          image.path, 
          image.name,
          AttachmentType.image,
        );

        if (attachment != null) {
          attachments.add(attachment);
        }
      }

      final addedCount = addMultipleAttachments(attachments);
      
      // 업로드 시뮬레이션
      for (final attachment in attachments.take(addedCount)) {
        _simulateUpload(attachment);
      }

      return attachments.take(addedCount).toList();
    } catch (e) {
      _setError('이미지 선택 중 오류가 발생했습니다: $e');
      return [];
    } finally {
      _setProcessing(false);
    }
  }

  /// 파일을 선택합니다
  Future<AttachmentFile?> pickFile() async {
    if (!canAddMore) {
      _setError('최대 $maxAttachmentCount개까지만 첨부할 수 있습니다.');
      return null;
    }

    _setProcessing(true);
    _clearError();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _setProcessing(false);
        return null;
      }

      final file = result.files.first;
      if (file.path == null) {
        _setError('파일 경로를 가져올 수 없습니다.');
        _setProcessing(false);
        return null;
      }

      final isImage = FileUtils.isSupportedImageFormat(file.name);
      final attachmentType = isImage ? AttachmentType.image : AttachmentType.document;

      final attachment = await _createAttachmentFromFile(
        file.path!,
        file.name,
        attachmentType,
      );

      if (attachment != null) {
        if (addAttachment(attachment)) {
          await _simulateUpload(attachment);
          return attachment;
        }
      }

      return null;
    } catch (e) {
      _setError('파일 선택 중 오류가 발생했습니다: $e');
      return null;
    } finally {
      _setProcessing(false);
    }
  }

  /// 여러 파일을 선택합니다
  Future<List<AttachmentFile>> pickMultipleFiles() async {
    if (!canAddMore) {
      _setError('최대 $maxAttachmentCount개까지만 첨부할 수 있습니다.');
      return [];
    }

    _setProcessing(true);
    _clearError();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        _setProcessing(false);
        return [];
      }

      final List<AttachmentFile> attachments = [];
      final remainingSlots = maxAttachmentCount - _attachments.length;
      final filesToProcess = result.files.take(remainingSlots).toList();

      for (final file in filesToProcess) {
        if (file.path == null) continue;

        final isImage = FileUtils.isSupportedImageFormat(file.name);
        final attachmentType = isImage ? AttachmentType.image : AttachmentType.document;

        final attachment = await _createAttachmentFromFile(
          file.path!,
          file.name,
          attachmentType,
        );

        if (attachment != null) {
          attachments.add(attachment);
        }
      }

      final addedCount = addMultipleAttachments(attachments);
      
      // 업로드 시뮬레이션
      for (final attachment in attachments.take(addedCount)) {
        _simulateUpload(attachment);
      }

      return attachments.take(addedCount).toList();
    } catch (e) {
      _setError('파일 선택 중 오류가 발생했습니다: $e');
      return [];
    } finally {
      _setProcessing(false);
    }
  }

  /// 첨부파일을 추가합니다
  bool addAttachment(AttachmentFile attachment) {
    if (!canAddMore) {
      _setError('최대 $maxAttachmentCount개까지만 첨부할 수 있습니다.');
      return false;
    }

    // 동일한 ID의 파일이 이미 있는지 확인
    if (_attachments.any((file) => file.id == attachment.id)) {
      _setError('이미 추가된 파일입니다.');
      return false;
    }

    _attachments.add(attachment);
    notifyListeners();
    return true;
  }

  /// 여러 첨부파일을 추가합니다
  int addMultipleAttachments(List<AttachmentFile> attachments) {
    final remainingSlots = maxAttachmentCount - _attachments.length;
    final filesToAdd = attachments.take(remainingSlots).toList();
    
    int addedCount = 0;
    for (final attachment in filesToAdd) {
      // 동일한 ID의 파일이 이미 있는지 확인
      if (!_attachments.any((file) => file.id == attachment.id)) {
        _attachments.add(attachment);
        addedCount++;
      }
    }
    
    if (addedCount > 0) {
      notifyListeners();
    }
    
    return addedCount;
  }

  /// 첨부파일을 제거합니다
  bool removeAttachment(String attachmentId) {
    final index = _attachments.indexWhere((file) => file.id == attachmentId);
    if (index != -1) {
      _attachments.removeAt(index);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 첨부파일을 업데이트합니다
  bool updateAttachment(AttachmentFile updatedAttachment) {
    final index = _attachments.indexWhere((file) => file.id == updatedAttachment.id);
    if (index != -1) {
      _attachments[index] = updatedAttachment;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 모든 첨부파일을 삭제합니다
  void clearAttachments() {
    _attachments.clear();
    notifyListeners();
  }

  /// 특정 ID의 첨부파일을 찾습니다
  AttachmentFile? findAttachment(String attachmentId) {
    try {
      return _attachments.firstWhere((file) => file.id == attachmentId);
    } catch (e) {
      return null;
    }
  }

  /// 파일에서 첨부파일 객체를 생성합니다
  Future<AttachmentFile?> _createAttachmentFromFile(
    String filePath,
    String fileName,
    AttachmentType type,
  ) async {
    try {
      final fileSize = await FileUtils.getFileSize(filePath);
      
      // 파일 크기 검증
      final maxSize = type == AttachmentType.image ? maxImageSize : maxDocumentSize;
      if (fileSize > maxSize) {
        final maxSizeStr = FileUtils.formatFileSize(maxSize);
        _setError('파일 크기가 너무 큽니다. 최대 $maxSizeStr까지 허용됩니다.');
        return null;
      }

      final uuid = const Uuid();
      final mimeType = type == AttachmentType.image 
          ? ImageUtils.getMimeTypeFromPath(filePath)
          : _getMimeType(fileName);

      return AttachmentFile(
        id: uuid.v4(),
        name: fileName,
        path: filePath,
        size: fileSize,
        mimeType: mimeType,
        type: type,
        uploadProgress: 0.0,
        isUploaded: false,
      );
    } catch (e) {
      _setError('파일 처리 중 오류가 발생했습니다: $e');
      return null;
    }
  }

  /// 업로드를 시뮬레이션합니다
  Future<void> _simulateUpload(AttachmentFile attachment) async {
    try {
      for (double progress = 0.1; progress <= 1.0; progress += 0.1) {
        await Future.delayed(const Duration(milliseconds: 200));
        
        final updatedAttachment = attachment.copyWith(
          uploadProgress: progress,
          isUploaded: progress >= 1.0,
        );
        
        updateAttachment(updatedAttachment);
      }
    } catch (e) {
      _setError('업로드 중 오류가 발생했습니다: $e');
    }
  }

  /// MIME 타입을 가져옵니다
  String _getMimeType(String fileName) {
    final extension = FileUtils.getFileExtension(fileName);
    
    switch (extension) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt': return 'text/plain';
      case 'rtf': return 'application/rtf';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default: return 'application/octet-stream';
    }
  }

  /// 처리 상태를 설정합니다
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// 오류를 설정합니다
  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  /// 오류를 삭제합니다
  void _clearError() {
    _lastError = null;
  }
}

