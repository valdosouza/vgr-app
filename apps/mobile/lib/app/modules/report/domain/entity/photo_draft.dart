import 'package:equatable/equatable.dart';

/// One captured evidence photo waiting to ride with the report.
///
/// `keepOriginal` is the reporter's PER-PHOTO choice (decision 130):
/// default discards the EXIF-bearing original; keeping it requires having
/// seen the warning, whose text version travels with the upload
/// (decision 86 pattern).
class PhotoDraft extends Equatable {
  const PhotoDraft({
    required this.path,
    this.keepOriginal = false,
    this.exifWarningVersion,
  });

  final String path;
  final bool keepOriginal;
  final String? exifWarningVersion;

  PhotoDraft copyWith({bool? keepOriginal, String? exifWarningVersion}) => PhotoDraft(
        path: path,
        keepOriginal: keepOriginal ?? this.keepOriginal,
        exifWarningVersion: exifWarningVersion ?? this.exifWarningVersion,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'keepOriginal': keepOriginal,
        'exifWarningVersion': exifWarningVersion,
      };

  factory PhotoDraft.fromJson(Map<String, dynamic> json) => PhotoDraft(
        path: json['path'] as String,
        keepOriginal: json['keepOriginal'] as bool? ?? false,
        exifWarningVersion: json['exifWarningVersion'] as String?,
      );

  @override
  List<Object?> get props => [path, keepOriginal, exifWarningVersion];
}
