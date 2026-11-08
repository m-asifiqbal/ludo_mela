// Entry point: portrait only, edge-to-edge, load the save, switch to the saved
// language (before the first frame, so even the splash is translated), start
// the app.
//
// Why the save is read here and not by a provider: everything downstream
// (language, settings, the profile in the HUD) must be correct on the very first
// frame, and a provider that loads asynchronously would flash defaults first.
// main() therefore awaits the file once and hands the result to Riverpod as an
// override (`initialSaveProvider`); from then on the SaveController owns it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/language_service.dart';
import 'core/storage/ids.dart';
import 'core/storage/save_store.dart';
import 'domain/save_data.dart';
import 'state/save_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicences();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = SaveStore(await getApplicationSupportDirectory());
  var save = await store.load();
  if (save == null) {
    // First launch (or both save files were unreadable and have been kept aside
    // by the store): start fresh and write it at once so the profile id and the
    // first-launch time are stable from now on.
    save = SaveData.fresh(now: DateTime.now(), profileId: newId());
    await store.write(save);
  }

  await activateLanguage(AppLanguage.resolve(save.settings.language, deviceLanguageCodes()));

  runApp(
    ProviderScope(
      overrides: [saveStoreProvider.overrideWithValue(store), initialSaveProvider.overrideWithValue(save)],
      child: const LudoMelaApp(),
    ),
  );
}

/// The bundled fonts are SIL OFL: their licence must travel with them, so it
/// shows under Settings › Licences (packages register theirs automatically).
void registerFontLicences() => LicenseRegistry.addLicense(fontLicenceEntries);

/// One licence entry per bundled font, read from assets/licenses/.
@visibleForTesting
Stream<LicenseEntry> fontLicenceEntries() async* {
  for (final (name, file) in fontLicenceFiles) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/licenses/$file'));
  }
}

/// Font name → licence file in assets/licenses/ (Lilita One for display text,
/// Baloo 2 for body text and Hindi, Baloo Da 2 for Bangla).
@visibleForTesting
const List<(String, String)> fontLicenceFiles = [
  ('Lilita One', 'LilitaOne-OFL.txt'),
  ('Baloo 2', 'Baloo2-OFL.txt'),
  ('Baloo Da 2', 'BalooDa2-OFL.txt'),
];
