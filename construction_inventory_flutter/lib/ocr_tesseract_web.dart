import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

Future<String> recognizeImageBytesWeb(Uint8List bytes) async {
  final tesseract = js_util.getProperty(html.window, 'Tesseract');
  if (tesseract == null) {
    throw Exception('Tesseract.js is not loaded. Add the Tesseract.js script to web/index.html.');
  }

  final blob = html.Blob([bytes], 'image/*');
  final promise = js_util.callMethod(tesseract, 'recognize', [blob, 'eng']);
  final result = await js_util.promiseToFuture(promise);
  final data = js_util.getProperty(result, 'data');
  final text = js_util.getProperty(data, 'text');
  return text is String ? text : text?.toString() ?? '';
}
