import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../core/errors/app_error.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/playlist_repository_provider.dart';

/// Rows fetched per page in a playlist detail view.
const int detailPageSize = 200;

@immutable
class PlaylistsState {
  const PlaylistsState({
    this.items = const <Playlist>[],
    this.covers = const <int, List<String?>>{},
    this.failure,
  });

  final List<Playlist> items;

  /// Up to four distinct cover paths per playlist, fetched in one query.
  final Map<int, List<String?>> covers;

  /// Diagnostic text, not user-facing copy.
  final String? failure;

  @override
  bool operator ==(Object other) =>
      other is PlaylistsState &&
      listEquals(other.items, items) &&
      _coversEqual(other.covers, covers) &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    Object.hashAll(covers.entries),
    failure,
  );

  static bool _coversEqual(
    Map<int, List<String?>> a,
    Map<int, List<String?>> b,
  ) {
    if (a.length != b.length) return false;
    for (final MapEntry<int, List<String?>> entry in a.entries) {
      if (!listEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
}

/// Owns the playlists list screen's data. `build` touches nothing; the first
/// load happens when the tab asks for it, and every mutation refreshes from
/// SQLite so counts stay honest.
class PlaylistsController extends Notifier<PlaylistsState> {
  @override
  PlaylistsState build() => const PlaylistsState();

  Future<void> load() async {
    try {
      final PlaylistRepository repository = await ref.read(
        playlistRepositoryProvider.future,
      );
      state = PlaylistsState(
        items: await repository.list(),
        covers: await repository.covers(),
      );
    } on Object catch (_) {
      state = PlaylistsState(failure: AppError.message(ErrorDomain.database));
    }
  }

  /// Returns null on success, otherwise user-facing copy for the failure.
  Future<String?> create(String name) => _mutate(() async {
    final PlaylistRepository repository = await ref.read(
      playlistRepositoryProvider.future,
    );
    await repository.create(name);
    state = PlaylistsState(
      items: await repository.list(),
      covers: await repository.covers(),
    );
  });

  Future<String?> rename(int id, String name) => _mutate(() async {
    final PlaylistRepository repository = await ref.read(
      playlistRepositoryProvider.future,
    );
    await repository.rename(id, name);
    state = PlaylistsState(
      items: await repository.list(),
      covers: await repository.covers(),
    );
  });

  Future<String?> delete(int id) => _mutate(() async {
    final PlaylistRepository repository = await ref.read(
      playlistRepositoryProvider.future,
    );
    await repository.delete(id);
    state = PlaylistsState(
      items: await repository.list(),
      covers: await repository.covers(),
    );
  });

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on PlaylistNameTaken {
      return 'That name is already in use.';
    } on Object catch (_) {
      return AppError.message(ErrorDomain.database);
    }
  }
}

final NotifierProvider<PlaylistsController, PlaylistsState> playlistsProvider =
    NotifierProvider<PlaylistsController, PlaylistsState>(
      PlaylistsController.new,
    );

@immutable
class PlaylistDetailState {
  const PlaylistDetailState({
    this.status = DetailStatus.initial,
    this.songs = const <Song>[],
    this.failure,
  });

  final DetailStatus status;
  final List<Song> songs;
  final String? failure;

  @override
  bool operator ==(Object other) =>
      other is PlaylistDetailState &&
      other.status == status &&
      listEquals(other.songs, songs) &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, Object.hashAll(songs), failure);
}

enum DetailStatus { initial, loading, ready }

/// What adding a song to a playlist actually did. Never fabricated: a value is
/// only returned after the database transaction confirmed (or refused) the
/// insert.
enum AddSongResult {
  /// The membership row was inserted and committed.
  added,

  /// The song already had a membership row in this playlist; nothing changed.
  duplicate,

  /// The insert failed; the database reports the outcome, never the UI.
  error,
}

/// What adding a batch of songs to a playlist did. Never fabricated: counts are
/// only meaningful after the database transaction committed.
@immutable
class AddSongsResult {
  const AddSongsResult({
    required this.added,
    required this.duplicates,
    this.failed = false,
  });

  /// Songs whose membership row now exists in the playlist.
  final int added;

  /// Songs that were already members and skipped.
  final int duplicates;

  /// The transaction failed and nothing was added.
  final bool failed;
}

