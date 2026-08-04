/// Port for evidence capture (decisions 129/130). Returns the picked
/// image's local file path, or null when the user cancels.
///
/// The captured bytes are sent AS CAPTURED: the EXIF choice belongs to the
/// server pipeline (`keepOriginal` per photo — the server always strips
/// the normalized variant and preserves the encrypted original only when
/// asked). HEIC→JPEG conversion at capture (M1 amendment) is this
/// gateway's job on iOS builds — not wired while the MVP targets Android.
abstract class PhotoGateway {
  Future<String?> pickFromCamera();
  Future<String?> pickFromGallery();
}
