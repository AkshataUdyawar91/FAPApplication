import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Opens the browser's front-facing camera via an HTML input element.
/// Returns the captured image bytes, or null if cancelled.
Future<Uint8List?> captureFromWebCamera() async {
  final completer = Completer<Uint8List?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..setAttribute('capture', 'user');

  web.document.body!.append(input);

  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.addEventListener(
        'loadend',
        (web.Event _) {
          final result = reader.result;
          if (result != null) {
            // result is JSArrayBuffer — convert to Uint8List
            final jsBuffer = result as JSArrayBuffer;
            final bytes = jsBuffer.toDart.asUint8List();
            input.remove();
            completer.complete(bytes);
          } else {
            input.remove();
            completer.complete(null);
          }
        }.toJS,
      );

      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  input.click();
  return completer.future;
}
