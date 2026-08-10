import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models/pet_animation.dart';
import 'models/pet_settings.dart';
import 'services/settings_service.dart';
import 'services/windows_service.dart';

class PetController extends ChangeNotifier {
  PetController({required this.windows, required this.settingsService});

  final WindowsService windows;
  final SettingsService settingsService;
  final Random _random = Random();

  PetSettings settings = const PetSettings();
  PetAnimation animation = PetAnimations.idle;
  EnvironmentSnapshot? environment;
  int frame = 0;
  bool facingLeft = true;

  Timer? _frameTimer;
  Timer? _environmentTimer;
  Timer? _behaviorTimer;
  StreamSubscription<String>? _traySubscription;
  Duration _frameElapsed = Duration.zero;
  double? _x;
  double? _y;
  bool _visible = true;
  bool? _nativeTaskbarMode;
  DateTime? _summonedUntil;
  DateTime? _manualPositionUntil;

  bool get _isSummoned =>
      _summonedUntil != null && DateTime.now().isBefore(_summonedUntil!);
  bool get _hasManualPosition =>
      _manualPositionUntil != null &&
      DateTime.now().isBefore(_manualPositionUntil!);

  String get statusText {
    if (settings.paused) return 'Paused - use the tray icon to resume';
    final app = environment?.processName;
    if (app != null &&
        app.isNotEmpty &&
        !(environment?.desktopVisible ?? true)) {
      return '${_label(animation)} near $app';
    }
    return _label(animation);
  }

