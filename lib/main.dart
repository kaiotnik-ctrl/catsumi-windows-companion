import 'package:flutter/material.dart';

import 'pet_controller.dart';
import 'services/settings_service.dart';
import 'services/windows_service.dart';
import 'widgets/pet_sprite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = PetController(
    windows: WindowsService(),
    settingsService: SettingsService(),
  );
  await controller.initialize();
  runApp(CatsumiApp(controller: controller));
}

class CatsumiApp extends StatelessWidget {
  const CatsumiApp({super.key, required this.controller});

  final PetController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: const Color(0xFF010203),
      home: PetSurface(controller: controller),
    );
  }
}

class PetSurface extends StatelessWidget {
  const PetSurface({super.key, required this.controller});

  final PetController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF010203),
          body: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => controller.beginDrag(),
              onDoubleTap: controller.reactToDoubleClick,
              onSecondaryTap: controller.showContextMenu,
              child: Transform.flip(
                flipX: !controller.facingLeft,
                child: PetSprite(
                  animation: controller.animation,
                  frame: controller.frame,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
