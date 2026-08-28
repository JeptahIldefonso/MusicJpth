import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/services/audio/interruption_policy.dart';

void main() {
  const InterruptionPolicy policy = InterruptionPolicy();

  group('InterruptionPolicy.onStart', () {
    test('ducks while playing', () {
      expect(
        policy.onStart(InterruptionKind.duck, playing: true),
        InterruptionResponse.duck,
      );
    });

    test('pauses for pause-shaped losses while playing', () {
      expect(
        policy.onStart(InterruptionKind.pause, playing: true),
        InterruptionResponse.pause,
      );
      expect(
        policy.onStart(InterruptionKind.unknown, playing: true),
        InterruptionResponse.pause,
      );
    });

    test('silence ignores every interruption', () {
      for (final InterruptionKind kind in InterruptionKind.values) {
        expect(
          policy.onStart(kind, playing: false),
          InterruptionResponse.ignore,
        );
      }
    });
  });

  group('InterruptionPolicy.onEnd', () {
    test('unducks what it ducked and resumes what it paused', () {
      expect(
        policy.onEnd(InterruptionKind.duck, wasInterruptedWhilePlaying: true),
        InterruptionResponse.unduck,
      );
      expect(
        policy.onEnd(InterruptionKind.pause, wasInterruptedWhilePlaying: true),
        InterruptionResponse.resume,
      );
    });

    test('never undoes an interruption it did not act on', () {
      for (final InterruptionKind kind in InterruptionKind.values) {
        expect(
          policy.onEnd(kind, wasInterruptedWhilePlaying: false),
          InterruptionResponse.ignore,
        );
      }
    });

    test('a phone call (unknown) never auto-resumes', () {
      expect(
        policy.onEnd(
          InterruptionKind.unknown,
          wasInterruptedWhilePlaying: true,
        ),
        InterruptionResponse.ignore,
      );
    });
  });
}
