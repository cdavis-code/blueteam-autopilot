---
document_id: asset-inventory
version: "2026.1"
source: dynamic
discovery_tool: list_assets
last_updated: "2026-06-14"
---

# Asset Inventory

Asset topology reference for BlueTeam investigations.

---

## Dynamic Asset Discovery

**IMPORTANT:** Asset information is NOT static. The agent discovers assets
dynamically at runtime via the `list_assets` MCP tool, which queries
Security Center's `DescribeCloudCenterInstances` API.

### Why Dynamic Discovery?

- Assets change frequently (spin up/down, auto-scaling)
- Static inventories become stale quickly
- Live data ensures accurate incident correlation
- Asset tags (SOC 2 scope, sensitive workloads) are authoritative

---

## Asset Discovery Process

### Step 1: Call list_assets

At the start of each investigation (Behavior 1: Incident Discovery):

```
Call `list_assets` to discover the environment's cloud assets dynamically.
```

**CLI Alternative:**
```bash
aliyun sas describe-cloud-center-instances --region "$ALIBABA_REGION"
```

### Step 2: Build Asset Context

From the API response, extract:
- `assetId`: Unique identifier (e.g., `i-xxx`)
- `name`: Human-readable name
- `ip`: Public/private IP addresses
- `region`: Deployment region
- `type`: Asset type (ECS, RDS, etc.)
- `tags`: Labels (SOC 2 scope, production, sensitive, etc.)

### Step 3: Cross-Reference Events

For each security event:
1. Check `affectedAssets` against live asset list
2. If asset tagged **SOC 2 scope** → elevate to HIGH minimum
3. If asset tagged **sensitive workloads** → elevate to HIGH minimum
4. Document asset context in incident report

---

## Example Asset Structure

> **NOTE:** The values below are **EXAMPLES ONLY**. Replace with your actual environment values
> or use `get_account_context` MCP tool to discover assets dynamically at runtime.

```json
{
  "assets": [
    {
      "assetId": "i-prod-web-01",
      "name": "Production Web Server 01",
      "ip": "47.89.123.45",
      "region": "{{ALIBABA_REGION}}",
      "type": "ECS",
      "tags": ["production", "soc2-scope", "web-tier"]
    },
    {
      "assetId": "i-prod-db-01",
      "name": "Production Database 01",
      "ip": "10.0.1.100",
      "region": "{{ALIBABA_REGION}}",
      "type": "RDS",
      "tags": ["production", "soc2-scope", "data-tier", "sensitive"]
    }
  ]
}
```

---

## Asset Severity Elevation Rules

| Asset Tag | Elevation Rule | Rationale |
|-----------|----------------|-----------|
| `soc2-scope` | Minimum HIGH | SOC 2 audit requirements |
| `sensitive` | Minimum HIGH | Data protection mandate |
| `production` | +1 severity level | Business criticality |
| `web-tier` | No change | Standard monitoring |
| `data-tier` | +1 severity level | Data sensitivity |

**Example:**
- MEDIUM event on `i-prod-db-01` (tags: production, soc2-scope, sensitive)
- Elevated to: **HIGH** (soc2-scope and sensitive tags)

---

## Asset Topology Reference

### Typical Architecture

```
Internet
  └─ WAF ({{ALIBABA_REGION}})
     └─ ECS Web Tier (example: i-prod-web-01, i-prod-web-02)
        └─ RDS Data Tier (example: i-prod-db-01, i-prod-db-02)
           └─ S3 Storage (data lake)
```

### Network Segmentation

| Tier | Network | Access |
|------|---------|--------|
| Web Tier | Public subnet | WAF → ECS (ports 80, 443) |
| Data Tier | Private subnet | ECS → RDS (port 3306) |
| Storage | VPC endpoint | RDS → S3 (internal) |

---

## Compliance Mapping

Assets tagged with compliance scopes must follow specific controls:

| Tag | Compliance Framework | Controls |
|-----|---------------------|----------|
| `soc2-scope` | SOC 2 Type II | CC6.1, CC6.8 |
| `pci-scope` | PCI DSS | Requirement 1, 2, 6 |
| `hipaa-scope` | HIPAA | Technical Safeguards |

---

## Troubleshooting

### "Asset not found in list_assets"

1. Verify asset is registered in Security Center
2. Check if asset was recently decommissioned
3. Confirm Security Center agent is installed on asset
4. Re-run `list_assets` to refresh inventory

### "Event references unknown asset"

1. Check if asset is in different region
2. Verify asset ID format (may be internal ID vs. Security Center ID)
3. Cross-reference with cloud console directly
4. Document as investigation finding

---

## Update Procedure

Assets are automatically discovered. No manual inventory maintenance required.

To ensure accurate discovery:
1. Install Security Center agent on all assets
2. Tag assets appropriately in Security Center console
3. Review asset inventory monthly for completeness

**Last Updated:** 2026-06-14
