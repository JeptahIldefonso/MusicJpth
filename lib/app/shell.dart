import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/app_platform.dart';
import '../core/widgets/brand_header.dart';
import '../features/player/widgets/mini_player.dart';
import 'router.dart';
import 'theme.dart';

/// Adaptive application chrome around the routed content.
///
/// Mobile: smoked-glass 4-tab bottom bar with sharp icons.
/// Desktop: 220px left sidebar with uppercase sans-serif labels.
/// Both: persistent mini-player above/below navigation.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return AppPlatform.isDesktop
        ? _DesktopShell(navigationShell: navigationShell)
        : _MobileShell(navigationShell: navigationShell);
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.branch,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int branch;
}

const List<_Destination> _destinations = <_Destination>[
  _Destination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'HOME',
    branch: AppBranch.home,
  ),
  _Destination(
    icon: Icons.search,
    activeIcon: Icons.search,
    label: 'SEARCH',
    branch: AppBranch.search,
  ),
  _Destination(
    icon: Icons.library_music_outlined,
    activeIcon: Icons.library_music,
    label: 'LIBRARY',
    branch: AppBranch.library,
  ),
  _Destination(
    icon: Icons.queue_music_outlined,
    activeIcon: Icons.queue_music,
    label: 'PLAYLISTS',
    branch: AppBranch.playlists,
  ),
];

/// ─── Mobile ────────────────────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(child: navigationShell),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: _SmokedGlassNavBar(
        navigationShell: navigationShell,
      ),
    );
  }
}

/// Spotify-style transparent bottom nav bar — heavy backdrop blur, no border,
/// icon-only tabs so the background gradient or wallpaper bleeds through.
class _SmokedGlassNavBar extends StatelessWidget {
  const _SmokedGlassNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          // Near-fully-transparent — just a hint of dark so icons remain legible
          color: Colors.black.withValues(alpha: 0.35),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MusicOasisNav.mobileTabBarHeight,
              child: Row(
                children: <Widget>[
                  for (final _Destination dest in _destinations)
                    Expanded(
                      child: _MobileTab(
                        key: ValueKey<String>('mobile-nav-${dest.label}'),
                        destination: dest,
                        selected:
                            navigationShell.currentIndex == dest.branch,
                        onTap: () =>
                            _goBranch(navigationShell, dest.branch),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTab extends StatelessWidget {
  const _MobileTab({
    required this.destination,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Spotify-style: bright white when active, dim grey when inactive
    final Color color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.45);

    return Semantics(
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        splashFactory: InkRipple.splashFactory,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              selected ? destination.activeIcon : destination.icon,
              size: selected ? 27 : 24,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Desktop ───────────────────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          SizedBox(
            width: MusicOasisNav.sidebarWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MusicOasisTokens.of(context).chrome,
                border: Border(
                  right: BorderSide(
                    color: MusicOasisTokens.of(context).hairline,
                    width: MusicOasisSpacing.hairline,
                  ),
                ),
              ),
              child: _Sidebar(navigationShell: navigationShell),
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: navigationShell),
                const MiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MusicOasisSpacing.md + MusicOasisSpacing.hairline,
            MusicOasisSpacing.lg,
            MusicOasisSpacing.md,
            MusicOasisSpacing.xl,
          ),
          child: const BrandHeader(
            size: 22,
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        for (final _Destination dest in _destinations)
          _SidebarItem(
            key: ValueKey<String>('desktop-nav-${dest.label}'),
            destination: dest,
            selected: navigationShell.currentIndex == dest.branch,
            onTap: () => _goBranch(navigationShell, dest.branch),
          ),
        const Spacer(),
        _SidebarItem(
          key: const ValueKey<String>('desktop-nav-SETTINGS'),
          destination: const _Destination(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'SETTINGS',
            branch: -1,
          ),
          selected: false,
          onTap: () => context.push(AppRoutes.settings),
        ),
        const SizedBox(height: MusicOasisSpacing.md),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: MusicOasisNav.sidebarItemHeight,
          child: Row(
            children: <Widget>[
              Container(
                width: 2,
                height: MusicOasisNav.sidebarItemHeight,
                color: selected ? color : Colors.transparent,
              ),
              const SizedBox(width: MusicOasisSpacing.md),
              Icon(
                selected ? destination.activeIcon : destination.icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: MusicOasisSpacing.sm),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _goBranch(StatefulNavigationShell navigationShell, int branch) {
  navigationShell.goBranch(
    branch,
    initialLocation: branch == navigationShell.currentIndex,
  );
}
