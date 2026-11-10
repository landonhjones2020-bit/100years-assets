"""Refresh the project's two bible parts from the live doc.

The game bible's master copy is the live Claude Doc
(https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU). The claude.ai Project holds a markdown
copy in two parts (Sections 1 to 14, 15 to 27), which is what a new session reads and searches.
After editing the live doc:

1. Export the doc's tab as markdown with the Docs `export` tool (container: the doc; file: its
   tab id, from a doc read; format "markdown"). The result is too big for a tool result, so the
   session saves it to a file and prints the path.
2. python3 tools/bible_parts.py <that file> "<what changed, for the header>"
   writes /mnt/user-data/outputs/bible/100-years-below-game-bible-part-1.md and -part-2.md.
3. Read each part in full (the Projects tool only takes a file this session has read), then
   project_write each to claude/100-years-of-fallout-game-bible-part-<n>.md with local_path.
"""
import base64
import json
import os
import re
import sys

URL = "https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU"
OUT = "/mnt/user-data/outputs/bible"


def main(path, what):
    doc = None
    for part in json.load(open(path)):
        try:
            d = json.loads(part.get("text", ""))
        except ValueError:
            continue
        if isinstance(d, dict) and "bytes_b64" in d.get("data", {}):
            doc = d
    if doc is None:
        sys.exit("no exported file in " + path)
    md = base64.b64decode(doc["data"]["bytes_b64"]).decode("utf-8")
    title = md.split("\n", 1)[0].lstrip("# ").strip()
    md = re.sub(r"&#91;embedded content: (.*?)\\\]", lambda m: f"*Diagram ({m.group(1)}): see the [live doc]({URL}).*", md)
    body = md.split("\n", 1)[1].lstrip("\n")
    cut = body.index("## 15. ")
    halves = (body[:cut].rstrip("\n") + "\n", body[cut:].rstrip("\n") + "\n")
    spans = ("Sections 1 to 14", "Sections 15 to 27")
    os.makedirs(OUT, exist_ok=True)
    for i, half in enumerate(halves):
        other = 2 - i
        head = (f"# {title} (Part {i + 1} of 2: {spans[i]})\n\n"
                f"> Synced copy of the live doc [{title}]({URL}), taken at live doc rev {doc.get('rev')} ({what}) and split in "
                f"two for this project. Part {other} ({spans[other - 1]}) is claude/100-years-of-fallout-game-bible-part-{other}.md. "
                f"The live doc is the master: edit there, then refresh both parts. The game was called 100 Years Of Fallout "
                f"until 2026-11-09; the project and these file names keep that name.\n\n")
        out = os.path.join(OUT, f"100-years-below-game-bible-part-{i + 1}.md")
        with open(out, "w") as f:
            f.write(head + half)
        print(out, len(head + half), "characters; sections", ", ".join(re.findall(r"^## (\d+)\.", half, re.M)))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
