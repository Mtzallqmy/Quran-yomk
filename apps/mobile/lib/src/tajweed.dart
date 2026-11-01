import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class TajweedMarkup {
  const TajweedMarkup._();

  static List<InlineSpan> spans(
    String value,
    TextStyle base,
    ColorScheme colors,
  ) {
    final result = <InlineSpan>[];
    final buffer = StringBuffer();
    var activeCode = '';

    void flush() {
      if (buffer.isEmpty) return;
      result.add(
        TextSpan(
          text: buffer.toString(),
          style: _style(activeCode, base, colors),
        ),
      );
      buffer.clear();
    }

    var index = 0;
    while (index < value.length) {
      final char = value[index];
      if (char == '[') {
        final end = value.indexOf('[', index + 1);
        if (end > index) {
          final code = value.substring(index + 1, end).trim();
          if (code.isNotEmpty && code.length <= 16) {
            flush();
            activeCode = code;
            index = end + 1;
            continue;
          }
        }
      }
      if (char == ']') {
        flush();
        activeCode = '';
        index += 1;
        continue;
      }
      buffer.write(char);
      index += 1;
    }
    flush();
    return result.isEmpty
        ? <InlineSpan>[TextSpan(text: value, style: base)]
        : result;
  }

  static String plainText(String value) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < value.length) {
      final char = value[index];
      if (char == '[') {
        final end = value.indexOf('[', index + 1);
        if (end > index) {
          index = end + 1;
          continue;
        }
      }
      if (char == ']') {
        index += 1;
        continue;
      }
      buffer.write(char);
      index += 1;
    }
    return buffer.toString();
  }

  static TextStyle _style(String code, TextStyle base, ColorScheme colors) {
    if (code.isEmpty) return base;
    final normalized = code.toLowerCase();
    if (normalized.startsWith('h') || normalized.startsWith('s')) {
      return base.copyWith(color: colors.outline);
    }
    if (normalized.startsWith('n') || normalized.startsWith('p')) {
      return base.copyWith(color: colors.primary);
    }
    if (normalized.startsWith('m') || normalized.startsWith('q')) {
      return base.copyWith(color: colors.tertiary);
    }
    if (normalized.startsWith('g')) {
      return base.copyWith(color: colors.secondary);
    }
    if (normalized.startsWith('i') || normalized.startsWith('c')) {
      return base.copyWith(color: colors.error);
    }
    return base.copyWith(color: colors.primary);
  }
}

String arabicIndicNumber(int value) {
  const western = '0123456789';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.toString().split('').map((digit) {
    final index = western.indexOf(digit);
    return index < 0 ? digit : arabic[index];
  }).join();
}

class TajweedColor {
  const TajweedColor(this.value);
  final int value;
}

class TajweedRule {
  const TajweedRule({
    required this.id,
    required this.label,
    required this.explanation,
    required this.color,
    required this.reviewReference,
  });
  final String id, label, explanation, reviewReference;
  final TajweedColor color;
}

class TajweedTextVersion {
  const TajweedTextVersion(this.id, this.textSha256);
  final String id, textSha256;
}

class TajweedSourceRights {
  const TajweedSourceRights(
    this.source,
    this.licenseUrl, {
    required this.mayUse,
    required this.scholarlyReviewed,
  });
  final String source, licenseUrl;
  final bool mayUse, scholarlyReviewed;
}

class TajweedAnnotation {
  const TajweedAnnotation(
    this.startUtf16,
    this.endUtf16,
    this.rule,
    this.version,
  );
  final int startUtf16, endUtf16;
  final TajweedRule rule;
  final TajweedTextVersion version;
  bool matches(String exactText, TajweedSourceRights rights) =>
      rights.mayUse &&
      rights.scholarlyReviewed &&
      rule.reviewReference.isNotEmpty &&
      sha256.convert(utf8.encode(exactText)).toString() == version.textSha256 &&
      startUtf16 >= 0 &&
      endUtf16 > startUtf16 &&
      endUtf16 <= exactText.length;
}
