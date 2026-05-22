// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class PickedQuestionImage {
  const PickedQuestionImage({
    required this.bytes,
    required this.name,
    required this.contentType,
  });

  final Uint8List bytes;
  final String name;
  final String contentType;
}

Future<PickedQuestionImage?> pickQuestionImage() async {
  final images = await pickQuestionImages(multiple: false);
  return images.isEmpty ? null : images.first;
}

Future<List<PickedQuestionImage>> pickQuestionImages({bool multiple = true}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg'
    ..multiple = multiple;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return const [];

  final picked = <PickedQuestionImage>[];
  for (final file in files) {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result is! ByteBuffer) continue;

    picked.add(PickedQuestionImage(
      bytes: Uint8List.view(result),
      name: file.name,
      contentType: file.type.isEmpty ? 'image/png' : file.type,
    ));
  }
  return picked;
}
