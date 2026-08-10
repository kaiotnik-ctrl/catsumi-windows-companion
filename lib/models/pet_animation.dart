class PetAnimation {
  const PetAnimation({
    required this.name,
    required this.sheet,
    required this.sourceTop,
    required this.sourceLefts,
    required this.frameDuration,
    this.sourceHeight = 256,
  });

  final String name;
  final String sheet;
  final double sourceTop;
  final List<double> sourceLefts;
  final Duration frameDuration;
  final double sourceHeight;

  int get frames => sourceLefts.length;
}

class PetAnimations {
  static const idle = PetAnimation(
    name: 'idle',
    sheet: 'catsumi-core.png',
    sourceTop: 0,
    sourceLefts: [30, 257, 499, 731, 966, 1196],
    frameDuration: Duration(milliseconds: 180),
  );
  static const walk = PetAnimation(
    name: 'walk',
    sheet: 'catsumi-core.png',
    sourceTop: 256,
    sourceLefts: [50, 288, 528, 760, 1001, 1236],
    frameDuration: Duration(milliseconds: 110),
  );
  static const run = PetAnimation(
    name: 'run',
    sheet: 'catsumi-core.png',
    sourceTop: 512,
    sourceLefts: [47, 306, 558, 786, 1017, 1257],
    frameDuration: Duration(milliseconds: 80),
  );
  static const sleep = PetAnimation(
    name: 'sleep',
    sheet: 'catsumi-core.png',
    sourceTop: 768,
    sourceLefts: [18, 262, 512, 753, 992, 1233],
    frameDuration: Duration(milliseconds: 300),
  );
  static const eat = PetAnimation(
    name: 'eat',
    sheet: 'catsumi-activities.png',
    sourceTop: 0,
    sourceLefts: [51, 302, 538, 782, 1026, 1259],
    frameDuration: Duration(milliseconds: 180),
  );
  static const read = PetAnimation(
    name: 'read',
    sheet: 'catsumi-activities.png',
    sourceTop: 256,
    sourceLefts: [34, 281, 519, 758, 1010, 1243],
    frameDuration: Duration(milliseconds: 240),
  );
  static const type = PetAnimation(
    name: 'type',
    sheet: 'catsumi-activities.png',
    sourceTop: 484,
    sourceLefts: [22, 275, 516, 766, 995, 1241],
    frameDuration: Duration(milliseconds: 120),
  );
  static const dance = PetAnimation(
    name: 'dance',
    sheet: 'catsumi-activities.png',
    sourceTop: 714,
    sourceLefts: [28, 268, 526, 776, 1006, 1252],
    frameDuration: Duration(milliseconds: 140),
  );
  static const trackCursor = PetAnimation(
    name: 'trackCursor',
    sheet: 'catsumi-environment.png',
    sourceTop: 0,
    sourceHeight: 240,
    sourceLefts: [47, 285, 524, 757, 1014, 1248],
    frameDuration: Duration(milliseconds: 160),
  );
  static const climb = PetAnimation(
    name: 'climb',
    sheet: 'catsumi-environment.png',
    sourceTop: 230,
    sourceLefts: [42, 287, 511, 750, 985, 1235],
    frameDuration: Duration(milliseconds: 130),
  );
  static const fall = PetAnimation(
    name: 'fall',
    sheet: 'catsumi-environment.png',
    sourceTop: 486,
    sourceHeight: 240,
    sourceLefts: [24, 263, 502, 742, 991, 1224],
    frameDuration: Duration(milliseconds: 90),
  );
  static const taskbarSit = PetAnimation(
    name: 'taskbarSit',
    sheet: 'catsumi-environment.png',
    sourceTop: 714,
    sourceLefts: [25, 267, 511, 756, 999, 1239],
    frameDuration: Duration(milliseconds: 220),
  );
  static const drinkCoffee = PetAnimation(
    name: 'drinkCoffee',
    sheet: 'catsumi-moods.png',
    sourceTop: 0,
    sourceLefts: [32, 279, 525, 763, 1008, 1247],
    frameDuration: Duration(milliseconds: 220),
  );
  static const listenToMusic = PetAnimation(
    name: 'listenToMusic',
    sheet: 'catsumi-moods.png',
    sourceTop: 256,
    sourceLefts: [23, 266, 513, 752, 1001, 1233],
    frameDuration: Duration(milliseconds: 150),
  );
  static const confused = PetAnimation(
    name: 'confused',
    sheet: 'catsumi-moods.png',
    sourceTop: 486,
    sourceLefts: [30, 268, 506, 750, 1002, 1235],
    frameDuration: Duration(milliseconds: 200),
  );
  static const tiredYawn = PetAnimation(
    name: 'tiredYawn',
    sheet: 'catsumi-moods.png',
    sourceTop: 714,
    sourceLefts: [25, 275, 525, 776, 1016, 1239],
    frameDuration: Duration(milliseconds: 240),
  );

  static const desktopActivities = <PetAnimation>[
    idle,
    walk,
    walk,
    run,
    eat,
    dance,
    trackCursor,
    drinkCoffee,
  ];
}
