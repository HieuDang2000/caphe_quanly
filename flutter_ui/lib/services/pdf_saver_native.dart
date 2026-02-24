import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<bool> savePdfNative({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      const XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']),
    ],
  );
  if (location == null) return false;
  final file = File(location.path);
  await file.writeAsBytes(bytes);
  return true;
}
