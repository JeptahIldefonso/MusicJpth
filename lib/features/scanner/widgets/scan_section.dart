import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/platform/app_platform.dart';
import '../../../services/scanner/music_scanner_service.dart';
import '../scanner_controller.dart';

/// Technical scan progress display with monospace counts.
class ScanSection extends ConsumerWidget {
  const ScanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScannerState scan = ref.watch(scannerProvider);
    final ThemeData theme = Theme.of(context);
    final MusicOasisTokens tokens = MusicOasisTokens.of(context);
    final bool failed = scan.status == ScanStatus.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'LIBRARY SCAN',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MusicOasisSpacing.md),
        Divider(color: tokens.hairline),
        const SizedBox(height: MusicOasisSpacing.sm),
        Text(
          key: const ValueKey<String>('scan-status'),
          _statusFor(scan),
          style: theme.textTheme.bodySmall?.copyWith(
            color: failed
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (scan.isScanning) ...<Widget>[
          const SizedBox(height: MusicOasisSpacing.sm),
          LinearProgressIndicator(
            value: null,
            minHeight: 2,
            backgroundColor: tokens.hairline,
            color: theme.colorScheme.onSurface,
          ),
        ],
        const SizedBox(height: MusicOasisSpacing.md),
        Row(
          children: <Widget>[
            if (scan.needsSystemSettings)
              Padding(
                padding: const EdgeInsets.only(right: MusicOasisSpacing.sm),
                child: OutlinedButton(
                  key: const ValueKey<String>('open-permission-settings'),
                  onPressed: () => ref
                      .read(mediaPermissionGateProvider)
                      .openSystemSettings(),
                  child: const Text('OPEN SETTINGS'),
                ),
              ),
            OutlinedButton(
              key: const ValueKey<String>('scan-library'),
              onPressed: scan.isScanning
                  ? ref.read(scannerProvider.notifier).cancel
                  : ref.read(scannerProvider.notifier).scan,
              child: Text(scan.isScanning ? 'CANCEL' : 'SCAN LIBRARY'),
            ),
          ],
        ),
      ],
    );
  }

  static String _statusFor(ScannerState scan) {
    if (scan.reason != null) {
      return switch (scan.reason!) {
        ScanBlockReason.noFolders =>
          'MUSIC ACCESS REQUIRED — Choose a music folder to build your '
              'library.',
        ScanBlockReason.permissionDenied =>
          'MUSIC ACCESS REQUIRED — Allow Music Jpth to read your audio '
              'files, then scan again.',
        ScanBlockReason.permissionPermanentlyDenied =>
          'MUSIC ACCESS REQUIRED — Open system settings and allow audio '
              'access.',
        ScanBlockReason.foldersUnreadable =>
          'FOLDER UNAVAILABLE — This folder may have been moved or deleted.',
      };
    }

    return switch (scan.status) {
      ScanStatus.idle when AppPlatform.isAndroid =>
        'READY TO SCAN — Music Jpth will ask to read your audio files.',
      ScanStatus.idle => 'NOT SCANNED YET',
      ScanStatus.scanning => 'SCANNING — ${_count(scan.found)} FILES FOUND',
      ScanStatus.cancelled =>
        'SCAN CANCELLED — ${_count(scan.found)} FILES FOUND',
      ScanStatus.completed =>
        '${_count(scan.found)} SCANNED · ${_count(scan.added)} ADDED · '
            '${_count(scan.updated)} UPDATED · ${_count(scan.missing)} MISSING',
      ScanStatus.error =>
        'SCAN UNAVAILABLE — Music Jpth could not finish scanning.',
    };
  }

  static String _count(int value) {
    final String digits = value.abs().toString();
    final StringBuffer grouped = StringBuffer(value < 0 ? '-' : '');
    for (int index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
      grouped.write(digits[index]);
    }
    return grouped.toString();
  }
}
