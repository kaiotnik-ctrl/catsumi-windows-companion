# Catsumi animation assets

The four final PNG files are transparent 1536 x 1024 sprite atlases. Each
atlas contains four visual animation rows and six poses per row.

Use nearest-neighbor image scaling so the pixel art remains crisp. The
generated poses are not perfectly confined to a mathematical 256 x 256 grid.
Production crop coordinates are measured per pose in
`lib/models/pet_animation.dart`; using only `frameIndex * 256` can cut off
ears, tails, or props.

The original nominal coordinates were:

```text
x = frameIndex * 256
y = animationRow * 256
width = 256
height = 256
```

`catsumi-animations.json` records the original nominal grid and timing. The
runtime uses the measured coordinates in Dart. The `Source` directory
preserves the original chroma-key images and is not intended to ship with the
application.
