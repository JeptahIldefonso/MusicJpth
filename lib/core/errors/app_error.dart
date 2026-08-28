/// Which layer an error came from — coarse on purpose.
///
/// The app deliberately has no exception hierarchy (`REQUIREMENTS.md` §42:
/// simple, predictable, user-friendly). A caught error keeps its stack out of
/// the UI and gets one of these six concise messages instead.
enum ErrorDomain {
  /// SQLite could not be opened or queried.
  database,

  /// A watched folder or audio file could not be read.
  filesystem,

  /// The OS refused access that the flow needs.
  permissions,

  /// Tags or covers could not be parsed from a file.
  metadata,

  /// The audio engine could not play a track.
  playback,

  /// Anything else — the fallback.
  unexpected,
}

/// The one place user-facing error copy comes from.
abstract final class AppError {
  const AppError._();

  static const String databaseMessage =
      'Something went wrong reading the library.';
  static const String filesystemMessage = 'A music folder could not be read.';
  static const String permissionsMessage =
      'Permission to read your music is missing.';
  static const String metadataMessage = 'Some file details could not be read.';
  static const String playbackMessage = 'This track could not be played.';
  static const String unexpectedMessage = 'Something went wrong.';

  /// Concise, safe text for [domain]: no exception types, no platform detail,
  /// no stack traces. Retry affordances live in the screens, not here.
  static String message(ErrorDomain domain) => switch (domain) {
    ErrorDomain.database => databaseMessage,
    ErrorDomain.filesystem => filesystemMessage,
    ErrorDomain.permissions => permissionsMessage,
    ErrorDomain.metadata => metadataMessage,
    ErrorDomain.playback => playbackMessage,
    ErrorDomain.unexpected => unexpectedMessage,
  };
}
