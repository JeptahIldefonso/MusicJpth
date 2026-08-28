import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../scanner/widgets/scan_section.dart';
import 'widgets/music_folders_section.dart';
import 'widgets/skin_theme_section.dart';

/// Settings surface: skin themes, music folders and library scan.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Header row with back button ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MusicOasisSpacing.xs,
                MusicOasisSpacing.sm,
                MusicOasisSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    key: const ValueKey<String>('settings-back'),
                    tooltip: 'Back',
                    icon: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: MusicOasisSpacing.xs),
                  Text('SETTINGS', style: theme.textTheme.displaySmall),
                ],
              ),
            ),
            const SizedBox(height: MusicOasisSpacing.sm),
            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MusicOasisSpacing.lg,
                  MusicOasisSpacing.sm,
                  MusicOasisSpacing.lg,
                  MusicOasisSpacing.lg,
                ),
                children: <Widget>[
                  const SkinThemeSection(),
                  const SizedBox(height: MusicOasisSpacing.lg),
                  const MusicFoldersSection(),
                  const SizedBox(height: MusicOasisSpacing.lg),
                  Divider(color: tokens.hairline),
                  const SizedBox(height: MusicOasisSpacing.lg),
                  const ScanSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
