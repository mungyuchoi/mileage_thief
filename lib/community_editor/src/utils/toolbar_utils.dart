import 'package:flutter/material.dart';

/// 툴바 관련 유틸리티 클래스입니다.
class ToolbarUtils {
  
  /// 선택된 텍스트에 마크다운 서식을 적용합니다.
  static void applyMarkdownFormat(
    TextEditingController controller,
    String format, {
    String? prefix,
    String? suffix,
  }) {
    final TextSelection selection = controller.selection;
    
    if (selection.baseOffset == selection.extentOffset) {
      // 선택된 텍스트가 없는 경우
      return;
    }

    final String selectedText = controller.text.substring(
      selection.baseOffset,
      selection.extentOffset,
    );

    String formattedText;
    switch (format.toLowerCase()) {
      case 'bold':
        formattedText = '**$selectedText**';
        break;
      case 'italic':
        formattedText = '*$selectedText*';
        break;
      case 'underline':
        formattedText = '<u>$selectedText</u>';
        break;
      case 'strikethrough':
        formattedText = '~~$selectedText~~';
        break;
      case 'code':
        formattedText = '`$selectedText`';
        break;
      case 'custom':
        formattedText = '${prefix ?? ''}$selectedText${suffix ?? ''}';
        break;
      default:
        formattedText = selectedText;
    }

    final String newText = controller.text.replaceRange(
      selection.baseOffset,
      selection.extentOffset,
      formattedText,
    );

    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: selection.baseOffset + formattedText.length,
    );
  }

  /// 현재 커서 위치에 텍스트를 삽입합니다.
  static void insertTextAtCursor(
    TextEditingController controller,
    String textToInsert,
  ) {
    final cursorPosition = controller.selection.baseOffset;
    final text = controller.text;
    
    final newText = text.substring(0, cursorPosition) +
                   textToInsert +
                   text.substring(cursorPosition);
    
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: cursorPosition + textToInsert.length,
    );
  }

  /// 현재 줄의 시작에 텍스트를 삽입합니다.
  static void insertTextAtLineStart(
    TextEditingController controller,
    String textToInsert,
  ) {
    final cursorPosition = controller.selection.baseOffset;
    final text = controller.text;
    
    // 현재 줄의 시작 위치 찾기
    int lineStart = cursorPosition;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    
    final newText = text.substring(0, lineStart) +
                   textToInsert +
                   text.substring(lineStart);
    
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: cursorPosition + textToInsert.length,
    );
  }

  /// 리스트 아이템을 삽입합니다.
  static void insertListItem(
    TextEditingController controller, {
    String bullet = '• ',
  }) {
    final cursorPosition = controller.selection.baseOffset;
    final text = controller.text;
    
    String textToInsert;
    int newCursorPosition;
    
    if (cursorPosition == 0 || text[cursorPosition - 1] == '\n') {
      // 줄의 시작에서 리스트 추가
      textToInsert = bullet;
      newCursorPosition = cursorPosition + bullet.length;
    } else {
      // 줄 중간에서 새 줄에 리스트 추가
      textToInsert = '\n$bullet';
      newCursorPosition = cursorPosition + textToInsert.length;
    }
    
    insertTextAtCursor(controller, textToInsert);
    controller.selection = TextSelection.collapsed(offset: newCursorPosition);
  }

  /// 번호 리스트 아이템을 삽입합니다.
  static void insertNumberedListItem(
    TextEditingController controller,
    int number,
  ) {
    insertListItem(controller, bullet: '$number. ');
  }

  /// 인용 블록을 삽입합니다.
  static void insertQuoteBlock(TextEditingController controller) {
    insertTextAtLineStart(controller, '> ');
  }

  /// 코드 블록을 삽입합니다.
  static void insertCodeBlock(TextEditingController controller) {
    insertTextAtCursor(controller, '\n```\n\n```\n');
    // 코드 블록 안쪽으로 커서 이동
    final newPosition = controller.selection.baseOffset - 5;
    controller.selection = TextSelection.collapsed(offset: newPosition);
  }

  /// 현재 선택영역이 특정 서식을 포함하고 있는지 확인합니다.
  static bool hasFormat(
    TextEditingController controller,
    String format,
  ) {
    final TextSelection selection = controller.selection;
    
    if (selection.baseOffset == selection.extentOffset) {
      return false;
    }

    final String selectedText = controller.text.substring(
      selection.baseOffset,
      selection.extentOffset,
    );

    switch (format.toLowerCase()) {
      case 'bold':
        return selectedText.startsWith('**') && selectedText.endsWith('**');
      case 'italic':
        return selectedText.startsWith('*') && selectedText.endsWith('*') &&
               !selectedText.startsWith('**');
      case 'underline':
        return selectedText.startsWith('<u>') && selectedText.endsWith('</u>');
      case 'strikethrough':
        return selectedText.startsWith('~~') && selectedText.endsWith('~~');
      case 'code':
        return selectedText.startsWith('`') && selectedText.endsWith('`');
      default:
        return false;
    }
  }

  /// 서식을 토글합니다 (적용/해제).
  static void toggleFormat(
    TextEditingController controller,
    String format,
  ) {
    if (hasFormat(controller, format)) {
      // 서식 해제
      _removeFormat(controller, format);
    } else {
      // 서식 적용
      applyMarkdownFormat(controller, format);
    }
  }

  /// 서식을 제거합니다.
  static void _removeFormat(
    TextEditingController controller,
    String format,
  ) {
    final TextSelection selection = controller.selection;
    
    if (selection.baseOffset == selection.extentOffset) {
      return;
    }

    final String selectedText = controller.text.substring(
      selection.baseOffset,
      selection.extentOffset,
    );

    String unformattedText;
    switch (format.toLowerCase()) {
      case 'bold':
        unformattedText = selectedText.replaceAll(RegExp(r'^\*\*|\*\*$'), '');
        break;
      case 'italic':
        unformattedText = selectedText.replaceAll(RegExp(r'^\*|\*$'), '');
        break;
      case 'underline':
        unformattedText = selectedText.replaceAll(RegExp(r'^<u>|</u>$'), '');
        break;
      case 'strikethrough':
        unformattedText = selectedText.replaceAll(RegExp(r'^~~|~~$'), '');
        break;
      case 'code':
        unformattedText = selectedText.replaceAll(RegExp(r'^`|`$'), '');
        break;
      default:
        unformattedText = selectedText;
    }

    final String newText = controller.text.replaceRange(
      selection.baseOffset,
      selection.extentOffset,
      unformattedText,
    );

    controller.text = newText;
    controller.selection = TextSelection(
      baseOffset: selection.baseOffset,
      extentOffset: selection.baseOffset + unformattedText.length,
    );
  }
}

