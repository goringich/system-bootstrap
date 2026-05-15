#!/usr/bin/env python3

import argparse
import re
import shutil
from collections import defaultdict
from pathlib import Path


KEEP_HUB_LINK = "Православие/Google Keep/0. KEEP СВЯЗИ"
DIARY_BRIDGE_LINK = "Православие/Дневник/KEEP И ДНЕВНИК"
DIARY_INDEX_LINK = "Православие/Дневник/Дневник"
DIARY_HUB_LINK = "Православие/Дневник/Авто-структура/0. ДНЕВНИК СВЯЗИ"

THEME_RULES = [
    (
        "молитва",
        {
            "keywords": [
                "молит",
                "псалтир",
                "причащ",
                "литург",
                "покаян",
                "исповед",
                "тропар",
                "кондак",
                "молеб",
            ],
            "diary_links": [
                "[[3. ЛЕНЬ ПЕРЕД МОЛИТВОЙ]]",
                "[[4. В ДЕНЬ СВЯТОГО ПРИЧАЩЕНИЯ... УСТАЛОСТЬ]]",
            ],
        },
    ),
    (
        "упование",
        {
            "keywords": ["упован", "надежд", "промысл", "воля бож", "терпени"],
            "diary_links": [
                "[[1. УПОВАНИЕ]]",
                "[[5. ВШЭ]]",
            ],
        },
    ),
    (
        "вечность",
        {
            "keywords": ["бессмерт", "вечност", "душ", "дар", "дух", "благодат"],
            "diary_links": [
                "[[2. БЕССМЕРТИЕ]]",
                "[[ПРЕДИСЛОВИЯ]]",
            ],
        },
    ),
    (
        "борьба",
        {
            "keywords": ["страст", "уныни", "лен", "искушен", "борьб", "горд"],
            "diary_links": [
                "[[3. ЛЕНЬ ПЕРЕД МОЛИТВОЙ]]",
                "[[4. В ДЕНЬ СВЯТОГО ПРИЧАЩЕНИЯ... УСТАЛОСТЬ]]",
            ],
        },
    ),
    (
        "дневник",
        {
            "keywords": ["дневник", "запис", "памят", "обзор"],
            "diary_links": [
                "[[Дневник]]",
                "[[ПРЕДИСЛОВИЯ]]",
            ],
        },
    ),
]

CATEGORY_ORDER = [
    "Святые и отцы",
    "Молитвы и богослужение",
    "Исповедь и вопросы",
    "Жития",
    "Размышления и дневник",
    "Разное",
]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir")
    parser.add_argument("vault_dir")
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def parse_note(path: Path) -> dict:
    text = read_text(path)
    lines = text.splitlines()
    title = path.stem
    if lines and lines[0].startswith("# "):
        title = lines[0][2:].strip()

    labels = []
    updated = ""
    created = ""
    source_file = ""
    in_table = False
    body_lines = []
    for line in lines[1:]:
        if line.startswith("| Field | Value |"):
            in_table = True
            continue
        if in_table:
            if not line.startswith("|"):
                in_table = False
            else:
                parts = [item.strip() for item in line.strip("|").split("|", 1)]
                if len(parts) == 2:
                    key, value = parts
                    if key == "Labels":
                        labels = [part.strip() for part in value.split(",") if part.strip()]
                    elif key == "Updated":
                        updated = value
                    elif key == "Created":
                        created = value
                    elif key == "Source file":
                        source_file = value.strip("`")
                continue
        body_lines.append(line)

    body = "\n".join(body_lines).strip()
    return {
        "path": path,
        "title": title,
        "labels": labels,
        "updated": updated,
        "created": created,
        "source_file": source_file,
        "body": body,
    }


def sanitize_filename(name: str) -> str:
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned or "Без названия"


def unique_target_reserved(base_dir: Path, base_name: str, suffix: str, reserved: set[str]) -> Path:
    candidate = base_dir / f"{base_name}{suffix}"
    counter = 2
    while candidate.name in reserved or candidate.exists():
        candidate = base_dir / f"{base_name} ({counter}){suffix}"
        counter += 1
    reserved.add(candidate.name)
    return candidate


