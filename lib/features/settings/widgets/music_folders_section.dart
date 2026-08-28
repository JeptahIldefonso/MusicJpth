import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/models/music_folder.dart';
import '../music_folders_controller.dart';

/// The folders Music Oasis scans, and the controls to change them.
class MusicFoldersSection extends ConsumerStatefulWidget {
  const MusicFoldersSection({super.key});

  @override
  ConsumerState<MusicFoldersSection> createState() =>
      _MusicFoldersSectionState();
}

class _MusicFoldersSectionState extends ConsumerState<MusicFoldersSection> {
  AddFolderOutcome? _outcome;
  bool _picking = false;

  Future<void> _addFolder() async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _outcome = null;
    });
    final AddFolderOutcome outcome = await ref
        .read(musicFoldersProvider.notifier)
        .addFolder();
    if (!mounted) return;
    setState(() {
      _picking = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MusicFolder>> folders = ref.watch(
      musicFoldersProvider,
    );
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);
    final String? message = _messageFor(_outcome);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'MUSIC FOLDERS',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            OutlinedButton(
              key: const ValueKey<String>('add-folder'),
              onPressed: _picking ? null : _addFolder,
              child: const Text('ADD FOLDER'),
            ),
          ],
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: MusicOasisSpacing.sm),
            child: Text(
              key: const ValueKey<String>('music-folders-message'),
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _outcome == AddFolderOutcome.duplicate
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: MusicOasisSpacing.md),
        Divider(color: tokens.hairline),
        folders.when(
          skipLoadingOnReload: true,
          loading: () => const SizedBox.shrink(),
          error: (Object error, StackTrace _) => Padding(
            padding: const EdgeInsets.only(top: MusicOasisSpacing.md),
            child: Text(
              key: const ValueKey<String>('music-folders-error'),
              'LIBRARY UNAVAILABLE — Could not read your music folders.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          data: (List<MusicFolder> value) => value.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: MusicOasisSpacing.md),
                  child: Text(
                    key: const ValueKey<String>('music-folders-empty'),
                    'MUSIC ACCESS REQUIRED — Choose a music folder to '
                    'build your library.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : _FolderList(folders: value),
        ),
      ],
    );
  }

  static String? _messageFor(AddFolderOutcome? outcome) => switch (outcome) {
    null || AddFolderOutcome.added || AddFolderOutcome.cancelled => null,
    AddFolderOutcome.duplicate =>
      'ALREADY IN YOUR LIBRARY — This folder is already being scanned.',
    AddFolderOutcome.denied =>
      'MUSIC ACCESS REQUIRED — Choose a music folder to build your library.',
    AddFolderOutcome.missing =>
      'FOLDER UNAVAILABLE — This folder may have been moved or deleted.',
    AddFolderOutcome.failed =>
      'FOLDER UNAVAILABLE — Music Jpth could not add that folder.',
  };
}

class _FolderList extends ConsumerWidget {
  const _FolderList({required this.folders});

  final List<MusicFolder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);

    return Column(
      children: [
        for (int i = 0; i < folders.length; i++) ...[
          if (i > 0) Divider(color: tokens.hairline),
          ListTile(
            key: ValueKey<String>('music-folder-${folders[i].id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              folders[i].path,
              style: tokens.metadata,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              key: ValueKey<String>('remove-folder-${folders[i].id}'),
              tooltip: 'Remove folder',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(musicFoldersProvider.notifier).removeFolder(folders[i].id),
            ),
          ),
        ],
      ],
    );
  }
}
