import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:core';

/// 支持 LaTeX 公式的 HTML 渲染器
class LatexHtml extends StatelessWidget {
  final String data;
  
  const LatexHtml({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 解析 HTML，提取 LaTeX 公式并替换为占位符
    final parts = _parseHtmlWithLatex(data);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: parts.map((part) {
        if (part is _LatexPart) {
          // 渲染 LaTeX 公式
          if (part.isBlock) {
            // 块级公式：居中显示
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Math.tex(
                  part.latex,
                  mathStyle: MathStyle.display,
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
            );
          } else {
            // 行内公式：正常显示
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Math.tex(
                part.latex,
                mathStyle: MathStyle.text,
                textStyle: TextStyle(fontSize: 16),
              ),
            );
          }
        } else if (part is _HtmlPart) {
          // 渲染 HTML 内容
          return Html(data: part.html);
        } else {
          return SizedBox.shrink();
        }
      }).toList(),
    );
  }

  /// 解析 HTML，分离 LaTeX 公式和 HTML 内容
  List<_Part> _parseHtmlWithLatex(String html) {
    final List<_Part> parts = [];
    int lastIndex = 0;
    
    // 先匹配块级公式 $$...$$
    final blockPattern = RegExp(r'\$\$([^$]+?)\$\$', dotAll: true);
    final inlinePattern = RegExp(r'(?<!\$)\$([^$\n]+?)\$(?!\$)');
    
    // 收集所有匹配项
    final List<_Match> matches = [];
    
    blockPattern.allMatches(html).forEach((match) {
      matches.add(_Match(
        start: match.start,
        end: match.end,
        latex: match.group(1) ?? '',
        isBlock: true,
      ));
    });
    
    inlinePattern.allMatches(html).forEach((match) {
      // 检查是否已经被块级公式包含
      bool isContained = false;
      for (var blockMatch in matches) {
        if (match.start >= blockMatch.start && match.end <= blockMatch.end) {
          isContained = true;
          break;
        }
      }
      if (!isContained) {
        matches.add(_Match(
          start: match.start,
          end: match.end,
          latex: match.group(1) ?? '',
          isBlock: false,
        ));
      }
    });
    
    // 按位置排序
    matches.sort((a, b) => a.start.compareTo(b.start));
    
    // 构建部分列表
    for (var match in matches) {
      // 添加之前的 HTML 内容
      if (match.start > lastIndex) {
        final htmlPart = html.substring(lastIndex, match.start);
        if (htmlPart.trim().isNotEmpty) {
          parts.add(_HtmlPart(html: htmlPart));
        }
      }
      
      // 添加 LaTeX 公式
      parts.add(_LatexPart(latex: match.latex, isBlock: match.isBlock));
      
      lastIndex = match.end;
    }
    
    // 添加剩余的 HTML 内容
    if (lastIndex < html.length) {
      final htmlPart = html.substring(lastIndex);
      if (htmlPart.trim().isNotEmpty) {
        parts.add(_HtmlPart(html: htmlPart));
      }
    }
    
    // 如果没有匹配到任何 LaTeX，直接返回整个 HTML
    if (parts.isEmpty) {
      parts.add(_HtmlPart(html: html));
    }
    
    return parts;
  }
}

class _Match {
  final int start;
  final int end;
  final String latex;
  final bool isBlock;
  
  _Match({
    required this.start,
    required this.end,
    required this.latex,
    required this.isBlock,
  });
}

abstract class _Part {}

class _HtmlPart extends _Part {
  final String html;
  _HtmlPart({required this.html});
}

class _LatexPart extends _Part {
  final String latex;
  final bool isBlock;
  _LatexPart({required this.latex, required this.isBlock});
}