def classify_note(note: dict) -> str:
    title = note["title"].lower()
    labels = " ".join(note["labels"]).lower()
    body = note["body"][:3000].lower()
    haystack = " ".join([title, labels, body])

    if "жития святых" in title or "жития святых" in labels:
        return "Жития"

    saint_markers = [
        "авва",
        "преп",
        "свят",
        "св.",
        "златоуст",
        "игумен",
        "митрополит",
        "архим",
        "архиеп",
        "священномуч",
        "исихаст",
        "оптин",
        "корепанов",
        "брянчанинов",
        "затворник",
        "саровск",
        "сирин",
        "войно-ясенецкий",
        "стеняев",
    ]
    if any(marker in title for marker in saint_markers):
        return "Святые и отцы"

    prayer_markers = [
        "молитва",
        "тропари",
        "кондаки",
        "литург",
        "причащ",
        "молеб",
        "здравие",
        "упокой",
        "прошение",
        "благодарственные",
    ]
    if any(marker in title for marker in prayer_markers) or "молитва" in labels:
        return "Молитвы и богослужение"

    confession_markers = [
        "исповед",
        "вопрос",
        "ответы",
    ]
    if any(marker in title for marker in confession_markers):
        return "Исповедь и вопросы"

    reflection_markers = [
        "размыш",
        "днев",
        "путь",
        "слова",
        "цитаты",
        "факты библии",
        "книги и фильмы",
        "разное",
        "риторика",
        "что не понял",
        "что-то",
        "идиот",
        "вое",
    ]
    if any(marker in title for marker in reflection_markers):
        return "Размышления и дневник"

    if "св.отцы и дух.инф" in labels:
        return "Святые и отцы"

    if any(marker in haystack for marker in ["покаян", "страст", "благодат", "памят", "чтени"]):
        return "Размышления и дневник"

    return "Разное"


def tokenize(text: str) -> set[str]:
    return {
        token
        for token in re.findall(r"[A-Za-zА-Яа-яЁё0-9]+", text.lower())
        if len(token) >= 4
    }


def replace_attachment_links(body: str) -> str:
    return body.replace("../attachments/", "../Вложения/")


def append_links_section(body: str, links: list[str]) -> str:
    body = body.rstrip()
    if body:
        body += "\n\n"
    body += "### Связи\n"
    for link in links:
        body += f"- {link}\n"
    return body.rstrip() + "\n"


def diary_links_for(note: dict) -> tuple[list[str], set[str]]:
    haystack = " ".join([note["title"], " ".join(note["labels"]), note["body"]]).lower()
    links = []
    matched_themes = set()
    for theme, rule in THEME_RULES:
        if any(keyword in haystack for keyword in rule["keywords"]):
            matched_themes.add(theme)
            for link in rule["diary_links"]:
                if link not in links:
                    links.append(link)
    return links, matched_themes


def keep_link(path: Path) -> str:
    rel = path.relative_to(path.parents[4]).as_posix()
    if rel.endswith(".md"):
        rel = rel[:-3]
    return f"[[{rel}|{path.stem}]]"


def build_note_links(note: dict, target_path: Path, related_notes: list[dict], diary_links: list[str]) -> list[str]:
    links = [
        f"[[{KEEP_HUB_LINK}|0. KEEP СВЯЗИ]]",
        f"[[{DIARY_BRIDGE_LINK}|KEEP И ДНЕВНИК]]",
    ]
    for related in related_notes[:4]:
        if related["target_path"] == target_path:
            continue
        links.append(keep_link(related["target_path"]))
    deduped = []
    seen = set()
    for link in links:
        if link not in seen:
            deduped.append(link)
            seen.add(link)
    return deduped


