#!/usr/bin/env python3
"""Convert a directory into a single Markdown file.

Produces a directory tree followed by the contents of every file, each in a
fenced code block with a language hint inferred from the extension.

Usage:
    python convert_into_md.py <directory> [-o output.md]
    python3 convert_into_md.py k8s-10-ingress              # writes k8s-10-ingress.md
    python3 convert_into_md.py k8s-10-ingress -o output.md # custom output name

Example:
    python convert_into_md.py k8s-10-ingress -o k8s-10-ingress.md
"""

import argparse
import sys
from pathlib import Path

# Map file extensions / names to Markdown code-fence language hints.
LANG_BY_EXT = {
    ".py": "python",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".json": "json",
    ".sh": "bash",
    ".md": "markdown",
    ".txt": "text",
    ".html": "html",
    ".css": "css",
    ".js": "javascript",
    ".ts": "typescript",
    ".toml": "toml",
    ".ini": "ini",
    ".env": "bash",
}
LANG_BY_NAME = {
    "Dockerfile": "dockerfile",
    "Makefile": "makefile",
}

# Files / directories to skip while walking.
IGNORE = {".git", "__pycache__", ".DS_Store", ".venv", "node_modules"}


def lang_for(path: Path) -> str:
    if path.name in LANG_BY_NAME:
        return LANG_BY_NAME[path.name]
    return LANG_BY_EXT.get(path.suffix.lower(), "")


def iter_paths(root: Path):
    """Yield every non-ignored path under root, directories first, sorted."""
    entries = sorted(
        (p for p in root.iterdir() if p.name not in IGNORE),
        key=lambda p: (p.is_file(), p.name.lower()),
    )
    for entry in entries:
        yield entry
        if entry.is_dir():
            yield from iter_paths(entry)


def build_tree(root: Path) -> str:
    """Return an ASCII tree of the directory, like the `tree` command."""
    lines = [f"{root.name}/"]

    def walk(directory: Path, prefix: str):
        children = sorted(
            (p for p in directory.iterdir() if p.name not in IGNORE),
            key=lambda p: (p.is_file(), p.name.lower()),
        )
        for i, child in enumerate(children):
            last = i == len(children) - 1
            connector = "└── " if last else "├── "
            suffix = "/" if child.is_dir() else ""
            lines.append(f"{prefix}{connector}{child.name}{suffix}")
            if child.is_dir():
                extension = "    " if last else "│   "
                walk(child, prefix + extension)

    walk(root, "")
    return "\n".join(lines)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return "<binary or unreadable file — skipped>"


def convert(root: Path) -> str:
    out = [f"# {root.name}", "", "## Directory structure", "", "```text",
           build_tree(root), "```", ""]

    out.append("## Files")
    out.append("")
    for path in iter_paths(root):
        if path.is_dir():
            continue
        rel = path.relative_to(root.parent)
        out.append(f"### `{rel.as_posix()}`")
        out.append("")
        lang = lang_for(path)
        out.append(f"```{lang}")
        out.append(read_text(path).rstrip("\n"))
        out.append("```")
        out.append("")

    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("directory", help="directory to convert")
    parser.add_argument("-o", "--output", help="output .md file (default: <dir>.md)")
    args = parser.parse_args()

    root = Path(args.directory).resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 1

    output = Path(args.output) if args.output else Path(f"{root.name}.md")
    output.write_text(convert(root), encoding="utf-8")
    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
