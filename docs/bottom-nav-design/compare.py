"""Compose source and actual Flutter captures for QA; leave shipped assets intact."""
from pathlib import Path
from PIL import Image, ImageDraw

folder = Path(__file__).parent
reference = Image.open(folder / "reference.png").convert("RGB")
canvas = Image.new("RGB", (780, 390), "#F7F6FC")
draw = ImageDraw.Draw(canvas)
for row, (role, box) in enumerate([
    ("client", (117, 73, 570, 165)),
    ("worker", (649, 73, 1102, 165)),
]):
    y = row * 130
    draw.text((12, y + 4), f"{role} - reference", fill="#17132D")
    draw.text((402, y + 4), f"{role} - Flutter", fill="#17132D")
    source = reference.crop(box).resize((366, 84), Image.Resampling.LANCZOS)
    actual = Image.open(folder / f"{role}.png").convert("RGB").resize((390, 94), Image.Resampling.LANCZOS)
    canvas.paste(source, (12, y + 25))
    canvas.paste(actual, (390, y + 25))

draw.text((12, 264), "Other selected tabs and unread badges", fill="#17132D")
for index, name in enumerate(["client-notifications", "worker-wallet"]):
    actual = Image.open(folder / f"{name}.png").convert("RGB").resize((390, 94), Image.Resampling.LANCZOS)
    canvas.paste(actual, (390 * index, 285))
canvas.save(folder / "comparison.png")

preview = Image.new("RGB", (800, 128), "#F7F6FC")
preview_draw = ImageDraw.Draw(preview)
for index, (role, label) in enumerate([("client", "Cliente"), ("worker", "Trabajador")]):
    preview_draw.text((12 + index * 410, 6), label, fill="#17132D")
    actual = Image.open(folder / f"{role}.png").convert("RGB").resize((390, 94), Image.Resampling.LANCZOS)
    preview.paste(actual, (index * 410, 26))
preview.save(folder / "client-worker.png")