def build_hub(notes: list[dict]) -> str:
    by_category = defaultdict(list)
    for note in notes:
        by_category[note["category"]].append(note)
    section_samples = {
        "Молитвы и богослужение": [
            "Благодарственные",
            "Литургия",
            "Тропари и кондаки",
            "Упокой",
        ],
        "Исповедь и вопросы": [
            "Исповедь",
            "Вопросы",
            "Ответы на вопросы 1",
            "Ответы на вопросы 7 _ исповедь",
        ],
        "Святые и отцы": [
            "Авва Исаак Сирский",
            "Добротолюбие",
            "Лествица",
            "Св. Игнатий Брянчанинов",
        ],
        "Жития": [
            "Жития Святых Январь",
            "Жития Святых август",
            "Жития Святых декабрь",
            "Жития Святых отдельно",
        ],
        "Размышления и дневник": [
            "Путь",
            "Размышления",
            "Цитаты",
            "ЧТО НЕ ПОНЯЛ",
        ],
        "Разное": [
            "Духовные книги",
            "Кого поздравлять в церковные праздники",
            "Ладан",
        ],
    }

    note_by_title = {note["title"]: note for note in notes}
    lines = [
        "# Google Keep",
        "",
        "Православный навигатор по импортированным заметкам из Google Keep.",
        "",
        "### Связи",
        f"- [[{DIARY_BRIDGE_LINK}|KEEP И ДНЕВНИК]]",
        f"- [[{DIARY_INDEX_LINK}|Дневник]]",
        f"- [[{DIARY_HUB_LINK}|0. ДНЕВНИК СВЯЗИ]]",
        "",
        "## Разделы",
        "",
    ]
    section_titles = {
        "Молитвы и богослужение": "Молитвенное правило и богослужение",
        "Исповедь и вопросы": "Исповедь, покаяние, вопросы",
        "Святые и отцы": "Святые отцы и наставники",
        "Жития": "Жития святых",
        "Размышления и дневник": "Размышления и конспекты",
        "Разное": "Временный и неразобранный слой",
    }
    for category in CATEGORY_ORDER:
        group = by_category.get(category, [])
        if not group:
            continue
        lines.append(f"### {section_titles[category]}")
        for sample_title in section_samples.get(category, []):
            note = note_by_title.get(sample_title)
            if note:
                lines.append(f"- {keep_link(note['target_path'])}")
        lines.append("")

    lines.append("## Папки")
    for category in CATEGORY_ORDER:
        group = by_category.get(category, [])
        if group:
            lines.append(f"- [[Православие/Google Keep/Заметки/{category}|{category}]]")
    lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def build_diary_bridge(notes: list[dict], diary_map: dict[str, list[dict]]) -> str:
    lines = [
        "# KEEP И ДНЕВНИК",
        "",
        "Минимальный мост между импортом Google Keep и существующим блоком дневниковых заметок.",
        "",
        "### Связи",
        f"- [[{KEEP_HUB_LINK}|0. KEEP СВЯЗИ]]",
        f"- [[{DIARY_HUB_LINK}|0. ДНЕВНИК СВЯЗИ]]",
        f"- [[{DIARY_INDEX_LINK}|Дневник]]",
        "",
        "## Дневник → Блоки Keep",
        "",
    ]
    diary_pairs = [
        ("[[Православие/Дневник/1. УПОВАНИЕ|1. УПОВАНИЕ]]", "[[Православие/Google Keep/Заметки/Размышления и дневник|Размышления и дневник]]"),
        ("[[Православие/Дневник/2. БЕССМЕРТИЕ|2. БЕССМЕРТИЕ]]", "[[Православие/Google Keep/Заметки/Святые и отцы|Святые и отцы]]"),
        ("[[Православие/Дневник/3. ЛЕНЬ ПЕРЕД МОЛИТВОЙ|3. ЛЕНЬ ПЕРЕД МОЛИТВОЙ]]", "[[Православие/Google Keep/Заметки/Молитвы и богослужение|Молитвы и богослужение]]"),
        ("[[Православие/Дневник/4. В ДЕНЬ СВЯТОГО ПРИЧАЩЕНИЯ... УСТАЛОСТЬ|4. В ДЕНЬ СВЯТОГО ПРИЧАЩЕНИЯ... УСТАЛОСТЬ]]", "[[Православие/Google Keep/Заметки/Молитвы и богослужение|Молитвы и богослужение]]"),
        ("[[Православие/Дневник/5. ВШЭ|5. ВШЭ]]", "[[Православие/Google Keep/Заметки/Размышления и дневник|Размышления и дневник]]"),
        ("[[Православие/Дневник/ПРЕДИСЛОВИЯ|ПРЕДИСЛОВИЯ]]", "[[Православие/Google Keep/0. KEEP СВЯЗИ|0. KEEP СВЯЗИ]]"),
    ]
    for diary_link, keep_target in diary_pairs:
        lines.append(f"- {diary_link} → {keep_target}")

    lines += [
        "",
        "## Keep → Дневник",
        "",
        "- [[Православие/Google Keep/Заметки/Молитвы и богослужение|Молитвы и богослужение]] → [[Православие/Дневник/3. ЛЕНЬ ПЕРЕД МОЛИТВОЙ|3. ЛЕНЬ ПЕРЕД МОЛИТВОЙ]], [[Православие/Дневник/4. В ДЕНЬ СВЯТОГО ПРИЧАЩЕНИЯ... УСТАЛОСТЬ|4. В ДЕНЬ СВЯТОГО ПРИЧАЩЕНИЯ... УСТАЛОСТЬ]]",
        "- [[Православие/Google Keep/Заметки/Святые и отцы|Святые и отцы]] → [[Православие/Дневник/2. БЕССМЕРТИЕ|2. БЕССМЕРТИЕ]], [[Православие/Дневник/ПРЕДИСЛОВИЯ|ПРЕДИСЛОВИЯ]]",
        "- [[Православие/Google Keep/Заметки/Исповедь и вопросы|Исповедь и вопросы]] → [[Православие/Дневник/ПРЕДИСЛОВИЯ|ПРЕДИСЛОВИЯ]]",
        "- [[Православие/Google Keep/Заметки/Размышления и дневник|Размышления и дневник]] → [[Православие/Дневник/1. УПОВАНИЕ|1. УПОВАНИЕ]], [[Православие/Дневник/5. ВШЭ|5. ВШЭ]]",
        "- [[Православие/Google Keep/Заметки/Жития|Жития]] → [[Православие/Дневник/ПРЕДИСЛОВИЯ|ПРЕДИСЛОВИЯ]]",
        "",
    ]
    return "\n".join(lines).rstrip() + "\n"


