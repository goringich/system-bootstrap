#!/usr/bin/env python3
"""Small retrieval benchmark for the local Obsidian-backed RAG baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path


HOME = Path.home()
DEFAULT_INVENTORY = HOME / "__home_organized/docs/codex-local-context/context-inventory.json"
DEFAULT_QUESTIONS = HOME / "__home_organized/runtime/local-ai/rag-bench/questions.json"
SEARCH_SUFFIXES = {".md", ".txt", ".json", ".yaml", ".yml", ".py", ".sh", ".toml", ".conf"}
MAX_DOC_CHARS = 2000


def expand_path(raw: str) -> Path:
    return Path(raw).expanduser()


def load_inventory(path: Path) -> dict[str, dict[str, list[Path]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    scopes = data.get("scopes")
    if not isinstance(scopes, dict):
        raise ValueError(f"inventory {path} has no valid scopes section")
    resolved: dict[str, dict[str, list[Path]]] = {}
    for scope_name, scope_data in scopes.items():
        if not isinstance(scope_data, dict):
            continue
        roots = [expand_path(item) for item in scope_data.get("roots", []) if str(item).strip()]
        files = [expand_path(item) for item in scope_data.get("files", []) if str(item).strip()]
        resolved[str(scope_name)] = {"roots": roots, "files": files}
    return resolved


def load_questions(path: Path) -> list[dict[str, object]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError(f"questions file {path} must contain a JSON list")
    return [item for item in payload if isinstance(item, dict)]


def tokenize(text: str) -> list[str]:
    raw = re.findall(r"[A-Za-zА-Яа-я0-9_.:/-]+", text.lower())
    return [token for token in raw if len(token) >= 3]


def iter_text_files(scope: dict[str, list[Path]]) -> list[Path]:
    seen: set[Path] = set()
    files: list[Path] = []

    for path in scope.get("files", []):
        if not path.exists() or path in seen:
            continue
        seen.add(path)
        files.append(path)

    for root in scope.get("roots", []):
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in SEARCH_SUFFIXES or path in seen:
                continue
            seen.add(path)
            files.append(path)

    return files


def read_doc_text(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""
    compact = text[:MAX_DOC_CHARS].strip()
    return f"{path.name}\n{compact}" if compact else path.name


def lexical_score(path: Path, text: str, terms: list[str]) -> int:
    if not terms:
        return 0
    lower = text.lower()
    path_lower = str(path).lower()
    score = 0
    for term in terms:
        if term in path_lower:
            score += 8
        score += min(lower.count(term), 10)
    return score


def post_json(url: str, body: dict[str, object], timeout: int = 120) -> dict[str, object]:
    req = urllib.request.Request(
        url,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def embed_text(model: str, text: str) -> list[float]:
    try:
        payload = post_json(
            "http://127.0.0.1:11434/api/embed",
            {"model": model, "input": text, "truncate": True},
        )
        embeddings = payload.get("embeddings")
        if isinstance(embeddings, list) and embeddings and isinstance(embeddings[0], list):
            return [float(item) for item in embeddings[0]]
        embedding = payload.get("embedding")
        if isinstance(embedding, list):
            return [float(item) for item in embedding]
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise

    payload = post_json(
        "http://127.0.0.1:11434/api/embeddings",
        {"model": model, "prompt": text, "truncate": True},
    )
    embedding = payload.get("embedding")
    if not isinstance(embedding, list):
        raise ValueError(f"unexpected embeddings payload for model {model}")
    return [float(item) for item in embedding]


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def matches_expected(path: Path, expected_any: list[str]) -> bool:
    path_lower = str(path).lower()
    return any(needle in path_lower for needle in expected_any)


def bench_question(
    *,
    question: dict[str, object],
    model: str,
    inventory: dict[str, dict[str, list[Path]]],
    corpora: dict[str, list[tuple[Path, str]]],
    embeddings_cache: dict[tuple[str, str], list[float]],
    candidate_limit: int,
    top_k: int,
) -> dict[str, object]:
    scope = str(question.get("scope") or "all")
    query = str(question.get("query") or "").strip()
    qid = str(question.get("id") or query or scope)
    expected_any = [str(item).lower() for item in question.get("expected_any", []) if str(item).strip()]
    exclude_substrings = [str(item).lower() for item in question.get("exclude_substrings", []) if str(item).strip()]
    if scope not in inventory:
        raise ValueError(f"question {qid}: unknown scope {scope}")
    if not query:
        raise ValueError(f"question {qid}: missing query")

    docs = corpora.setdefault(scope, [(path, read_doc_text(path)) for path in iter_text_files(inventory[scope])])
    if exclude_substrings:
        docs = [
            (path, text)
            for path, text in docs
            if not any(needle in str(path).lower() for needle in exclude_substrings)
        ]
    terms = tokenize(query)
    ranked = sorted(
        ((lexical_score(path, text, terms), path, text) for path, text in docs),
        key=lambda item: (-item[0], str(item[1])),
    )
    candidates = [item for item in ranked[:candidate_limit] if item[0] > 0]
    if not candidates:
        candidates = ranked[:candidate_limit]

    query_key = (model, hashlib.sha256(query.encode("utf-8")).hexdigest())
    if query_key not in embeddings_cache:
        embeddings_cache[query_key] = embed_text(model, query)
    query_embedding = embeddings_cache[query_key]

    results: list[dict[str, object]] = []
    for lexical, path, text in candidates:
        doc_key = (model, hashlib.sha256(text.encode("utf-8")).hexdigest())
        if doc_key not in embeddings_cache:
            try:
                embeddings_cache[doc_key] = embed_text(model, text)
            except urllib.error.HTTPError as exc:
                raise ValueError(f"{path} rejected by embeddings API (chars={len(text)}): {exc}") from exc
        similarity = cosine(query_embedding, embeddings_cache[doc_key])
        results.append(
            {
                "path": str(path),
                "lexical": lexical,
                "similarity": similarity,
                "expected": matches_expected(path, expected_any),
            }
        )

    results.sort(key=lambda item: (-float(item["similarity"]), -int(item["lexical"]), str(item["path"])))
    top_results = results[:top_k]
    hit_rank = next((index for index, item in enumerate(results, start=1) if item["expected"]), None)
    top1_path = top_results[0]["path"] if top_results else ""
    return {
        "id": qid,
        "scope": scope,
        "query": query,
        "expected_any": expected_any,
        "exclude_substrings": exclude_substrings,
        "hit_rank": hit_rank,
        "hit_at_1": bool(hit_rank == 1),
        "hit_at_k": bool(hit_rank and hit_rank <= top_k),
        "top1_path": top1_path,
        "top_results": top_results,
    }


def print_report(model: str, results: list[dict[str, object]], top_k: int) -> None:
    hit1 = sum(1 for item in results if item["hit_at_1"])
    hitk = sum(1 for item in results if item["hit_at_k"])
    total = len(results)
    print("# Local RAG bench")
    print(f"- model: `{model}`")
    print(f"- questions: {total}")
    print(f"- hit@1: {hit1}/{total}")
    print(f"- hit@{top_k}: {hitk}/{total}")
    print()
    print("| Question | Scope | Hit@1 | Hit@5 | Rank | Top-1 |")
    print("| --- | --- | --- | --- | ---: | --- |")
    for item in results:
        top1_name = Path(str(item["top1_path"])).name if item["top1_path"] else "n/a"
        rank = item["hit_rank"] if item["hit_rank"] is not None else "-"
        print(
            f"| `{item['id']}` | `{item['scope']}` | "
            f"{'yes' if item['hit_at_1'] else 'no'} | "
            f"{'yes' if item['hit_at_k'] else 'no'} | "
            f"{rank} | `{top1_name}` |"
        )
    print()
    for item in results:
        print(f"## {item['id']}")
        print(f"- query: {item['query']}")
        print("- expected: " + (", ".join(f"`{needle}`" for needle in item["expected_any"]) if item["expected_any"] else "_none_"))
        if item["exclude_substrings"]:
            print("- excluded: " + ", ".join(f"`{needle}`" for needle in item["exclude_substrings"]))
        for index, result in enumerate(item["top_results"], start=1):
            print(f"- {index}. `{result['similarity']:.4f}` (lexical={result['lexical']}) `{result['path']}`")
        print()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Benchmark the local Obsidian-backed RAG baseline")
    parser.add_argument("--model", default="nomic-embed-text:latest")
    parser.add_argument("--inventory", default=str(DEFAULT_INVENTORY))
    parser.add_argument("--questions", default=str(DEFAULT_QUESTIONS))
    parser.add_argument("--candidate-limit", type=int, default=12)
    parser.add_argument("--top-k", type=int, default=5)
    args = parser.parse_args(argv[1:])

    inventory = load_inventory(Path(args.inventory).expanduser())
    questions = load_questions(Path(args.questions).expanduser())
    corpora: dict[str, list[tuple[Path, str]]] = {}
    embeddings_cache: dict[tuple[str, str], list[float]] = {}

    try:
        results = [
            bench_question(
                question=question,
                model=args.model,
                inventory=inventory,
                corpora=corpora,
                embeddings_cache=embeddings_cache,
                candidate_limit=args.candidate_limit,
                top_k=args.top_k,
            )
            for question in questions
        ]
    except (OSError, ValueError, urllib.error.URLError, urllib.error.HTTPError) as exc:
        print(f"rag-bench failed: {exc}", file=sys.stderr)
        return 1

    print_report(args.model, results, args.top_k)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
