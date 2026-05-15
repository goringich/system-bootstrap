#!/usr/bin/env python3

import argparse
import re
import sys
from collections import Counter
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", help="Directory with converted source notes and attachments")
    parser.add_argument("obsidian_keep_dir", help="Directory with Obsidian Google Keep import")
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_links_section(text: str) -> str:
    marker = "\n### Связи\n"
    if marker in text:
        text = text.split(marker, 1)[0]
    return text.rstrip() + "\n"


def normalize_body(text: str) -> str:
    text = text.replace("../attachments/", "__ATTACH__/")
    text = text.replace("../Вложения/", "__ATTACH__/")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"\n{3,}", "\n\n", text.strip())
    return text + "\n"


def parse_source_note(path: Path) -> tuple[str, str]:
    text = read_text(path)
    lines = text.splitlines()
    title = lines[0][2:].strip() if lines and lines[0].startswith("# ") else path.stem
    body_lines = []
    in_table = False
    for line in lines[1:]:
        if line.startswith("| Field | Value |"):
            in_table = True
            continue
        if in_table:
            if line.startswith("|"):
                continue
            in_table = False
        body_lines.append(line)
    body = "\n".join(body_lines).strip()
    return title, normalize_body(body)


def parse_target_note(path: Path) -> tuple[str, str]:
    text = strip_links_section(read_text(path))
    lines = text.splitlines()
    title = lines[0][2:].strip() if lines and lines[0].startswith("# ") else path.stem
    body = "\n".join(lines[1:]).strip()
    return title, normalize_body(body)


def wiki_targets(text: str) -> list[str]:
    return re.findall(r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]", text)


def resolve_wiki_target(vault_root: Path, target: str) -> bool:
    candidate = vault_root / target
    if candidate.exists():
        return True
    md_candidate = vault_root / f"{target}.md"
    if md_candidate.exists():
        return True
    if candidate.is_dir():
        return True
    return False


def main():
    args = parse_args()
    source_dir = Path(args.source_dir).expanduser().resolve()
    obsidian_keep_dir = Path(args.obsidian_keep_dir).expanduser().resolve()
    vault_root = obsidian_keep_dir.parents[1]

    source_notes = sorted((source_dir / "notes").glob("*.md"))
    target_notes = sorted((obsidian_keep_dir / "Заметки").rglob("*.md"))
    source_attachments = sorted((source_dir / "attachments").glob("*"))
    target_attachments = sorted((obsidian_keep_dir / "Вложения").glob("*"))

    problems = []

    if len(source_notes) != len(target_notes):
        problems.append(f"note count mismatch: source={len(source_notes)} target={len(target_notes)}")
    if len(source_attachments) != len(target_attachments):
        problems.append(
            f"attachment count mismatch: source={len(source_attachments)} target={len(target_attachments)}"
        )

    source_counter = Counter(parse_source_note(path) for path in source_notes)
    target_counter = Counter(parse_target_note(path) for path in target_notes)
    if source_counter != target_counter:
        missing = list((source_counter - target_counter).elements())
        extra = list((target_counter - source_counter).elements())
        problems.append(f"content mismatch: missing={len(missing)} extra={len(extra)}")

    source_attach_names = sorted(path.name for path in source_attachments if path.is_file())
    target_attach_names = sorted(path.name for path in target_attachments if path.is_file())
    if source_attach_names != target_attach_names:
        problems.append("attachment filename mismatch")

    markdown_files = [obsidian_keep_dir / "0. KEEP СВЯЗИ.md"]
    markdown_files.extend(target_notes)
    bridge = vault_root / "Православие" / "Дневник" / "KEEP И ДНЕВНИК.md"
    if bridge.exists():
        markdown_files.append(bridge)

    broken_links = []
    for path in markdown_files:
        text = read_text(path)
        for target in wiki_targets(text):
            if not resolve_wiki_target(vault_root, target):
                broken_links.append(f"{path}: {target}")
    if broken_links:
        problems.append(f"broken wiki links: {len(broken_links)}")

    print(f"source_notes={len(source_notes)}")
    print(f"target_notes={len(target_notes)}")
    print(f"source_attachments={len(source_attachments)}")
    print(f"target_attachments={len(target_attachments)}")
    print(f"broken_links={len(broken_links)}")

    if broken_links:
        for item in broken_links[:20]:
            print(f"BROKEN {item}")

    if problems:
        for item in problems:
            print(f"ERROR {item}")
        sys.exit(1)

    print("VERIFIED all notes, attachments, and wiki links")


if __name__ == "__main__":
    main()
