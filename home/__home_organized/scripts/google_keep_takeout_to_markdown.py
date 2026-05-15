#!/usr/bin/env python3

import argparse
import datetime as dt
import html
import json
import re
import shutil
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert Google Keep Takeout notes to Markdown."
    )
    parser.add_argument("input_dir", help="Path to Takeout/Keep directory")
    parser.add_argument("output_dir", help="Directory for generated Markdown files")
    return parser.parse_args()


def sanitize_filename(name: str) -> str:
    cleaned = re.sub(r'[<>:"/\\\\|?*\x00-\x1f]', "_", name).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned or "untitled"


def unique_path(base_dir: Path, filename: str, suffix: str) -> Path:
    candidate = base_dir / f"{filename}{suffix}"
    counter = 2
    while candidate.exists():
        candidate = base_dir / f"{filename} ({counter}){suffix}"
        counter += 1
    return candidate


def format_timestamp(usec):
    if not usec:
        return ""
    try:
        return (
            dt.datetime.fromtimestamp(int(usec) / 1_000_000, tz=dt.timezone.utc)
            .astimezone()
            .isoformat(timespec="seconds")
        )
    except Exception:
        return ""


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = html.unescape(text)
    lines = [line.rstrip() for line in text.split("\n")]
    return "\n".join(lines).strip()


def markdown_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("|", "\\|")


def copy_attachment(src: Path, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    target = unique_path(dest_dir, src.stem, src.suffix)
    shutil.copy2(src, target)
    return target


def build_markdown(note, json_name: str, attachment_links):
    title = note.get("title") or Path(json_name).stem
    created = format_timestamp(note.get("createdTimestampUsec"))
    updated = format_timestamp(note.get("userEditedTimestampUsec"))
    labels = [item.get("name", "").strip() for item in note.get("labels", []) if item.get("name")]
    annotations = note.get("annotations", [])

    lines = [f"# {title}", ""]
    lines.append("| Field | Value |")
    lines.append("| --- | --- |")
    lines.append(f"| Source file | `{markdown_escape(json_name)}` |")
    if created:
        lines.append(f"| Created | {markdown_escape(created)} |")
    if updated:
        lines.append(f"| Updated | {markdown_escape(updated)} |")
    lines.append(f"| Color | {markdown_escape(note.get('color', ''))} |")
    lines.append(f"| Pinned | {'yes' if note.get('isPinned') else 'no'} |")
    lines.append(f"| Archived | {'yes' if note.get('isArchived') else 'no'} |")
    lines.append(f"| Trashed | {'yes' if note.get('isTrashed') else 'no'} |")
    if labels:
        lines.append(f"| Labels | {markdown_escape(', '.join(labels))} |")
    lines.append("")

    body = normalize_text(note.get("textContent", ""))
    if body:
        lines.append(body)
        lines.append("")

    if annotations:
        lines.append("## Links")
        lines.append("")
        for item in annotations:
            item_title = item.get("title") or item.get("url") or item.get("source") or "Link"
            url = item.get("url", "")
            description = normalize_text(item.get("description", ""))
            if url:
                lines.append(f"- [{item_title}]({url})")
            else:
                lines.append(f"- {item_title}")
            if description:
                lines.append(f"  {description}")
        lines.append("")

    if attachment_links:
        lines.append("## Attachments")
        lines.append("")
        for link in attachment_links:
            path = link.as_posix()
            if link.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"}:
                lines.append(f"![{link.name}]({path})")
            else:
                lines.append(f"- [{link.name}]({path})")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main():
    args = parse_args()
    input_dir = Path(args.input_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    attachments_dir = output_dir / "attachments"
    notes_dir = output_dir / "notes"

    if not input_dir.is_dir():
        raise SystemExit(f"Input directory not found: {input_dir}")

    output_dir.mkdir(parents=True, exist_ok=True)
    notes_dir.mkdir(parents=True, exist_ok=True)

    index_rows = []

    for json_path in sorted(input_dir.glob("*.json")):
        with json_path.open("r", encoding="utf-8") as handle:
            note = json.load(handle)

        title = note.get("title") or json_path.stem
        safe_name = sanitize_filename(title)
        note_path = unique_path(notes_dir, safe_name, ".md")

        attachment_links = []
        for attachment in note.get("attachments", []):
            rel_path = attachment.get("filePath")
            if not rel_path:
                continue
            src = input_dir / rel_path
            if not src.exists():
                continue
            copied = copy_attachment(src, attachments_dir)
            attachment_links.append(Path("..") / "attachments" / copied.name)

        markdown = build_markdown(note, json_path.name, attachment_links)
        note_path.write_text(markdown, encoding="utf-8")

        labels = ", ".join(item.get("name", "") for item in note.get("labels", []) if item.get("name"))
        index_rows.append(
            {
                "title": title,
                "file": note_path.name,
                "labels": labels,
                "updated": format_timestamp(note.get("userEditedTimestampUsec")),
            }
        )

    index_lines = [
        "# Google Keep Export",
        "",
        f"Source: `{input_dir}`",
        f"Generated: `{dt.datetime.now().astimezone().isoformat(timespec='seconds')}`",
        "",
        f"Notes: `{len(index_rows)}`",
        "",
        "| Title | Labels | Updated |",
        "| --- | --- | --- |",
    ]

    for item in index_rows:
        index_lines.append(
            f"| [{item['title']}](notes/{item['file']}) | "
            f"{markdown_escape(item['labels'])} | "
            f"{markdown_escape(item['updated'])} |"
        )

    (output_dir / "index.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
