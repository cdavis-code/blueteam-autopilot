"""Vector embeddings for cross-incident similarity search.

Uses DashScope text-embedding-v3 for generating embeddings.
Falls back to deterministic hash-based pseudo-embeddings in demo mode
or when the API key is unavailable.

Provides storage and cosine similarity search against the
incident_embeddings table in the Turso/libSQL database.
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import urllib.request
import urllib.error
from datetime import datetime, timezone
from typing import Any

from connectonion_qwen.config import (
    DASHSCOPE_API_KEY,
    QWEN_BASE_URL,
    SECURITY_CENTER_MODE,
)
from connectonion_qwen.memory import _connect, init_db

logger = logging.getLogger(__name__)

_REAL_DIMS = 1024  # DashScope text-embedding-v3
_DEMO_DIMS = 64    # Hash-based fallback
_API_TIMEOUT = 30


def generate_embedding(text: str) -> list[float]:
    """Generate an embedding vector for the given text.

    In real mode with a valid API key, calls DashScope text-embedding-v3.
    In demo mode or without an API key, returns a deterministic 64-dim
    pseudo-embedding based on SHA-256 hash of the text.

    Args:
        text: The text to embed.

    Returns:
        A list of floats representing the embedding vector.
    """
    if SECURITY_CENTER_MODE == "demo" or not DASHSCOPE_API_KEY:
        return _demo_embedding(text)

    try:
        return _dashscope_embedding(text)
    except Exception as e:
        logger.warning(f"DashScope embedding failed, using demo fallback: {e}")
        return _demo_embedding(text)


def _dashscope_embedding(text: str) -> list[float]:
    """Call DashScope text-embedding-v3 API."""
    url = f"{QWEN_BASE_URL}/embeddings"
    payload = json.dumps({
        "input": text,
        "model": "text-embedding-v3",
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
        },
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=_API_TIMEOUT) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    return data["data"][0]["embedding"]


def _demo_embedding(text: str) -> list[float]:
    """Generate a deterministic pseudo-embedding from text hash.

    Uses SHA-256 to produce consistent 64-dim vectors.
    Same text always produces the same embedding, enabling
    meaningful similarity comparisons in demo mode.
    """
    hash_bytes = b""
    seed = text.encode("utf-8")
    while len(hash_bytes) < _DEMO_DIMS * 4:
        seed = hashlib.sha256(seed).digest()
        hash_bytes += seed

    floats = []
    for i in range(_DEMO_DIMS):
        chunk = hash_bytes[i * 4 : (i + 1) * 4]
        val = int.from_bytes(chunk, "big")
        floats.append((val / (2**32 - 1)) * 2 - 1)

    norm = math.sqrt(sum(x * x for x in floats))
    if norm > 0:
        floats = [x / norm for x in floats]

    return floats


def store_incident_embedding(
    description: str,
    source_workflow: str = "",
    source_type: str = "incident",
    source_id: str = "",
    metadata: dict | None = None,
) -> int:
    """Store an incident description with its embedding in the database.

    Args:
        description: The text description to embed and store.
        source_workflow: Which workflow generated this incident.
        source_type: Type of source (incident, alert, finding, vulnerability).
        source_id: Identifier from the source system.
        metadata: Additional context (JSON-serializable dict).

    Returns:
        The ID of the inserted row.
    """
    init_db()
    embedding = generate_embedding(description)
    now = datetime.now(timezone.utc).isoformat()

    conn = _connect()
    try:
        cursor = conn.execute(
            """INSERT INTO incident_embeddings
               (source_workflow, source_type, source_id, description,
                embedding, created_at, metadata)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                source_workflow,
                source_type,
                source_id,
                description,
                json.dumps(embedding),
                now,
                json.dumps(metadata) if metadata else None,
            ),
        )
        conn.commit()
        row_id = cursor.lastrowid
        logger.info(
            f"Stored incident embedding {row_id} "
            f"(type={source_type}, workflow={source_workflow})"
        )
        return row_id
    finally:
        conn.close()


def find_similar(description: str, top_k: int = 5) -> list[dict[str, Any]]:
    """Find the most similar stored incidents to the given description.

    Computes cosine similarity between the input text's embedding and
    all stored embeddings. Returns the top-k matches.

    Args:
        description: The text to search for.
        top_k: Number of results to return.

    Returns:
        List of dicts with keys: id, source_workflow, source_type,
        source_id, description, similarity, created_at, metadata.
    """
    init_db()
    query_embedding = generate_embedding(description)

    conn = _connect()
    try:
        rows = conn.execute(
            """SELECT id, source_workflow, source_type, source_id,
                      description, embedding, created_at, metadata
               FROM incident_embeddings"""
        ).fetchall()

        if not rows:
            return []

        results = []
        for row in rows:
            stored_embedding = json.loads(row["embedding"])
            similarity = _cosine_similarity(query_embedding, stored_embedding)
            results.append({
                "id": row["id"],
                "source_workflow": row["source_workflow"],
                "source_type": row["source_type"],
                "source_id": row["source_id"],
                "description": row["description"],
                "similarity": round(similarity, 4),
                "created_at": row["created_at"],
                "metadata": json.loads(row["metadata"]) if row["metadata"] else None,
            })

        results.sort(key=lambda x: x["similarity"], reverse=True)
        return results[:top_k]
    finally:
        conn.close()


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    if len(a) != len(b):
        # Different dimensions — return 0 (incomparable)
        return 0.0

    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))

    if norm_a == 0 or norm_b == 0:
        return 0.0

    return dot / (norm_a * norm_b)
