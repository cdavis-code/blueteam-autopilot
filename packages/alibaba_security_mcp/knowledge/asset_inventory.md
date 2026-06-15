# Asset Inventory — Network Topology

Asset inventory is sourced dynamically from Security Center via the
`list_assets` MCP tool (DescribeCloudCenterInstances API). Call `list_assets`
at session start or during incident discovery to build a live view of the
environment's cloud assets.

## How to Classify Assets

After calling `list_assets`, classify each returned asset by:

1. **SOC 2 Scope** — assets hosting sensitive workloads (payment APIs,
   customer data stores, auth services) are SOC 2 strict scope.
2. **Severity Elevation** — any event targeting SOC 2 scoped assets
   is elevated to HIGH or above regardless of initial severity scoring.
3. **Region Awareness** — cross-reference asset `regionId` with the
   configured region to identify cross-region events.

## Environment-Specific Assets

Replace or extend this section with assets specific to your environment.
Example:

| Asset | Domain / IP | Purpose | SOC 2 Scope |
|-------|-------------|---------|-------------|
| _example_ | _app.example.com_ | _Primary API_ | _Yes — strict_ |

## Elevation Rules

- Any event targeting SOC 2 scoped assets → minimum severity **HIGH**
- Any event targeting restricted database-linked assets → minimum severity **HIGH**
