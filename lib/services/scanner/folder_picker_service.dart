import 'package:file_picker/file_picker.dart';

/// Opens the platform folder picker. Overridden in tests.
typedef DirectoryPicker = Future<String?> Function({String? dialogTitle});

/// The first step of the scanner flow: let the user choose where their music
/// lives (`CLAUDE.md` §11).
///
/// Wraps `file_picker` so no widget touches the platform channel and so the
/// picker can be faked in tests. Returns `null` when the user cancels.
class FolderPickerService {
  const FolderPickerService({DirectoryPicker? pickerOverride})
    : _picker = pickerOverride;

  final DirectoryPicker? _picker;

  /// The chosen folder, or `null` if the user backed out.
  ///
  /// The dialog runs on the platform side, so awaiting it never blocks the UI
  /// isolate.
  ///
  /// Android returns `null` for a folder whose document URI has no filesystem
  /// path (protected locations such as Downloads), which is indistinguishable
  /// from a cancellation here — both correctly leave the library untouched.
  Future<String?> pickFolder({String? dialogTitle}) =>
      (_picker ?? _pickDirectory)(dialogTitle: dialogTitle);

  static Future<String?> _pickDirectory({String? dialogTitle}) =>
      FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
}
