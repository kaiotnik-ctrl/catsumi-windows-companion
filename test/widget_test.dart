import 'package:catsumi/main.dart';
import 'package:catsumi/models/pet_animation.dart';
import 'package:catsumi/models/pet_settings.dart';
import 'package:catsumi/pet_controller.dart';
import 'package:catsumi/services/settings_service.dart';
import 'package:catsumi/services/windows_service.dart';
import 'package:catsumi/widgets/pet_sprite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings preserve defaults and round-trip values', () {
    final settings = PetSettings.fromJson(const {'clickThrough': true});
    expect(settings.clickThrough, isTrue);
    expect(settings.hideDuringFullscreen, isTrue);
    expect(settings.petSize, 168);
    expect(PetSettings.fromJson(settings.toJson()).toJson(), settings.toJson());
  });

  test('pet size is clamped to supported bounds', () {
    expect(PetSettings.fromJson(const {'petSize': 1}).petSize, 96);
    expect(PetSettings.fromJson(const {'petSize': 999}).petSize, 288);
  });

  test('native environment payload is parsed defensively', () {
    final snapshot = EnvironmentSnapshot.fromMap(const {
      'processName': 'code.exe',
      'desktopVisible': false,
      'idleSeconds': 42,
      'workRight': 1920,
      'workBottom': 1040,
    });
    expect(snapshot.processName, 'code.exe');
    expect(snapshot.idleSeconds, 42);
    expect(snapshot.windowWidth, 256);
  });

  testWidgets('pet surface renders the current animation', (tester) async {
    final controller = PetController(
      windows: WindowsService(),
      settingsService: SettingsService(),
    );
    await tester.pumpWidget(CatsumiApp(controller: controller));
    expect(find.byType(PetSprite), findsOneWidget);
    expect(controller.animation, PetAnimations.idle);
  });
}
