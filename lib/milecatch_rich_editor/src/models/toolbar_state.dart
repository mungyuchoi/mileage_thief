import 'package:flutter/material.dart';

class ToolbarState {
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? textColor;
  final Color? backgroundColor;
  final int fontSize;
  final TextAlign textAlign;
  final bool isVisible;
  final bool isExpanded;

  const ToolbarState({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.textColor,
    this.backgroundColor,
    this.fontSize = 16,
    this.textAlign = TextAlign.left,
    this.isVisible = true,
    this.isExpanded = false,
  });

  ToolbarState copyWith({
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    Color? textColor,
    Color? backgroundColor,
    int? fontSize,
    TextAlign? textAlign,
    bool? isVisible,
    bool? isExpanded,
  }) {
    return ToolbarState(
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontSize: fontSize ?? this.fontSize,
      textAlign: textAlign ?? this.textAlign,
      isVisible: isVisible ?? this.isVisible,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderline': isUnderline,
      'textColor': textColor?.value,
      'backgroundColor': backgroundColor?.value,
      'fontSize': fontSize,
      'textAlign': textAlign.index,
      'isVisible': isVisible,
      'isExpanded': isExpanded,
    };
  }

  factory ToolbarState.fromJson(Map<String, dynamic> json) {
    return ToolbarState(
      isBold: json['isBold'] ?? false,
      isItalic: json['isItalic'] ?? false,
      isUnderline: json['isUnderline'] ?? false,
      textColor: json['textColor'] != null ? Color(json['textColor']) : null,
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor']) : null,
      fontSize: json['fontSize'] ?? 16,
      textAlign: TextAlign.values[json['textAlign'] ?? 0],
      isVisible: json['isVisible'] ?? true,
      isExpanded: json['isExpanded'] ?? false,
    );
  }

  @override
  String toString() {
    return 'ToolbarState{isBold: $isBold, isItalic: $isItalic, isUnderline: $isUnderline, textColor: $textColor, backgroundColor: $backgroundColor, fontSize: $fontSize, textAlign: $textAlign, isVisible: $isVisible, isExpanded: $isExpanded}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolbarState &&
        other.isBold == isBold &&
        other.isItalic == isItalic &&
        other.isUnderline == isUnderline &&
        other.textColor == textColor &&
        other.backgroundColor == backgroundColor &&
        other.fontSize == fontSize &&
        other.textAlign == textAlign &&
        other.isVisible == isVisible &&
        other.isExpanded == isExpanded;
  }

  @override
  int get hashCode {
    return Object.hash(
      isBold,
      isItalic,
      isUnderline,
      textColor,
      backgroundColor,
      fontSize,
      textAlign,
      isVisible,
      isExpanded,
    );
  }
}

