import 'package:flutter/widgets.dart';

import 'app/story_asset_vault_app.dart';
import 'core/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppBootstrap.initialize();
  runApp(StoryAssetVaultApp(dependencies: dependencies));
}
