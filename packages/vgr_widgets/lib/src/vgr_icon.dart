import 'package:flutter/material.dart';

/// Icons named by MEANING, never by drawing (decision 133).
///
/// Screens ask for `VgrIconName.delete`, not for `Icons.delete_outline`.
/// Changing the icon set — or moving off Material icons entirely — is a
/// change to this one map.
enum VgrIconName {
  add,
  edit,
  delete,
  save,
  copy,
  back,
  forward,
  search,
  refresh,
  check,
  close,
  warning,
  legal,
  security,
  person,
  group,
  settings,
  menu,
  visibility,
  language,
  money,
  location,
  alert,
  image,
  camera,
  gallery,
}

class VgrIcon extends StatelessWidget {
  const VgrIcon(this.name, {super.key, this.size, this.color});

  final VgrIconName name;
  final double? size;
  final Color? color;

  static IconData dataOf(VgrIconName name) => switch (name) {
        VgrIconName.add => Icons.add,
        VgrIconName.edit => Icons.edit,
        VgrIconName.delete => Icons.delete_outline,
        VgrIconName.save => Icons.save_outlined,
        VgrIconName.copy => Icons.copy,
        VgrIconName.back => Icons.arrow_back,
        VgrIconName.forward => Icons.arrow_forward,
        VgrIconName.search => Icons.search,
        VgrIconName.refresh => Icons.refresh,
        VgrIconName.check => Icons.check,
        VgrIconName.close => Icons.close,
        VgrIconName.warning => Icons.warning_amber_outlined,
        VgrIconName.legal => Icons.gavel,
        VgrIconName.security => Icons.shield_outlined,
        VgrIconName.person => Icons.person_outline,
        VgrIconName.group => Icons.group_outlined,
        VgrIconName.settings => Icons.settings_outlined,
        VgrIconName.menu => Icons.menu,
        VgrIconName.visibility => Icons.visibility_outlined,
        VgrIconName.language => Icons.language,
        VgrIconName.money => Icons.attach_money,
        VgrIconName.location => Icons.place_outlined,
        VgrIconName.alert => Icons.notifications_active_outlined,
        VgrIconName.image => Icons.image_outlined,
        VgrIconName.camera => Icons.photo_camera_outlined,
        VgrIconName.gallery => Icons.photo_library_outlined,
      };

  @override
  Widget build(BuildContext context) => Icon(dataOf(name), size: size, color: color);
}
