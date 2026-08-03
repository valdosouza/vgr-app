import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('home.title'.tr()),
        actions: const [LanguageSelector(persist: true)],
      ),
      body: BlocBuilder<MenuBloc, MenuState>(
        builder: (context, state) {
          return switch (state) {
            MenuLoading() => const Center(child: CircularProgressIndicator()),
            MenuError(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('menu-retry-button'),
                      onPressed: () =>
                          context.read<MenuBloc>().add(const MenuRequested()),
                      child: Text('home.retry'.tr()),
                    ),
                  ],
                ),
              ),
            MenuLoaded(:final tree) => tree.isEmpty
                ? Center(child: Text('home.emptyMenu'.tr()))
                : ListView(
                    children: [
                      for (final module in tree)
                        ExpansionTile(
                          key: Key('menu-module-${module.id ?? module.description}'),
                          initiallyExpanded: true,
                          title: Text(_moduleLabel(module)),
                          children: [
                            for (final screen in module.interfaces)
                              ListTile(
                                key: Key('menu-interface-${screen.i18nKey}'),
                                title: Text(_interfaceLabel(screen)),
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
