import 'dart:async';

import 'package:flutter/services.dart';

class EnvironmentSnapshot {
  const EnvironmentSnapshot({
    required this.processName,
    required this.windowTitle,
    required this.desktopVisible,
    required this.fullscreen,
    required this.idleSeconds,
    required this.workLeft,
    required this.workTop,
    required this.workRight,
    required this.workBottom,
    required this.windowWidth,
    required this.windowHeight,
    required this.windowLeft,
    required this.windowTop,
    required this.cursorX,
    required this.cursorY,
  });

  final String processName;
  final String windowTitle;
  final bool desktopVisible;
  final bool fullscreen;
  final int idleSeconds;
  final int workLeft;
  final int workTop;
  final int workRight;
  final int workBottom;
  final int windowWidth;
  final int windowHeight;
  final int windowLeft;
  final int windowTop;
  final int cursorX;
  final int cursorY;

  factory EnvironmentSnapshot.fromMap(Map<Object?, Object?> map) {
    int number(String key, [int fallback = 0]) =>
        (map[key] as num?)?.round() ?? fallback;
    return EnvironmentSnapshot(
      processName: map['processName'] as String? ?? '',
      windowTitle: map['windowTitle'] as String? ?? '',
      desktopVisible: map['desktopVisible'] as bool? ?? false,
      fullscreen: map['fullscreen'] as bool? ?? false,
      idleSeconds: number('idleSeconds'),
      workLeft: number('workLeft'),
      workTop: number('workTop'),
      workRight: number('workRight', 1920),
      workBottom: number('workBottom', 1080),
      windowWidth: number('windowWidth', 256),
      windowHeight: number('windowHeight', 256),
      windowLeft: number('windowLeft'),
      windowTop: number('windowTop'),
      cursorX: number('cursorX'),
      cursorY: number('cursorY'),
    );
  }
}

class WindowsService {
  static const _channel = MethodChannel('catsumi/windows');
  final _trayActions = StreamController<String>.broadcast();

  Stream<String> get trayActions => _trayActions.stream;

  void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trayAction' && call.arguments is String) {
        _trayActions.add(call.arguments as String);
      }
    });
  }

  Future<EnvironmentSnapshot> environment() async {
    final value = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getEnvironment',
    );
    return EnvironmentSnapshot.fromMap(value ?? const {});
  }

  Future<void> setPosition(double x, double y) =>
      _channel.invokeMethod('setPosition', {'x': x.round(), 'y': y.round()});

  Future<void> setVisible(bool visible) =>
      _channel.invokeMethod('setVisible', {'visible': visible});

  Future<void> setClickThrough(bool enabled) =>
      _channel.invokeMethod('setClickThrough', {'enabled': enabled});

  Future<void> setPaused(bool paused) =>
      _channel.invokeMethod('setPaused', {'paused': paused});

  Future<void> setPetMode({required bool taskbar}) =>
      _channel.invokeMethod('setPetMode', {'taskbar': taskbar});

  Future<void> setPetSize(int size) =>
      _channel.invokeMethod('setPetSize', {'size': size});

  Future<void> beginDrag() => _channel.invokeMethod('beginDrag');
  Future<void> showContextMenu() => _channel.invokeMethod('showContextMenu');
}
