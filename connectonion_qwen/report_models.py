"""Pydantic models for Incident Response report generation.

These models define the structured data returned by generate_incident_report.
They extend the existing incident-report.json schema with IR-specific fields:
timeline, blast radius, confidence rating, recommended actions, and audit trail.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class AttackChainStage(BaseModel):
    """Single stage in an attack chain (e.g., Reconnaissance → Exploitation)."""

    stage: str = Field(description="Attack stage name", examples=["Reconnaissance"])
    description: str = Field(description="Stage description")
    evidence: str = Field(default="", description="Supporting evidence for this stage")


class AffectedAsset(BaseModel):
    """An asset impacted by the incident."""

    assetId: str = Field(description="Cloud asset identifier", examples=["i-prod-web-01"])
    name: str = Field(default="", description="Human-readable asset name")
    ip: str = Field(default="", description="Private or public IP address")
    criticality: str = Field(
        default="MEDIUM",
        description="Asset criticality based on tags and role",
    )
    tags: list[str] = Field(
        default_factory=list,
        description="Asset tags (e.g., SOC 2 scope, production)",
    )


class TimelineEvent(BaseModel):
    """Chronological event in the investigation timeline."""

    timestamp: str = Field(description="ISO 8601 timestamp or relative time")
    event: str = Field(description="What happened")
    source: str = Field(
        default="",
        description="Data source (e.g., WAF logs, Security Center, SLS)",
    )


class RecommendedAction(BaseModel):
    """A recommended response action with associated policy."""

    action: str = Field(description="Description of the recommended action")
    policyId: str = Field(default="", description="Response policy ID if applicable")
    riskLevel: Literal["LOW", "MEDIUM", "HIGH"] = Field(
        default="MEDIUM",
        description="Risk level of this action",
    )


class AuditEntry(BaseModel):
    """Record of a tool call made during the investigation."""

    tool: str = Field(description="Tool name called", examples=["get_security_event_detail"])
    timestamp: str = Field(default="", description="When the tool was called")
    summary: str = Field(default="", description="Brief summary of the result")


class IncidentReport(BaseModel):
    """Complete incident response report.

    Extends the existing incident-report.json schema with:
    - timeline: chronological investigation reconstruction
    - blastRadius: scope and impact assessment
    - confidence: verdict confidence (0.0–1.0)
    - recommendedActions: prioritized response actions
    - auditTrail: tools and data sources consulted
    """

    eventId: str = Field(description="Security Center event ID")
    title: str = Field(description="Human-readable incident title")
    severity: Literal["CRITICAL", "HIGH", "MEDIUM", "LOW"] = Field(
        description="Incident severity level"
    )
    generatedAt: str = Field(default="", description="ISO 8601 generation timestamp")
    aiSummary: str = Field(description="AI-generated incident summary")
    rootCause: str = Field(description="Root cause analysis")
    businessImpact: str = Field(description="Business impact assessment")
    attackChain: list[AttackChainStage] = Field(
        default_factory=list,
        description="Attack chain stages with evidence",
    )
    affectedAssets: list[AffectedAsset] = Field(
        default_factory=list,
        description="Assets impacted by the incident",
    )
    sourceIps: list[str] = Field(
        default_factory=list,
        description="Source IP addresses involved",
    )
    relatedCves: list[str] = Field(
        default_factory=list,
        description="Related CVE identifiers (CVE-YYYY-NNNNN)",
    )
    complianceControls: list[str] = Field(
        default_factory=list,
        description="Applicable compliance controls (e.g., NIST CSF DE.AE-2)",
    )
    timeline: list[TimelineEvent] = Field(
        default_factory=list,
        description="Chronological investigation timeline",
    )
    blastRadius: str = Field(
        default="",
        description="Scope and impact assessment — what systems/data are affected",
    )
    recommendedActions: list[RecommendedAction] = Field(
        default_factory=list,
        description="Prioritized response actions with policies",
    )
    rollbackPlan: str = Field(
        default="",
        description="How to undo the recommended actions",
    )
    confidence: float = Field(
        default=0.0,
        description="Verdict confidence (0.0–1.0), e.g., 0.85 for True Positive >85%",
    )
    auditTrail: list[AuditEntry] = Field(
        default_factory=list,
        description="Tool calls and data sources consulted during investigation",
    )
