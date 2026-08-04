import 'package:image_picker/image_picker.dart';

import '../domain/gateway/photo_gateway.dart';

/// image_picker-backed adapter. Bytes are passed through as captured —
/// see the port's doc for the EXIF/HEIC contract.
class ImagePickerPhotoGateway implements PhotoGateway {
  ImagePickerPhotoGateway({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickFromCamera() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    return file?.path;
  }
}
