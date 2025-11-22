import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// 获取适用于当前平台的表情符号文本样式
/// 在 Windows 上使用系统默认字体，在其他平台使用 Noto Color Emoji
TextStyle getEmojiTextStyle({double fontSize = 16}) {
  // Web 平台始终使用 Noto Color Emoji
  if (kIsWeb) {
    return GoogleFonts.notoColorEmoji(fontSize: fontSize);
  }
  
  // 检测是否为 Windows 平台
  try {
    if (Platform.isWindows) {
      // Windows 平台使用系统默认字体，让系统自己处理 emoji
      return TextStyle(
        fontSize: fontSize,
        // 不指定 fontFamily，让系统使用默认的 emoji 字体
      );
    }
  } catch (e) {
    // 如果 Platform 不可用（某些情况下），使用 Noto Color Emoji
  }
  
  // 其他平台使用 Noto Color Emoji
  return GoogleFonts.notoColorEmoji(fontSize: fontSize);
}

