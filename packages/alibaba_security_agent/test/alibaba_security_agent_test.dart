import 'dart:convert';

import 'package:alibaba_security_agent/alibaba_security_agent.dart';
import 'package:test/test.dart';

void main() {
  group('SecOpsKnowledge', () {
    test('summary references dynamic asset discovery and controls', () {
      final summary = SecOpsKnowledge.summary();
      expect(summary, contains('list_assets'));
      expect(summary, contains('SOC 2'));
      expect(summary, contains('NIST CSF'));
      // No hardcoded hostnames
      expect(summary, isNot(contains('ecs.muayid.com')));
    });

    test('assetSummary describes dynamic discovery framework', () {
      expect(SecOpsKnowledge.assetSummary, contains('list_assets'));
      expect(SecOpsKnowledge.assetSummary, contains('HIGH'));
      // No hardcoded hostnames
      expect(SecOpsKnowledge.assetSummary, isNot(contains('ecs.muayid.com')));
    });

    test('trustedNetworkReminder warns against blind blocking', () {
      expect(
        SecOpsKnowledge.trustedNetworkReminder,
        contains('never blindly block'),
      );
    });
  });

  group('SystemPrompt', () {
    late String prompt;

    setUpAll(() {
      prompt = SystemPrompt.build();
    });

    test('contains role definition', () {
      expect(prompt, contains('BlueTeam Autopilot'));
    });

    test('lists all MCP tools', () {
      const tools = [
        'ping',
        'get_account_context',
        'list_security_events',
        'get_security_event_detail',
        'list_alerts_for_event',
        'list_vulnerabilities',
        'get_vulnerability_detail',
        'list_response_policies',
        'execute_response_policy',
        'get_waf_instance_info',
        'list_waf_security_events',
        'list_waf_top_rules',
        'list_waf_top_ips',
        'list_assets',
        'list_knowledge_documents',
        'get_knowledge_document',
      ];
      for (final tool in tools) {
        expect(prompt, contains(tool), reason: 'Missing tool: $tool');
      }
    });

    test('defines all 5 core behaviors', () {
      expect(prompt, contains('Incident Discovery'));
      expect(prompt, contains('Incident Deep-Dive'));
      expect(prompt, contains('Recommendation Synthesis'));
      expect(prompt, contains('Action Proposal'));
      expect(prompt, contains('Reporting'));
    });

    test('enforces dry-run default', () {
      expect(prompt, contains('dry-run'));
      expect(prompt, contains('default'));
    });

    test('references compliance controls', () {
      expect(prompt, contains('DE.AE-2'));
      expect(prompt, contains('CC6.8'));
      expect(prompt, contains('RS.RP-1'));
    });

    test('references trusted networks', () {
      expect(prompt, contains('trusted network'));
      expect(prompt, contains('potentially compromised'));
    });

    test('references change management policy', () {
      expect(prompt, contains('Change Mgmt'));
    });

    test('references dynamic asset discovery', () {
      expect(prompt, contains('list_assets'));
      expect(prompt, isNot(contains('ecs.muayid.com')));
    });

    test('never allows execute without human approval', () {
      expect(prompt, contains('NEVER call `execute_response_policy`'));
      expect(prompt, contains('explicit human approval'));
    });

    test('defines knowledge fetching policy', () {
      expect(prompt, contains('Knowledge Fetching Policy'));
      expect(prompt, contains('Do NOT call `get_knowledge_document`'));
      expect(prompt, contains('list_knowledge_documents'));
    });
  });

  group('BehaviorPrompts', () {
    test(
      'incidentDiscovery references list_assets and knowledge tools conditionally',
      () {
        final prompt = BehaviorPrompts.incidentDiscovery();
        expect(prompt, contains('list_assets'));
        expect(prompt, contains('list_security_events'));
        // No hardcoded hostnames
        expect(prompt, isNot(contains('ecs.muayid.com')));
        // Knowledge fetching is conditional, not mandatory
        expect(prompt, contains('get_knowledge_document'));
        expect(prompt, contains('asset_inventory'));
        expect(prompt, contains('If the user asks'));
      },
    );

    test('incidentDeepDive references knowledge tools conditionally', () {
      final prompt = BehaviorPrompts.incidentDeepDive();
      expect(prompt, contains('get_knowledge_document'));
      expect(prompt, contains('compliance_nist'));
      expect(prompt, contains('runbook_waf_triage'));
      expect(prompt, contains('trusted_networks'));
      // Should use conditional language
      expect(prompt, contains('If the user asks'));
    });

    test(
      'recommendationSynthesis references knowledge tools conditionally',
      () {
        final prompt = BehaviorPrompts.recommendationSynthesis();
        expect(prompt, contains('get_knowledge_document'));
        expect(prompt, contains('compliance_nist'));
        expect(prompt, contains('list_response_policies'));
        expect(prompt, contains('If the user asks'));
      },
    );

    test('actionProposal references knowledge tools conditionally', () {
      final prompt = BehaviorPrompts.actionProposal();
      expect(prompt, contains('get_knowledge_document'));
      expect(prompt, contains('policy_change_mgmt'));
      expect(prompt, contains('compliance_soc2'));
      expect(prompt, contains('requiresApproval'));
      expect(prompt, contains('If the user asks'));
    });

    test('reporting references knowledge tools conditionally', () {
      final prompt = BehaviorPrompts.reporting();
      expect(prompt, contains('get_knowledge_document'));
      expect(prompt, contains('compliance_nist'));
      expect(prompt, contains('compliance_soc2'));
      expect(prompt, contains('If the user asks'));
    });
  });

  group('IncidentReport', () {
    final report = IncidentReport(
      eventId: 'evt-test-001',
      title: 'WAF SQLi Attack on Payment Portal',
      severity: 'HIGH',
      aiSummary: 'An attacker at 1.2.3.4 attempted SQL injection.',
      rootCause: 'Unpatched SQL injection vector on /api/login endpoint.',
      businessImpact: 'Potential data breach of payment records.',
      attackChain: [
        AttackChainEntry(stage: 'Recon', description: 'Port scanning'),
        AttackChainEntry(stage: 'Exploit', description: 'SQLi on /api/login'),
      ],
      affectedAssets: ['ecs.muayid.com'],
      sourceIps: ['1.2.3.4'],
      relatedCves: ['CVE-2024-1234'],
      complianceControls: ['NIST CSF DE.AE-2', 'SOC 2 CC6.8'],
      generatedAt: '2026-06-11T12:00:00Z',
    );

    test('round-trip serialization', () {
      final json = report.toJson();
      final decoded = IncidentReport.fromJson(json);
      expect(decoded.eventId, report.eventId);
      expect(decoded.title, report.title);
      expect(decoded.severity, report.severity);
      expect(decoded.attackChain.length, 2);
      expect(decoded.attackChain[0].stage, 'Recon');
      expect(decoded.sourceIps, ['1.2.3.4']);
      expect(decoded.complianceControls, contains('NIST CSF DE.AE-2'));
    });

    test('toJson produces valid JSON string', () {
      final jsonStr = jsonEncode(report.toJson());
      expect(() => jsonDecode(jsonStr), returnsNormally);
    });
  });

  group('ActionProposal', () {
    final proposal = ActionProposal(
      reasoning: 'Block attacker IP per NIST CSF RS.RP-1',
      recommendedPolicyId: 'pol-block-ip',
      expectedEffects: 'Block IP 1.2.3.4 for 24 hours via WAF',
      rollbackPlan: 'Remove IP from WAF blacklist',
      riskLevel: 'MEDIUM',
      complianceControls: ['SOC 2 CC6.8', 'NIST CSF RS.RP-1'],
      eventId: 'evt-test-001',
      trustedNetworkMatch: false,
    );

    test('round-trip serialization', () {
      final json = proposal.toJson();
      final decoded = ActionProposal.fromJson(json);
      expect(decoded.reasoning, proposal.reasoning);
      expect(decoded.recommendedPolicyId, 'pol-block-ip');
      expect(decoded.requiresApproval, isTrue);
      expect(decoded.trustedNetworkMatch, isFalse);
      expect(decoded.complianceControls, contains('SOC 2 CC6.8'));
    });

    test('requiresApproval defaults to true', () {
      final p = ActionProposal(
        reasoning: 'test',
        recommendedPolicyId: 'pol-1',
        expectedEffects: 'test',
        rollbackPlan: 'test',
        riskLevel: 'LOW',
      );
      expect(p.requiresApproval, isTrue);
    });
  });

  group('VulnerabilityPrioritization', () {
    final prioritization = VulnerabilityPrioritization(
      rankedVulns: [
        RankedVulnerability(
          vulId: 'vul-001',
          name: 'OpenSSL Buffer Overflow',
          severity: 'CRITICAL',
          cveId: 'CVE-2024-5678',
          assetId: 'ecs-001',
          rank: 1,
          remediationSteps: 'Upgrade OpenSSL to 3.0.12',
        ),
        RankedVulnerability(
          vulId: 'vul-002',
          name: 'Nginx Path Traversal',
          severity: 'HIGH',
          cveId: 'CVE-2024-9012',
          assetId: 'ecs-001',
          rank: 2,
          remediationSteps: 'Upgrade Nginx to 1.25.4',
        ),
      ],
      remediationSteps: 'Patch OpenSSL first, then Nginx.',
      assetGrouping: {
        'ecs-001': ['vul-001', 'vul-002'],
      },
      totalAnalyzed: 15,
      generatedAt: '2026-06-11T12:00:00Z',
    );

    test('round-trip serialization', () {
      final json = prioritization.toJson();
      final decoded = VulnerabilityPrioritization.fromJson(json);
      expect(decoded.rankedVulns.length, 2);
      expect(decoded.rankedVulns[0].rank, 1);
      expect(decoded.rankedVulns[0].cveId, 'CVE-2024-5678');
      expect(decoded.totalAnalyzed, 15);
      expect(decoded.assetGrouping['ecs-001'], hasLength(2));
    });
  });

  group('ReportTemplates', () {
    final report = IncidentReport(
      eventId: 'evt-render-001',
      title: 'WAF Attack on Payment Portal',
      severity: 'HIGH',
      aiSummary: 'SQL injection attack detected.',
      rootCause: 'Unpatched SQLi vector',
      businessImpact: 'Payment data at risk',
      attackChain: [
        AttackChainEntry(stage: 'Exploit', description: 'SQLi on /api/login'),
      ],
      affectedAssets: ['ecs.muayid.com'],
      sourceIps: ['5.6.7.8'],
      relatedCves: ['CVE-2024-1234'],
      complianceControls: ['NIST CSF DE.AE-2', 'SOC 2 CC6.8'],
      generatedAt: '2026-06-11T12:00:00Z',
    );

    test('renderIncidentReport contains expected sections', () {
      final md = ReportTemplates.renderIncidentReport(report);
      expect(md, contains('# Incident Report: WAF Attack on Payment Portal'));
      expect(md, contains('## AI Summary'));
      expect(md, contains('## Root Cause'));
      expect(md, contains('## Business Impact'));
      expect(md, contains('## Attack Chain'));
      expect(md, contains('## Affected Assets'));
      expect(md, contains('## Source IPs'));
      expect(md, contains('## Related CVEs'));
      expect(md, contains('## Compliance Controls'));
      expect(md, contains('NIST CSF DE.AE-2'));
    });

    test('renderVulnerabilityTriage contains ranked table', () {
      final prior = VulnerabilityPrioritization(
        rankedVulns: [
          RankedVulnerability(
            vulId: 'vul-001',
            name: 'Test Vuln',
            severity: 'CRITICAL',
            rank: 1,
            remediationSteps: 'Patch it',
          ),
        ],
        remediationSteps: 'Patch all critical vulns',
        assetGrouping: {
          'ecs-001': ['vul-001'],
        },
        totalAnalyzed: 10,
      );
      final md = ReportTemplates.renderVulnerabilityTriage(prior);
      expect(md, contains('# Vulnerability Prioritization Report'));
      expect(md, contains('## Ranked Vulnerabilities'));
      expect(md, contains('vul-001'));
      expect(md, contains('## Vulnerabilities by Asset'));
    });

    test('renderActionProposal contains approval section', () {
      final proposal = ActionProposal(
        reasoning: 'Block attacker IP',
        recommendedPolicyId: 'pol-block',
        expectedEffects: 'Block IP for 24h',
        rollbackPlan: 'Remove from blacklist',
        riskLevel: 'MEDIUM',
        complianceControls: ['SOC 2 CC6.8'],
        eventId: 'evt-001',
      );
      final md = ReportTemplates.renderActionProposal(proposal);
      expect(md, contains('# Action Proposal'));
      expect(md, contains('Human approval is REQUIRED'));
      expect(md, contains('SOC 2 CC6.8'));
      expect(md, contains('APPROVED'));
    });

    test('renderActionProposal warns on trusted network match', () {
      final proposal = ActionProposal(
        reasoning: 'Suspicious internal IP',
        recommendedPolicyId: 'pol-escalate',
        expectedEffects: 'Escalate to security team',
        rollbackPlan: 'N/A',
        riskLevel: 'HIGH',
        trustedNetworkMatch: true,
      );
      final md = ReportTemplates.renderActionProposal(proposal);
      expect(md, contains('WARNING'));
      expect(md, contains('trusted network'));
    });

    test('renderRunbookChecklist matches runbook structure', () {
      final md = ReportTemplates.renderRunbookChecklist(report);
      expect(md, contains('RUN-SEC-042'));
      expect(md, contains('Contextual Discovery'));
      expect(md, contains('Attack Chain Verification'));
      expect(md, contains('Mitigation Execution'));
      expect(md, contains('Rollback & Logging'));
      expect(md, contains('Compliance Evidence'));
    });
  });

  group('AgentConfig', () {
    test('default constructor uses sensible defaults', () {
      final config = AgentConfig(
        mcpServerEndpoint: 'stdio',
        systemPrompt: 'test prompt',
      );
      expect(config.defaultTimeRange, 'lastHour');
      expect(config.defaultDryRun, isTrue);
      expect(config.maxIncidentsPerRun, 10);
    });

    test('toQwenCloudManifest produces valid structure', () {
      final config = AgentConfig(
        mcpServerEndpoint: 'stdio',
        systemPrompt: 'You are BlueTeam Autopilot...',
      );
      final manifest = config.toQwenCloudManifest();
      expect(manifest['name'], 'BlueTeam Autopilot');
      expect(manifest['version'], '0.1.0');
      expect(manifest['systemPrompt'], contains('BlueTeam Autopilot'));
      expect(manifest['mcpServers'], isList);
      expect(
        (manifest['mcpServers'] as List).first['name'],
        'alibaba-security-mcp',
      );
      expect(manifest['parameters']['defaultDryRun'], isTrue);
    });

    test('toManifestJson produces valid JSON', () {
      final config = AgentConfig(
        mcpServerEndpoint: 'stdio',
        systemPrompt: 'test',
      );
      final jsonStr = config.toManifestJson();
      expect(() => jsonDecode(jsonStr), returnsNormally);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed['name'], 'BlueTeam Autopilot');
    });

    test('http endpoint uses http transport in manifest', () {
      final config = AgentConfig(
        mcpServerEndpoint: 'https://mcp.example.com',
        systemPrompt: 'test',
      );
      final manifest = config.toQwenCloudManifest();
      final server =
          (manifest['mcpServers'] as List).first as Map<String, dynamic>;
      expect(server['transport'], 'http');
    });
  });
}
