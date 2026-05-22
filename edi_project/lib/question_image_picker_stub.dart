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

Future<PickedQuestionImage?> pickQuestionImage() async => null;

Future<List<PickedQuestionImage>> pickQuestionImages() async => const [];
