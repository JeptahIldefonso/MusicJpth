import 'package:flutter_test/flutter_test.dart';
import 'package:music_oasis/core/errors/app_error.dart';

void main() {
  test('every domain has concise, non-technical copy', () {
    for (final ErrorDomain domain in ErrorDomain.values) {
      final String message = AppError.message(domain);
      expect(message, isNotEmpty);
      // No raw exception/platform vocabulary leaks into user copy.
      expect(message.toLowerCase(), isNot(contains('exception')));
      expect(message.toLowerCase(), isNot(contains('sqlite')));
      expect(message.toLowerCase(), isNot(contains('error:')));
    }
  });

  test('each domain maps to its own constant', () {
    expect(AppError.message(ErrorDomain.database), AppError.databaseMessage);
    expect(
      AppError.message(ErrorDomain.filesystem),
      AppError.filesystemMessage,
    );
    expect(
      AppError.message(ErrorDomain.permissions),
      AppError.permissionsMessage,
    );
    expect(AppError.message(ErrorDomain.metadata), AppError.metadataMessage);
    expect(AppError.message(ErrorDomain.playback), AppError.playbackMessage);
    expect(
      AppError.message(ErrorDomain.unexpected),
      AppError.unexpectedMessage,
    );
  });

  test('playback copy stays generic — no engine codes or platform text', () {
    expect(AppError.playbackMessage, 'This track could not be played.');
  });
}
