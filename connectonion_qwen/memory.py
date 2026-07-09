"""Turso/libSQL memory layer — persistent scan storage for IAM forensics.

Provides embedded libSQL database for storing IAM scan snapshots,
findings with risk scores, and remediation history. Zero-config in
demo mode (embedded file), optional cloud sync via TURSO_DATABASE_URL.
"""

from __future__ import annotations

import json
import logging
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from connectonion_qwen.config import DATA_DIR, TURSO_DATABASE_URL

logger = logging.getLogger(__name__)

_DB_PATH: Path | None = None


def _get_db_path() -> Path:
    """Resolve the database file path."""
    global _DB_PATH
    if _DB_PATH is not None:
        return _DB_PATH

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    _DB_PATH = DATA_DIR / "blueteam.db"
    return _DB_PATH


def _connect() -> sqlite3.Connection:
    """Open a connection to the embedded libSQL database."""
    db_path = _get_db_path()

    if TURSO_DATABASE_URL:
        # Cloud sync mode — use libSQL remote
        try:
            import libsql
            conn = libsql.connect(str(db_path), sync_url=TURSO_DATABASE_URL)
        except ImportError:
            logger.warning(
                "libsql package not installed — falling back to sqlite3. "
                "Install with: pip install libsql"
            )
            conn = sqlite3.connect(str(db_path))
    else:
        conn = sqlite3.connect(str(db_path))

    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Create the database and tables if they don't exist."""
    conn = _connect()
    try:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS iam_scan_snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_timestamp TEXT NOT NULL,
                workflow_run_id TEXT,
                entity_count INTEGER DEFAULT 0,
                risk_summary TEXT,
                raw_inventory TEXT
            );

            CREATE TABLE IF NOT EXISTS iam_findings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                snapshot_id INTEGER NOT NULL,
                entity_type TEXT NOT NULL,
                entity_name TEXT NOT NULL,
                risk_score REAL DEFAULT 0.0,
                risk_category TEXT,
                description TEXT,
                recommendation TEXT,
                status TEXT DEFAULT 'open',
                remediated_at TEXT,
                embedding TEXT,
                FOREIGN KEY (snapshot_id) REFERENCES iam_scan_snapshots(id)
            );

            CREATE TABLE IF NOT EXISTS remediation_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                finding_id INTEGER NOT NULL,
                action_taken TEXT NOT NULL,
                approved_by TEXT,
                timestamp TEXT NOT NULL,
                pre_state TEXT,
                post_state TEXT,
                FOREIGN KEY (finding_id) REFERENCES iam_findings(id)
            );

            CREATE INDEX IF NOT EXISTS idx_findings_snapshot
                ON iam_findings(snapshot_id);
            CREATE INDEX IF NOT EXISTS idx_findings_entity
                ON iam_findings(entity_name);
            CREATE INDEX IF NOT EXISTS idx_snapshots_timestamp
                ON iam_scan_snapshots(scan_timestamp);

            CREATE TABLE IF NOT EXISTS incident_embeddings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_workflow TEXT,
                source_type TEXT NOT NULL,
                source_id TEXT,
                description TEXT NOT NULL,
                embedding TEXT NOT NULL,
                created_at TEXT NOT NULL,
                metadata TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_incident_type
                ON incident_embeddings(source_type);

            CREATE TABLE IF NOT EXISTS monitor_state (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                last_check_timestamp TEXT,
                total_ticks INTEGER DEFAULT 0,
                total_escalations INTEGER DEFAULT 0,
                last_tick_timestamp TEXT
            );
            INSERT OR IGNORE INTO monitor_state
                (id, last_check_timestamp, total_ticks, total_escalations)
                VALUES (1, NULL, 0, 0);
        """)
        conn.commit()
        logger.info(f"Database initialized at {_get_db_path()}")
    finally:
        conn.close()


def store_snapshot(
    workflow_run_id: str,
    inventory: dict[str, Any],
    findings: list[dict[str, Any]],
) -> int:
    """Store an IAM scan snapshot and its findings.

    Args:
        workflow_run_id: Identifier for the workflow run.
        inventory: Raw IAM inventory data (users, roles, policies).
        findings: List of finding dicts with keys:
            entity_type, entity_name, risk_score, risk_category,
            description, recommendation.

    Returns:
        The snapshot_id of the newly inserted snapshot.
    """
    init_db()
    conn = _connect()
    try:
        now = datetime.now(timezone.utc).isoformat()

        risk_counts: dict[str, int] = {}
        for f in findings:
            cat = f.get("risk_category", "unknown")
            risk_counts[cat] = risk_counts.get(cat, 0) + 1

        cursor = conn.execute(
            """INSERT INTO iam_scan_snapshots
               (scan_timestamp, workflow_run_id, entity_count, risk_summary, raw_inventory)
               VALUES (?, ?, ?, ?, ?)""",
            (
                now,
                workflow_run_id,
                len(findings),
                json.dumps(risk_counts),
                json.dumps(inventory),
            ),
        )
        snapshot_id = cursor.lastrowid

        for f in findings:
            conn.execute(
                """INSERT INTO iam_findings
                   (snapshot_id, entity_type, entity_name, risk_score, risk_category,
                    description, recommendation, status, embedding)
                   VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?)""",
                (
                    snapshot_id,
                    f.get("entity_type", "unknown"),
                    f.get("entity_name", "unknown"),
                    f.get("risk_score", 0.0),
                    f.get("risk_category", ""),
                    f.get("description", ""),
                    f.get("recommendation", ""),
                    json.dumps(f.get("embedding")) if f.get("embedding") else None,
                ),
            )

        conn.commit()
        logger.info(
            f"Stored snapshot {snapshot_id} with {len(findings)} findings "
            f"(run={workflow_run_id})"
        )
        return snapshot_id
    finally:
        conn.close()


def get_latest_snapshot() -> dict[str, Any] | None:
    """Retrieve the most recent snapshot with its findings.

    Returns:
        Dict with keys: id, scan_timestamp, workflow_run_id, entity_count,
        risk_summary, findings (list). None if no snapshots exist.
    """
    init_db()
    conn = _connect()
    try:
        row = conn.execute(
            "SELECT * FROM iam_scan_snapshots ORDER BY scan_timestamp DESC LIMIT 1"
        ).fetchone()

        if not row:
            return None

        snapshot = dict(row)
        findings_rows = conn.execute(
            "SELECT * FROM iam_findings WHERE snapshot_id = ? ORDER BY risk_score DESC",
            (snapshot["id"],),
        ).fetchall()
        snapshot["findings"] = [dict(f) for f in findings_rows]

        return snapshot
    finally:
        conn.close()


def diff_snapshots(old_id: int, new_id: int) -> dict[str, list[dict]]:
    """Compare two snapshots and return the drift.

    Args:
        old_id: Snapshot ID of the previous scan.
        new_id: Snapshot ID of the current scan.

    Returns:
        Dict with keys: added, removed, modified. Each is a list of
        dicts with entity_type, entity_name, and details.
    """
    init_db()
    conn = _connect()
    try:
        old_findings = {
            (r["entity_type"], r["entity_name"]): dict(r)
            for r in conn.execute(
                "SELECT * FROM iam_findings WHERE snapshot_id = ?", (old_id,)
            ).fetchall()
        }
        new_findings = {
            (r["entity_type"], r["entity_name"]): dict(r)
            for r in conn.execute(
                "SELECT * FROM iam_findings WHERE snapshot_id = ?", (new_id,)
            ).fetchall()
        }

        old_keys = set(old_findings.keys())
        new_keys = set(new_findings.keys())

        added = [
            {"entity_type": k[0], "entity_name": k[1], **new_findings[k]}
            for k in new_keys - old_keys
        ]
        removed = [
            {"entity_type": k[0], "entity_name": k[1], **old_findings[k]}
            for k in old_keys - new_keys
        ]

        modified = []
        for k in old_keys & new_keys:
            old_f = old_findings[k]
            new_f = new_findings[k]
            if (
                old_f.get("risk_score") != new_f.get("risk_score")
                or old_f.get("status") != new_f.get("status")
                or old_f.get("risk_category") != new_f.get("risk_category")
            ):
                modified.append({
                    "entity_type": k[0],
                    "entity_name": k[1],
                    "old": {
                        "risk_score": old_f.get("risk_score"),
                        "risk_category": old_f.get("risk_category"),
                        "status": old_f.get("status"),
                    },
                    "new": {
                        "risk_score": new_f.get("risk_score"),
                        "risk_category": new_f.get("risk_category"),
                        "status": new_f.get("status"),
                    },
                })

        return {"added": added, "removed": removed, "modified": modified}
    finally:
        conn.close()


def log_remediation(
    finding_id: int,
    action: str,
    approver: str = "operator",
    pre_state: dict | None = None,
    post_state: dict | None = None,
) -> int:
    """Log a remediation action against a finding.

    Args:
        finding_id: The finding being remediated.
        action: Description of the action taken.
        approver: Who approved the action.
        pre_state: State before remediation (JSON-serializable).
        post_state: State after remediation (JSON-serializable).

    Returns:
        The remediation log entry ID.
    """
    init_db()
    conn = _connect()
    try:
        now = datetime.now(timezone.utc).isoformat()
        cursor = conn.execute(
            """INSERT INTO remediation_log
               (finding_id, action_taken, approved_by, timestamp, pre_state, post_state)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                finding_id,
                action,
                approver,
                now,
                json.dumps(pre_state) if pre_state else None,
                json.dumps(post_state) if post_state else None,
            ),
        )

        conn.execute(
            "UPDATE iam_findings SET status = 'remediated', remediated_at = ? WHERE id = ?",
            (now, finding_id),
        )

        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def get_finding_history(entity_name: str) -> list[dict[str, Any]]:
    """Retrieve all findings for an entity across all scans.

    Args:
        entity_name: The RAM entity (user/role/policy) to look up.

    Returns:
        List of finding dicts ordered by scan timestamp (newest first).
    """
    init_db()
    conn = _connect()
    try:
        rows = conn.execute(
            """SELECT f.*, s.scan_timestamp, s.workflow_run_id
               FROM iam_findings f
               JOIN iam_scan_snapshots s ON f.snapshot_id = s.id
               WHERE f.entity_name = ?
               ORDER BY s.scan_timestamp DESC""",
            (entity_name,),
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()