def update_diary_hub(path: Path) -> None:
    text = read_text(path).rstrip()
    marker = "##### GOOGLE KEEP"
    if marker in text:
        return
    addition = (
        "\n\n##### GOOGLE KEEP\n"
        "- [[Православие/Дневник/KEEP И ДНЕВНИК]] — мост между дневниковым блоком и импортом из Google Keep.\n"
        "- [[Православие/Google Keep/0. KEEP СВЯЗИ]] — полный индекс импортированных заметок.\n"
    )
    write_text(path, text + addition + "\n")


def ensure_diary_index(path: Path) -> None:
    if path.exists() and path.stat().st_size > 0:
        return
    text = (
        "# Дневник\n\n"
        "### Связи\n"
        "- [[Православие/Дневник/ПРЕДИСЛОВИЯ|ПРЕДИСЛОВИЯ]]\n"
        "- [[Православие/Дневник/Авто-структура/0. ДНЕВНИК СВЯЗИ|0. ДНЕВНИК СВЯЗИ]]\n"
        "- [[Православие/Дневник/KEEP И ДНЕВНИК|KEEP И ДНЕВНИК]]\n"
    )
    write_text(path, text)


def main():
    args = parse_args()
    source_dir = Path(args.source_dir).expanduser().resolve()
    vault_dir = Path(args.vault_dir).expanduser().resolve()

    notes_source = source_dir / "notes"
    attachments_source = source_dir / "attachments"

    keep_root = vault_dir / "Православие" / "Google Keep"
    keep_notes_dir = keep_root / "Заметки"
    keep_attach_dir = keep_root / "Вложения"
    bridge_path = vault_dir / "Православие" / "Дневник" / "KEEP И ДНЕВНИК.md"
    diary_index_path = vault_dir / "Православие" / "Дневник" / "Дневник.md"
    diary_hub_path = vault_dir / "Православие" / "Дневник" / "Авто-структура" / "0. ДНЕВНИК СВЯЗИ.md"

    if keep_root.exists():
        shutil.rmtree(keep_root)
    keep_notes_dir.mkdir(parents=True, exist_ok=True)
    keep_attach_dir.mkdir(parents=True, exist_ok=True)

    for attachment in sorted(attachments_source.glob("*")):
        if attachment.is_file():
            shutil.copy2(attachment, keep_attach_dir / attachment.name)

    notes = [parse_note(path) for path in sorted(notes_source.glob("*.md"))]

    reserved_names_by_category = defaultdict(set)

    for note in notes:
        note["category"] = classify_note(note)
        category_dir = keep_notes_dir / note["category"]
        category_dir.mkdir(parents=True, exist_ok=True)
        note["target_path"] = unique_target_reserved(
            category_dir,
            sanitize_filename(note["title"]),
            ".md",
            reserved_names_by_category[note["category"]],
        )
        note["tokens"] = tokenize(note["title"] + " " + " ".join(note["labels"]) + " " + note["body"])
        diary_links, matched_themes = diary_links_for(note)
        note["diary_links"] = diary_links
        note["matched_themes"] = matched_themes

    for note in notes:
        scored_related = []
        for other in notes:
            if other is note:
                continue
            score = 0
            shared_labels = set(note["labels"]) & set(other["labels"])
            if shared_labels:
                score += 10 + len(shared_labels)
            shared_themes = note["matched_themes"] & other["matched_themes"]
            if shared_themes:
                score += 6 + len(shared_themes)
            shared_tokens = note["tokens"] & other["tokens"]
            score += min(len(shared_tokens), 4)
            if other["title"].lower() in note["body"].lower():
                score += 8
            if score > 0:
                scored_related.append((score, other["title"].lower(), other))
        scored_related.sort(key=lambda item: (-item[0], item[1]))
        related_notes = [item[2] for item in scored_related]

        body = replace_attachment_links(note["body"])
        links = build_note_links(note, note["target_path"], related_notes, note["diary_links"])
        content = f"# {note['title']}\n\n{body}\n"
        content = append_links_section(content, links)
        write_text(note["target_path"], content)

    write_text(keep_root / "0. KEEP СВЯЗИ.md", build_hub(notes))

    diary_map = defaultdict(list)
    for theme, _ in THEME_RULES:
        themed = [note for note in notes if theme in note["matched_themes"]]
        themed.sort(key=lambda item: item["title"].lower())
        diary_map[theme] = themed
    write_text(bridge_path, build_diary_bridge(notes, diary_map))

    update_diary_hub(diary_hub_path)
    ensure_diary_index(diary_index_path)

    print(f"Imported {len(notes)} notes into {keep_root}")


if __name__ == "__main__":
    main()
