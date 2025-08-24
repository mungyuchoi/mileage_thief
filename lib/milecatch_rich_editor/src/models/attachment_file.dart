enum AttachmentType { image, document }

class AttachmentFile {
  final String id;
  final String name;
  final String path;
  final int size;
  final String mimeType;
  final AttachmentType type;
  final double uploadProgress;
  final bool isUploaded;
  final String? thumbnailPath;

  const AttachmentFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.type,
    this.uploadProgress = 0.0,
    this.isUploaded = false,
    this.thumbnailPath,
  });

  AttachmentFile copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    String? mimeType,
    AttachmentType? type,
    double? uploadProgress,
    bool? isUploaded,
    String? thumbnailPath,
  }) {
    return AttachmentFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      type: type ?? this.type,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploaded: isUploaded ?? this.isUploaded,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'mimeType': mimeType,
      'type': type.name,
      'uploadProgress': uploadProgress,
      'isUploaded': isUploaded,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory AttachmentFile.fromJson(Map<String, dynamic> json) {
    return AttachmentFile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      size: json['size'] ?? 0,
      mimeType: json['mimeType'] ?? '',
      type: AttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttachmentType.document,
      ),
      uploadProgress: (json['uploadProgress'] ?? 0.0).toDouble(),
      isUploaded: json['isUploaded'] ?? false,
      thumbnailPath: json['thumbnailPath'],
    );
  }

  @override
  String toString() {
    return 'AttachmentFile{id: $id, name: $name, size: $size, type: $type, uploadProgress: $uploadProgress, isUploaded: $isUploaded}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentFile &&
        other.id == id &&
        other.name == name &&
        other.path == path &&
        other.size == size &&
        other.mimeType == mimeType &&
        other.type == type &&
        other.uploadProgress == uploadProgress &&
        other.isUploaded == isUploaded &&
        other.thumbnailPath == thumbnailPath;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      path,
      size,
      mimeType,
      type,
      uploadProgress,
      isUploaded,
      thumbnailPath,
    );
  }
}

