import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../network/api_client.dart';
import '../data/current_user_repository_impl.dart';
import '../domain/current_user.dart';
import '../domain/current_user_repository.dart';
import '../logout.dart';

/// Who is signed in, plus the way out (decision 215 — ported from
/// setes-app's `UserBadge`). Reads `GET /api/core/me` once; while it
/// loads, or if it fails, the badge still offers "Sign out" — losing the
/// name must never lose the exit.
class UserBadge extends StatefulWidget {
  const UserBadge({
    super.key,
    required this.logoutLabel,
    required this.tooltip,
    this.repository,
    this.onLogout,
  });

  /// Pre-translated by the app (the design system speaks no i18n).
  final String logoutLabel;
  final String tooltip;

  /// Injectable for tests; defaults to the ApiClient-backed one.
  final CurrentUserRepository? repository;

  /// Test seam — defaults to [logoutAdminSession].
  final Future<void> Function()? onLogout;

  @override
  State<UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends State<UserBadge> {
  CurrentUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repository ?? CurrentUserRepositoryImpl(Modular.get<ApiClient>());
    final result = await repo.getMe();
    if (!mounted) return;
    result.fold((_) {}, (user) => setState(() => _user = user));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return VgrRow(
      children: [
        if (user != null)
          VgrText.caption(user.displayName, key: const Key('user-badge-name')),
        VgrMenuButton<String>(
          key: const Key('user-badge-menu'),
          icon: VgrIconName.person,
          tooltip: widget.tooltip,
          entriesBuilder: (_) => [
            VgrMenuEntry(
              key: const Key('user-badge-logout'),
              value: 'logout',
              label: widget.logoutLabel,
            ),
          ],
          onSelected: (_) => (widget.onLogout ?? logoutAdminSession)(),
        ),
      ],
    );
  }
}
