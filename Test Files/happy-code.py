"""
sample_module.py — Test file for text viewer display.

This module doesn't do anything useful. It exists to provide a
representative sample of Python source code with common constructs:
imports, classes, functions, comments, docstrings, and typical formatting.
"""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass, field
from typing import Iterable, Optional


# --- Constants ------------------------------------------------------------

DEFAULT_TIMEOUT = 30
MAX_RETRIES = 3
SUPPORTED_FORMATS = ("json", "yaml", "toml", "ini")


# --- Data classes ---------------------------------------------------------

@dataclass
class Document:
    """Represents a document with a title, body, and optional tags."""

    title: str
    body: str
    tags: list[str] = field(default_factory=list)
    word_count: int = 0

    def __post_init__(self) -> None:
        if not self.word_count:
            self.word_count = len(self.body.split())

    def summary(self, max_words: int = 10) -> str:
        words = self.body.split()[:max_words]
        return " ".join(words) + ("..." if len(words) == max_words else "")


@dataclass
class Collection:
    """A named group of documents."""

    name: str
    documents: list[Document] = field(default_factory=list)

    def add(self, doc: Document) -> None:
        self.documents.append(doc)

    def total_words(self) -> int:
        return sum(d.word_count for d in self.documents)


# --- Functions ------------------------------------------------------------

def load_documents(path: str) -> list[Document]:
    """Load documents from a JSON file on disk.

    Args:
        path: Filesystem path to a JSON file.

    Returns:
        A list of Document instances, or an empty list on failure.
    """
    if not os.path.exists(path):
        print(f"warning: {path} does not exist", file=sys.stderr)
        return []

    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)

    return [
        Document(
            title=item["title"],
            body=item.get("body", ""),
            tags=item.get("tags", []),
        )
        for item in raw
    ]


def filter_by_tag(docs: Iterable[Document], tag: str) -> list[Document]:
    """Return only documents that contain the given tag."""
    return [d for d in docs if tag in d.tags]


def group_by_first_letter(docs: Iterable[Document]) -> dict[str, list[Document]]:
    groups: dict[str, list[Document]] = {}
    for doc in docs:
        key = doc.title[:1].upper() or "?"
        groups.setdefault(key, []).append(doc)
    return groups


def format_report(collection: Collection) -> str:
    """Produce a plain-text summary report for a collection."""
    lines = [
        f"Collection: {collection.name}",
        f"Documents:  {len(collection.documents)}",
        f"Total words: {collection.total_words()}",
        "-" * 40,
    ]
    for i, doc in enumerate(collection.documents, start=1):
        lines.append(f"{i:>3}. {doc.title} ({doc.word_count} words)")
        if doc.tags:
            lines.append(f"     tags: {', '.join(doc.tags)}")
    return "\n".join(lines)


# --- CLI entry point ------------------------------------------------------

def main(argv: Optional[list[str]] = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    if not argv:
        print("usage: sample_module.py <path-to-json>")
        return 1

    path = argv[0]
    docs = load_documents(path)

    if not docs:
        print("no documents loaded")
        return 1

    collection = Collection(name="Loaded Documents")
    for doc in docs:
        collection.add(doc)

    print(format_report(collection))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
