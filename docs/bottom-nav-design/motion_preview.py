"""Display actual Flutter transition frames; no shipped image assets are edited."""
from pathlib import Path
from PIL import Image, ImageDraw

folder = Path(__file__).parent
frames = []
for index in range(8):
    frame = Image.new("RGB", (800, 128), "#F7F6FC")
    draw = ImageDraw.Draw(frame)
    for column, (role, label) in enumerate([("client", "Cliente"), ("worker", "Trabajador")]):
        draw.text((12 + column * 410, 6), label, fill="#17132D")
        actual = Image.open(folder / "motion" / f"{role}-{index}.png").convert("RGB")
        actual = actual.resize((390, 94), Image.Resampling.LANCZOS)
        frame.paste(actual, (column * 410, 26))
    frames.append(frame)

# Repeat the sampled motion in both directions for a readable preview only.
# The app itself animates once when selection changes and has no idle loop.
sequence = frames + frames[-2:0:-1]
durations = [700] + [40] * 6 + [900] + [40] * 6
sequence[0].save(folder / "selection-animation.gif", save_all=True,
                 append_images=sequence[1:], duration=durations, loop=0,
                 disposal=2)

grid = Image.new("RGB", (1560, 246), "#F7F6FC")
draw = ImageDraw.Draw(grid)
for row, role in enumerate(["client", "worker"]):
    for col, index in enumerate([0, 2, 4, 7]):
        draw.text((col * 390 + 12, row * 123 + 4),
                  f"{role}: {index * 40} ms", fill="#17132D")
        actual = Image.open(folder / "motion" / f"{role}-{index}.png").convert("RGB")
        grid.paste(actual.resize((390, 94), Image.Resampling.LANCZOS),
                   (col * 390, row * 123 + 25))
grid.save(folder / "motion-comparison.png")
