/// What playback should do about one platform audio-focus event
/// (`REQUIREMENTS.md` §13).
///
/// Pure decision logic, deliberately free of any package types: the handler
/// maps the platform event onto an [InterruptionKind], applies the returned
/// [InterruptionResponse]. Testable without channels.
enum InterruptionKind {
  /// Brief lowering of another app's claim — duck under it.
  duck,

  /// A pause-shaped loss (notification sounds, other players).
  pause,

  /// Unspecified loss — phone calls, rejected focus requests.
  unknown,
}

enum InterruptionResponse { ignore, duck, unduck, pause, resume }

class InterruptionPolicy {
  const InterruptionPolicy();

  /// Decision as an interruption begins. Silence ignores interruptions —
  /// taking focus behaviour into our own hands while idle would fight the
  /// platform.
  InterruptionResponse onStart(InterruptionKind kind, {required bool playing}) {
    if (!playing) return InterruptionResponse.ignore;
    return switch (kind) {
      InterruptionKind.duck => InterruptionResponse.duck,
      InterruptionKind.pause ||
      InterruptionKind.unknown => InterruptionResponse.pause,
    };
  }

  /// Decision as an interruption ends. Only losses this app responded to are
  /// undone, and only they may trigger a resume; `unknown` endings never
  /// auto-resume — after a phone call, the user presses play.
  InterruptionResponse onEnd(
    InterruptionKind kind, {
    required bool wasInterruptedWhilePlaying,
  }) {
    if (!wasInterruptedWhilePlaying) return InterruptionResponse.ignore;
    return switch (kind) {
      InterruptionKind.duck => InterruptionResponse.unduck,
      InterruptionKind.pause => InterruptionResponse.resume,
      InterruptionKind.unknown => InterruptionResponse.ignore,
    };
  }
}
