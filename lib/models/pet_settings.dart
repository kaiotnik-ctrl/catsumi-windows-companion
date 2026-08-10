class PetSettings {
  const PetSettings({
    this.hideDuringFullscreen = true,
    this.reactToApps = true,
    this.clickThrough = false,
    this.paused = false,
    this.petSize = 168,
  });

  final bool hideDuringFullscreen;
  final bool reactToApps;
  final bool clickThrough;
  final bool paused;
  final int petSize;

  PetSettings copyWith({
    bool? hideDuringFullscreen,
    bool? reactToApps,
    bool? clickThrough,
    bool? paused,
    int? petSize,
  }) {
    return PetSettings(
      hideDuringFullscreen: hideDuringFullscreen ?? this.hideDuringFullscreen,
      reactToApps: reactToApps ?? this.reactToApps,
      clickThrough: clickThrough ?? this.clickThrough,
      paused: paused ?? this.paused,
      petSize: petSize ?? this.petSize,
    );
  }

  factory PetSettings.fromJson(Map<String, dynamic> json) {
    return PetSettings(
      hideDuringFullscreen: json['hideDuringFullscreen'] as bool? ?? true,
      reactToApps: json['reactToApps'] as bool? ?? true,
      clickThrough: json['clickThrough'] as bool? ?? false,
      paused: json['paused'] as bool? ?? false,
      petSize: (((json['petSize'] as num?)?.round() ?? 168).clamp(
        96,
        288,
      )).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'hideDuringFullscreen': hideDuringFullscreen,
    'reactToApps': reactToApps,
    'clickThrough': clickThrough,
    'paused': paused,
    'petSize': petSize,
  };
}