/// One playlist's contents. Family-scoped by playlist id.
///
/// Contents are fetched page by page ([detailPageSize]) until a short page
/// proves the end — bounded queries per `REQUIREMENTS.md` §21 without ever
/// asking the caller to drive pagination.
class PlaylistDetailController
    extends FamilyNotifier<PlaylistDetailState, int> {
  @override
  PlaylistDetailState build(int arg) {
    return const PlaylistDetailState(status: DetailStatus.initial);
  }

  /// Reloads from the first page — after any mutation or on entry.
  Future<void> load() async {
    if (state.status == DetailStatus.loading) return;
    state = const PlaylistDetailState(status: DetailStatus.loading);
    await _load();
  }

  /// Adds [songId] to this playlist and confirms the outcome in the database.
  ///
  /// Returns [AddSongResult.added] only after the membership insert committed,
  /// [AddSongResult.duplicate] when the song was already a member (no write
  /// happens), or [AddSongResult.error] when the insert failed.
  Future<AddSongResult> addSong(int songId) async {
    debugPrint('PLAYLIST_TRACE: addSong playlist=$arg song=$songId');
    try {
      final PlaylistRepository repository = await ref.read(
        playlistRepositoryProvider.future,
      );
      final bool already = await repository.containsSong(arg, songId);
      if (already) {
        debugPrint('PLAYLIST_TRACE: duplicate, no insert');
        return AddSongResult.duplicate;
      }
      await repository.addSong(arg, songId);
      await _load();
      final bool persisted = await repository.containsSong(arg, songId);
      debugPrint('PLAYLIST_TRACE: insert commit, persisted=$persisted');
      return persisted ? AddSongResult.added : AddSongResult.error;
    } on Object catch (_) {
      debugPrint('PLAYLIST_TRACE: insert failed');
      state = PlaylistDetailState(
        status: state.status,
        songs: state.songs,
        failure: AppError.message(ErrorDomain.unexpected),
      );
      return AddSongResult.error;
    }
  }

  /// Adds a batch of songs (skipping duplicates) and reloads the detail.
  ///
  /// The playlist list's counts refresh so the row number stays honest.
  Future<AddSongsResult> addSongs(List<int> songIds) async {
    debugPrint('PLAYLIST_TRACE: addSongs playlist=$arg count=${songIds.length}');
    try {
      final PlaylistRepository repository = await ref.read(
        playlistRepositoryProvider.future,
      );
      final ({int added, int duplicates}) outcome = await repository.addSongs(
        arg,
        songIds,
      );
      await _load();
      if (outcome.added > 0) {
        await ref.read(playlistsProvider.notifier).load();
      }
      debugPrint(
        'PLAYLIST_TRACE: addSongs committed added=${outcome.added} '
        'duplicates=${outcome.duplicates}',
      );
      return AddSongsResult(
        added: outcome.added,
        duplicates: outcome.duplicates,
      );
    } on Object catch (_) {
      debugPrint('PLAYLIST_TRACE: addSongs failed');
      state = PlaylistDetailState(
        status: state.status,
        songs: state.songs,
        failure: AppError.message(ErrorDomain.unexpected),
      );
      return const AddSongsResult(added: 0, duplicates: 0, failed: true);
    }
  }

  Future<void> removeAt(int position) => _mutate(() async {
    final PlaylistRepository repository = await ref.read(
      playlistRepositoryProvider.future,
    );
    await repository.removeAt(arg, position);
    await _load();
    // The playlist list shows per-playlist counts; keep them honest.
    await ref.read(playlistsProvider.notifier).load();
  });

  Future<void> move({required int from, required int to}) async {
    if (from == to) return;
    // Optimistic reorder; the repository confirms against the database.
    final List<Song> songs = <Song>[...state.songs];
    if (from >= songs.length || to >= songs.length) return;
    songs.insert(to, songs.removeAt(from));
    state = PlaylistDetailState(
      status: DetailStatus.ready,
      songs: songs,
      failure: state.failure,
    );

    try {
      final PlaylistRepository repository = await ref.read(
        playlistRepositoryProvider.future,
      );
      await repository.move(arg, from: from, to: to);
      await _load();
    } on Object catch (_) {
      state = PlaylistDetailState(
        status: DetailStatus.ready,
        songs: state.songs,
        failure: AppError.message(ErrorDomain.unexpected),
      );
    }
  }

  Future<void> _load() async {
    try {
      final PlaylistRepository repository = await ref.read(
        playlistRepositoryProvider.future,
      );
      final List<Song> songs = <Song>[];
      int offset = 0;
      while (true) {
        final List<Song> page = await repository.songs(
          arg,
          limit: detailPageSize,
          offset: offset,
        );
        songs.addAll(page);
        if (page.length < detailPageSize) break;
        offset += detailPageSize;
      }
      state = PlaylistDetailState(status: DetailStatus.ready, songs: songs);
    } on Object catch (_) {
      state = PlaylistDetailState(
        status: state.status,
        songs: const <Song>[],
        failure: AppError.message(ErrorDomain.unexpected),
      );
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (_) {
      state = PlaylistDetailState(
        status: state.status,
        songs: state.songs,
        failure: AppError.message(ErrorDomain.unexpected),
      );
    }
  }
}

typedef PlaylistDetailFamily =
    NotifierProviderFamily<PlaylistDetailController, PlaylistDetailState, int>;

final PlaylistDetailFamily playlistDetailProvider =
    NotifierProvider.family<PlaylistDetailController, PlaylistDetailState, int>(
      PlaylistDetailController.new,
    );
