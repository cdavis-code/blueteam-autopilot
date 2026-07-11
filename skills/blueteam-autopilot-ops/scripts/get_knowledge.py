#!/usr/bin/env python3
"""Get knowledge base article content.

Replaces get-knowledge.sh with Python equivalent.
Usage: python get_knowledge.py <topic>
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class GetKnowledgeScript(BaseScript):
    """Get knowledge script."""

    def execute(self, topic: str) -> str:
        """Get knowledge base article content.

        Args:
            topic: The topic name (e.g., 'nist-csf', 'soc2-cc6')
        """
        if self.mode == "demo":
            # Return a sample knowledge article
            return f"# {topic}\n\nKnowledge base article for {topic}.\n\nThis is demo content."

        # Real mode: read from knowledge directory
        knowledge_dir = self.knowledge_dir
        article_path = knowledge_dir / f"{topic}.md"

        if not article_path.exists():
            return f"Knowledge article not found: {topic}"

        with open(article_path) as f:
            return f.read()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get_knowledge.py <topic>")
        sys.exit(1)
    print(GetKnowledgeScript().execute(sys.argv[1]))
