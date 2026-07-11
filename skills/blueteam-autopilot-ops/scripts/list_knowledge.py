#!/usr/bin/env python3
"""List knowledge base articles.

Replaces list-knowledge.sh with Python equivalent.
Usage: python list_knowledge.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListKnowledgeScript(BaseScript):
    """List knowledge script."""

    def execute(self) -> str:
        """List knowledge base articles."""
        if self.mode == "demo":
            return self.load_demo("knowledge_list.json")

        # Real mode: list files in knowledge directory
        knowledge_dir = self.knowledge_dir
        if not knowledge_dir.exists():
            return "[]"

        articles = []
        for f in knowledge_dir.glob("*.md"):
            articles.append({"name": f.stem, "file": f.name})

        import json
        return json.dumps(articles, indent=2)


if __name__ == "__main__":
    print(ListKnowledgeScript().execute())
