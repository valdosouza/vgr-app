import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../interface_routes.dart';

/// Menu assembled by the backend (GET /api/core/menus, decision 71): the
/// tree arrives filtered by the user's VIEW grants — nothing hardcoded.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Applies the user's server-saved locale after login/refresh (phase 5).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) applyUserLocale(context);
    });
  }

  String _moduleLabel(MenuModule module) {
    // Admin-managed modules translate via menu.modules.<i18nKey>;
    // pseudo-modules (group_default) via menu.groups.<lowercase>.
    if (module.i18nKey != null) {
      return trCatalog(
        prefix: 'menu.modules',
        key: module.i18nKey!,
        fallback: module.description,
      );
    }
    return trCatalog(
      prefix: 'menu.groups',
      key: module.description.toLowerCase(),
      fallback: module.description,
    );
  }

  String _interfaceLabel(MenuInterface screen) => trCatalog(
        prefix: 'menu.interfaces',
        key: screen.i18nKey,
        fallback: screen.description,
      );

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'home.title'.tr(),
      actions: const [LanguageSelector(persist: true)],
      padded: false,
      body: BlocBuilder<MenuBloc, MenuState>(
        builder: (context, state) {
          return switch (state) {
            MenuLoading() => const VgrLoading(),
            MenuError(:final message) => VgrCenter(
                child: VgrColumn(
                  children: [
                    VgrText.error(message),
                    const VgrGap.md(),
                    VgrPrimaryButton(
                      key: const Key('menu-retry-button'),
                      label: 'home.retry'.tr(),
                      onPressed: () => context.read<MenuBloc>().add(const MenuRequested()),
                    ),
                  ],
                ),
              ),
            MenuLoaded(:final tree) => tree.isEmpty
                ? VgrCenter(child: VgrText('home.emptyMenu'.tr()))
                : VgrListView(
                    children: [
                      for (final module in tree)
                        VgrExpansionTile(
                          key: Key('menu-module-${module.id ?? module.description}'),
                          initiallyExpanded: true,
                          title: _moduleLabel(module),
                          children: [
                            for (final screen in module.interfaces)
                              VgrListTile(
                                key: Key('menu-interface-${screen.i18nKey}'),
                                title: _interfaceLabel(screen),
                                onTap: () => navigateToInterface(screen),
                              ),
                          ],
                        ),
                    ],
                  ),
          };
        },
      ),
    );
  }
}
