import 'package:flutter/material.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../features/vault/application/vault_controller.dart';
import '../features/vault/presentation/vault_home_page.dart';

/// 스토리 에셋 볼트의 최상위 위젯입니다.
class StoryAssetVaultApp extends StatefulWidget {
  const StoryAssetVaultApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<StoryAssetVaultApp> createState() => _StoryAssetVaultAppState();
}

class _StoryAssetVaultAppState extends State<StoryAssetVaultApp> {
  late final VaultController controller;

  @override
  void initState() {
    super.initState();
    controller = VaultController(repository: widget.dependencies.repository)..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '스토리 에셋 볼트',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
      useMaterial3: true,
    ),
    home: VaultHomePage(controller: controller),
  );
}
