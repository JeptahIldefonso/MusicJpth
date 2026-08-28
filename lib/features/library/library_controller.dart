import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import '../../data/repositories/song_repository.dart'
    show LibraryCursor, SongRepository;
import '../../core/errors/app_error.dart';
import '../../data/repositories/song_repository_provider.dart';

/// Rows fetched per database page. Small enough to keep memory flat on a
/// 10,000-song library, large enough that scrolling costs one query every few
/// screens (`REQUIREMENTS.md` §21).
const int _pageSize = 200;

enum LibraryStatus { initial, loading, ready, error }

/// Everything the Library screen needs: the loaded window of songs and whether
/// more exist. Songs live in SQLite; only the currently shown pages are held
/// here (`PROJECT.md` §09).
@immutable
class LibraryState {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.songs = const <Song>[],
    this.hasMore = false,
    this.failure,
  });

  final LibraryStatus status;
  final List<Song> songs;

  /// Whether another page can be fetched.
  final bool hasMore;

  /// Diagnostic text, not user-facing copy.
  final String? failure;

  bool get isEmpty => status == LibraryStatus.ready && songs.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LibraryState &&
      other.status == status &&
      other.songs.length == songs.length &&
      other.hasMore == hasMore &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, songs.length, hasMore, failure);
}

/// Pages the song list out of SQLite on demand, keyset-style.
///
/// `build` touches nothing, so opening the Library tab never opens the
/// database before it is needed; the first page loads when the screen asks for
/// it. Pagination carries a [LibraryCursor] instead of an OFFSET, so page N
/// costs the same as page 1 no matter how deep the scroll, and there is no
/// COUNT(*) per load — a short page is all the end-of-list proof needed.
class LibraryController extends Notifier<LibraryState> {
  LibraryCursor? _cursor;

  @override
  LibraryState build() => const LibraryState();

  /// Loads the first page, replacing whatever was held before.
  Future<void> loadInitial() async {
    if (state.status == LibraryStatus.loading) return;
    _cursor = null;
    state = const LibraryState(status: LibraryStatus.loading);
    await _load(reset: true);
  }

  /// Fetches the next page and appends it. A call while a page is already in
  /// flight is ignored — two appends would duplicate rows. Also allowed after
  /// an error so the list's retry footer can re-fetch the failed page.
  Future<void> loadMore() async {
    final bool blocked =
        state.status != LibraryStatus.ready &&
        state.status != LibraryStatus.error;
    if (blocked || !state.hasMore) return;
    state = LibraryState(
      status: LibraryStatus.loading,
      songs: state.songs,
      hasMore: true,
    );
    await _load();
  }

  /// Permanently removes a song from the library after the physical file
  /// has been deleted by the platform. The caller must handle the platform
  /// deletion flow first.
  Future<bool> removeSongFromDatabase(int songId) async {
    try {
      final SongRepository repository = await ref.read(
        songRepositoryProvider.future,
      );
      final bool removed = await repository.removeFromDatabase(songId);
      if (removed) await loadInitial();
      return removed;
    } on Object catch (_) {
      return false;
    }
  }

  Future<void> _load({bool reset = false}) async {
    try {
      final SongRepository repository = await ref.read(
        songRepositoryProvider.future,
      );
      final List<Song> page = await repository.page(
        limit: _pageSize,
        after: _cursor,
      );

      final List<Song> songs = reset ? page : <Song>[...state.songs, ...page];
      if (songs.isNotEmpty) {
        _cursor = LibraryCursor.fromSong(songs.last);
      }

      // A short page is proof there is nothing left to fetch.
      state = LibraryState(
        status: LibraryStatus.ready,
        songs: songs,
        hasMore: page.length == _pageSize,
      );
    } on Object catch (_) {
      state = LibraryState(
        status: LibraryStatus.error,
        songs: state.songs,
        hasMore: state.hasMore,
        failure: AppError.message(ErrorDomain.database),
      );
    }
  }
}

final NotifierProvider<LibraryController, LibraryState> libraryProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);
