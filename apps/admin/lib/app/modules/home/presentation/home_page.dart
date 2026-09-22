import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../interface_routes.dart';

/// The panel shell (decision 215, setes-app layout): app bar with the
/// language selector and the user badge (sign out), then the menu as two
/// navigation columns — modules, screens of the selected module — beside
/// a `RouterOutlet` where the picked screen renders. Below 850 px the
/// columns collapse into a drawer.
///
/// The menu tree comes assembled by the backend (GET /api/core/menus,
/// decision 71), already filtered by the user's VIEW grants — nothing
/// hardcoded. Selection is by CLICK, never hover.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<MenuBloc>();
    if (bloc.state is! MenuLoaded) bloc.add(const MenuRequested());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Applies the user's server-saved locale after login/refresh (phase 5).
      applyUserLocale(context);
      // The outlet needs an active child route: a plain login lands on `/`,
      // so open the welcome content; a refresh on `/reports/` keeps it and
      // the columns highlight the screen the URL already shows.
      final path = Modular.to.path;
      if (path == '/' || path.isEmpty) {
        Modular.to.navigate(welcomeRoute);
      } else {
        final key = interfaceKeyForPath(path);
        if (key != null) bloc.add(MenuInterfaceSelected(key));
      }
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

  void _openScreen(BuildContext context, MenuInterface screen) {
    context.read<MenuBloc>().add(MenuInterfaceSelected(screen.i18nKey));
    navigateToInterface(screen);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuBloc, MenuState>(
      builder: (context, state) => VgrResponsive(
        desktop: _desktop(context, state),
        mobile: _mobile(context, state),
      ),
    );
  }

  List<Widget> get _appBarActions => [
        const LanguageSelector(persist: true),
        UserBadge(
          logoutLabel: 'home.logout'.tr(),
          tooltip: 'home.account'.tr(),
        ),
      ];

  // ---- desktop: two columns + outlet -------------------------------------

  Widget _desktop(BuildContext context, MenuState state) {
    return VgrScaffold(
      title: 'home.title'.tr(),
      actions: _appBarActions,
      padded: false,
      body: VgrSidebarLayout(
        sidebars: _columns(context, state),
        content: const RouterOutlet(),
      ),
    );
  }

  List<Widget> _columns(BuildContext context, MenuState state) {
    return switch (state) {
      MenuLoading() => [
          const VgrNavColumn(key: Key('shell-modules-column'), children: [VgrLoading()]),
        ],
      MenuError(:final message) => [
          VgrNavColumn(key: const Key('shell-modules-column'), children: [_menuError(context, message)]),
        ],
      MenuLoaded(:final tree) => [
          VgrNavColumn(
            key: const Key('shell-modules-column'),
            children: tree.isEmpty
                ? [VgrPadding(child: VgrText.caption('home.emptyMenu'.tr()))]
                : [
                    for (var index = 0; index < tree.length; index++)
                      VgrListTile(
                        key: Key('menu-module-${tree[index].id ?? tree[index].description}'),
                        title: _moduleLabel(tree[index]),
                        leadingIcon: VgrIconName.menu,
                        selected: state.selectedModuleIndex == index,
                        onTap: () => context.read<MenuBloc>().add(MenuModuleSelected(index)),
                      ),
                  ],
          ),
          if (state.selectedModule != null)
            VgrNavColumn(
              key: const Key('shell-screens-column'),
              width: 240,
              level: 1,
              children: [
                for (final screen in state.selectedModule!.interfaces)
                  VgrListTile(
                    key: Key('menu-interface-${screen.i18nKey}'),
                    title: _interfaceLabel(screen),
                    selected: state.selectedInterfaceKey == screen.i18nKey,
                    onTap: () => _openScreen(context, screen),
                  ),
              ],
            ),
        ],
    };
  }

  // ---- mobile: drawer + outlet --------------------------------------------

  Widget _mobile(BuildContext context, MenuState state) {
    return VgrScaffold(
      title: 'home.title'.tr(),
      actions: _appBarActions,
      padded: false,
      drawer: VgrDrawer(
        key: const Key('shell-drawer'),
        children: switch (state) {
          MenuLoading() => const [VgrLoading()],
          MenuError(:final message) => [_menuError(context, message)],
          MenuLoaded(:final tree) => tree.isEmpty
              ? [VgrPadding(child: VgrText.caption('home.emptyMenu'.tr()))]
              : [
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
                            selected: state.selectedInterfaceKey == screen.i18nKey,
                            onTap: () {
                              Navigator.of(context).pop(); // close the drawer
                              _openScreen(context, screen);
                            },
                          ),
                      ],
                    ),
                ],
        },
      ),
      body: const RouterOutlet(),
    );
  }

  Widget _menuError(BuildContext context, String message) {
    return VgrPadding(
      child: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
