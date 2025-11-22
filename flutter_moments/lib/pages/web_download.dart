// Web平台的下载实现
import 'dart:html' as html;

void downloadFileOnWeb(String url, String filename) {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
}

