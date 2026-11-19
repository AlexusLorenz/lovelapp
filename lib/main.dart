import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lizenz der mitgelieferten Schrift auf der Lizenzseite anzeigen.
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL-Staatliches.txt');
    yield LicenseEntryWithLineBreaks(['Staatliches'], ofl);
  });

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  const app = ProviderScope(child: LovelApp());
  if (Env.sentryDsn.isEmpty) {
    runApp(app);
    return;
  }
  // Absturzberichte – datensparsam: keine IP, keine Nutzerdaten, keine
  // Screenshots, keine Netzwerk-Inhalte.
  await SentryFlutter.init((options) {
    options
      ..dsn = Env.sentryDsn
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..tracesSampleRate = 0
      ..environment = kReleaseMode ? 'production' : 'debug'
      ..beforeBreadcrumb = (crumb, hint) =>
          // Keine URLs/Requests mitschicken (könnten IDs enthalten).
          crumb?.category == 'http' || crumb?.category == 'navigation'
          ? null
          : crumb;
  }, appRunner: () => runApp(SentryWidget(child: app)));
}
