import 'package:kazumi/bean/dialog/exit_confirmation_dialog.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:window_manager/window_manager.dart';

/// Shell-level exit helpers. The confirmation UI is rendered by the shell
/// itself (above the movie texture), not by the anime Navigator, so it works
/// while the movie module is active.
ExitDialogAction? rememberedExitAction() {
  return switch (GStorage.getSetting(SettingsKeys.exitBehavior)) {
    0 => ExitDialogAction.exit,
    1 => ExitDialogAction.minimizeToTray,
    _ => null,
  };
}

Future<void> persistExitChoice(ExitDialogResult result) async {
  if (!result.rememberChoice) return;
  await GStorage.putSetting(
    SettingsKeys.exitBehavior,
    switch (result.action) {
      ExitDialogAction.exit => 0,
      ExitDialogAction.minimizeToTray => 1,
    },
  );
}

Future<void> applyExitAction(
  ExitDialogAction action, {
  required Future<void> Function() onExit,
}) async {
  switch (action) {
    case ExitDialogAction.exit:
      await onExit();
    case ExitDialogAction.minimizeToTray:
      await windowManager.hide();
  }
}