  Future<void> initialize() async {
    windows.initialize();
    settings = await settingsService.load();
    await _safe(() => windows.setClickThrough(settings.clickThrough));
    await _safe(() => windows.setPaused(settings.paused));
    await _safe(() => windows.setPetSize(settings.petSize));
    _traySubscription = windows.trayActions.listen(_handleTrayAction);
    await _pollEnvironment();
    _chooseBehavior(force: true);
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => _tick(const Duration(milliseconds: 40)),
    );
    _environmentTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollEnvironment(),
    );
    _behaviorTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _chooseBehavior(),
    );
  }

  Future<void> _pollEnvironment() async {
    try {
      final previous = environment;
      environment = await windows.environment();
      var current = environment!;

      final shouldHide = settings.hideDuringFullscreen && current.fullscreen;
      if (_visible == shouldHide) {
        _visible = !shouldHide;
        await windows.setVisible(_visible);
      }

      final contextChanged =
          previous == null ||
          previous.desktopVisible != current.desktopVisible ||
          previous.fullscreen != current.fullscreen ||
          previous.processName != current.processName;
      final targetTaskbarMode = !current.desktopVisible && !_isSummoned;
      final modeChanged = _nativeTaskbarMode != targetTaskbarMode;
      if (modeChanged || (contextChanged && targetTaskbarMode)) {
        await windows.setPetMode(taskbar: targetTaskbarMode);
        _nativeTaskbarMode = targetTaskbarMode;
        environment = await windows.environment();
        current = environment!;
      }
      if (contextChanged) _chooseBehavior(force: true);

      _placeForEnvironment(force: contextChanged || _x == null);
      notifyListeners();
    } catch (_) {
      // The Windows runner may be unavailable during widget-only tests.
    }
  }

  void _tick(Duration elapsed) {
    if (settings.paused) return;
    _frameElapsed += elapsed;
    if (_frameElapsed >= animation.frameDuration) {
      _frameElapsed -= animation.frameDuration;
      frame = (frame + 1) % animation.frames;
      notifyListeners();
    }

    final snapshot = environment;
    if (snapshot == null || !snapshot.desktopVisible) return;
    if (_hasManualPosition) return;
    if (animation != PetAnimations.walk && animation != PetAnimations.run) {
      return;
    }

    final speed = animation == PetAnimations.run ? 8.0 : 3.5;
    _x ??= snapshot.workRight - snapshot.windowWidth - 24.0;
    _x = _x! + (facingLeft ? -speed : speed);

    final minX = snapshot.workLeft.toDouble();
    final maxX = (snapshot.workRight - snapshot.windowWidth).toDouble();
    if (_x! <= minX) {
      _x = minX;
      facingLeft = false;
    } else if (_x! >= maxX) {
      _x = maxX;
      facingLeft = true;
    }
    _moveWindow();
  }

  void _chooseBehavior({bool force = false}) {
    final snapshot = environment;
    if (snapshot == null || settings.paused) return;

    PetAnimation next;
    if (snapshot.fullscreen && settings.hideDuringFullscreen) {
      return;
    } else if (!snapshot.desktopVisible) {
      next = settings.reactToApps
          ? _animationForProcess(snapshot.processName.toLowerCase())
          : PetAnimations.taskbarSit;
    } else if (snapshot.idleSeconds >= 600) {
      next = PetAnimations.sleep;
    } else if (snapshot.idleSeconds >= 120) {
      next = _random.nextBool() ? PetAnimations.tiredYawn : PetAnimations.walk;
    } else {
      next =
          PetAnimations.desktopActivities[_random.nextInt(
            PetAnimations.desktopActivities.length,
          )];
    }

    if (force || animation != next) _setAnimation(next);
  }

  PetAnimation _animationForProcess(String process) {
    const development = [
      'code.exe',
      'devenv.exe',
      'idea64.exe',
      'studio64.exe',
      'notepad++.exe',
      'windowsterminal.exe',
      'cmd.exe',
      'powershell.exe',
      'pwsh.exe',
    ];
    const browsers = [
      'chrome.exe',
      'msedge.exe',
      'firefox.exe',
      'brave.exe',
      'opera.exe',
    ];
    const music = ['spotify.exe', 'music.ui.exe', 'vlc.exe', 'wmplayer.exe'];
    const meetings = ['teams.exe', 'ms-teams.exe', 'zoom.exe', 'webex.exe'];

    if (development.any(process.endsWith)) return PetAnimations.type;
    if (music.any(process.endsWith)) return PetAnimations.listenToMusic;
    if (browsers.any(process.endsWith)) return PetAnimations.read;
    if (meetings.any(process.endsWith)) return PetAnimations.taskbarSit;
    return PetAnimations.taskbarSit;
  }

  void _placeForEnvironment({required bool force}) {
    final snapshot = environment;
    if (snapshot == null) return;
    final floorY = (snapshot.workBottom - snapshot.windowHeight).toDouble();

    if (!snapshot.desktopVisible) {
      // Native taskbar mode owns both size and position so the pet remains
      // inside the taskbar rather than covering the active application.
      return;
    }

    if (_hasManualPosition && _x != null && _y != null) return;

    _y = floorY;
    if (force || _x == null) {
      final available = max(
        1,
        snapshot.workRight - snapshot.workLeft - snapshot.windowWidth,
      );
      _x = snapshot.workLeft + _random.nextInt(available).toDouble();
    }
    _moveWindow();
  }

  void _moveWindow() {
    if (_x == null || _y == null) return;
    unawaited(_safe(() => windows.setPosition(_x!, _y!)));
  }

  void _setAnimation(PetAnimation next) {
    animation = next;
    frame = 0;
    _frameElapsed = Duration.zero;
    notifyListeners();
  }

  Future<void> beginDrag() async {
    _manualPositionUntil = DateTime.now().add(const Duration(minutes: 5));
    await _safe(windows.beginDrag);
    try {
      final snapshot = await windows.environment();
      environment = snapshot;
      _x = snapshot.windowLeft.toDouble();
      _y = snapshot.windowTop.toDouble();
      notifyListeners();
    } catch (_) {
      // Keep the previous position if Windows is unavailable during shutdown.
    }
  }

  Future<void> showContextMenu() => _safe(windows.showContextMenu);

  void reactToDoubleClick() {
    _setAnimation(PetAnimations.dance);
  }

  Future<void> _handleTrayAction(String action) async {
    switch (action) {
      case 'pause':
        settings = settings.copyWith(paused: !settings.paused);
        await _safe(() => windows.setPaused(settings.paused));
        if (!settings.paused) _chooseBehavior(force: true);
        break;
      case 'clickThrough':
        settings = settings.copyWith(clickThrough: !settings.clickThrough);
        await _safe(() => windows.setClickThrough(settings.clickThrough));
        break;
      case 'summon':
        _summonedUntil = DateTime.now().add(const Duration(minutes: 5));
        _nativeTaskbarMode = false;
        _visible = true;
        if (settings.clickThrough) {
          settings = settings.copyWith(clickThrough: false);
          await _safe(() => windows.setClickThrough(false));
        }
        await _safe(() => windows.setVisible(true));
        await _safe(() => windows.setPetMode(taskbar: false));
        break;
      case 'sizeDecrease':
        settings = settings.copyWith(petSize: max(96, settings.petSize - 24));
        await _safe(() => windows.setPetSize(settings.petSize));
        break;
      case 'sizeIncrease':
        settings = settings.copyWith(petSize: min(288, settings.petSize + 24));
        await _safe(() => windows.setPetSize(settings.petSize));
        break;
      case 'sizeReset':
        settings = settings.copyWith(petSize: 168);
        await _safe(() => windows.setPetSize(settings.petSize));
        break;
    }
    await settingsService.save(settings);
    notifyListeners();
  }

  String _label(PetAnimation value) {
    const labels = {
      'idle': 'Watching the desktop',
      'walk': 'Taking a little walk',
      'run': 'Zoomies!',
      'sleep': 'Sleeping',
      'eat': 'Snack time',
      'read': 'Reading along',
      'type': 'Helping you type',
      'dance': 'Dancing',
      'trackCursor': 'Watching your cursor',
      'climb': 'Climbing',
      'fall': 'Falling!',
      'taskbarSit': 'Sitting by the taskbar',
      'drinkCoffee': 'Coffee break',
      'listenToMusic': 'Listening to music',
      'confused': 'A little confused',
      'tiredYawn': 'Getting sleepy',
    };
    return labels[value.name] ?? value.name;
  }

  Future<void> _safe(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Keep the pet alive if a transient native call fails.
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _environmentTimer?.cancel();
    _behaviorTimer?.cancel();
    _traySubscription?.cancel();
    super.dispose();
  }
}
