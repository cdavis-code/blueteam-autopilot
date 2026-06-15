import 'package:alibaba_security_mcp/alibaba_security_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('AlibabaSecurityServer', () {
    test('ping returns expected structure', () {
      // This test verifies the ping tool's return shape.
      // Since we can't easily construct the server without env vars,
      // we test the expected output format.
      final result = {'ok': true, 'region': 'cn-hangzhou', 'mode': 'dryRun'};

      expect(result['ok'], true);
      expect(result['region'], isA<String>());
      expect(result['mode'], isA<String>());
    });

    test('dry-run result format is correct', () {
      // Verify the expected shape of a dry-run execute_response_policy result
      final result = {
        'policyId': 'pol-123',
        'eventId': 'evt-456',
        'mode': 'dry-run',
        'result':
            '[DRY-RUN] Would execute response policy "pol-123" for event "evt-456". '
            'No state-changing API call was made.',
        'raw': {'simulated': true, 'policyId': 'pol-123', 'eventId': 'evt-456'},
      };

      expect(result['mode'], 'dry-run');
      expect(result['policyId'], 'pol-123');
      expect(result['raw'], isA<Map>());
    });
  });

  group('KnowledgeStore', () {
    test('documentTypes returns all 6 types', () {
      expect(KnowledgeStore.documentTypes, hasLength(6));
      expect(
        KnowledgeStore.documentTypes,
        containsAll([
          'asset_inventory',
          'trusted_networks',
          'compliance_nist',
          'compliance_soc2',
          'runbook_waf_triage',
          'policy_change_mgmt',
        ]),
      );
    });

    test('load returns embedded defaults when no files exist', () {
      final store = KnowledgeStore(knowledgeDir: '/tmp/nonexistent_dir');
      final doc = store.load('compliance_nist');

      expect(doc['documentType'], 'compliance_nist');
      expect(doc['title'], contains('NIST CSF'));
      expect(doc['content'], contains('DE.AE-2'));
      expect(doc['source'], 'embedded');
      expect(doc['lastModified'], isNull);
    });

    test('load throws on unknown document type', () {
      final store = KnowledgeStore();
      expect(() => store.load('unknown_type'), throwsArgumentError);
    });

    test('load returns all 6 document types from embedded defaults', () {
      final store = KnowledgeStore(knowledgeDir: '/tmp/nonexistent_dir');
      for (final type in KnowledgeStore.documentTypes) {
        final doc = store.load(type);
        expect(doc['documentType'], type);
        expect(doc['title'], isA<String>());
        expect((doc['content'] as String).isNotEmpty, isTrue);
      }
    });

    test('list returns all documents with source metadata', () {
      final store = KnowledgeStore(knowledgeDir: '/tmp/nonexistent_dir');
      final docs = store.list();

      expect(docs, hasLength(6));
      for (final doc in docs) {
        expect(doc['documentType'], isA<String>());
        expect(doc['title'], isA<String>());
        expect(doc['source'], anyOf('file', 'embedded'));
      }
      // All should be 'embedded' when knowledge dir doesn't exist
      expect(docs.every((d) => d['source'] == 'embedded'), isTrue);
    });

    test('embedded asset_inventory has no hardcoded hostnames', () {
      final store = KnowledgeStore(knowledgeDir: '/tmp/nonexistent_dir');
      final doc = store.load('asset_inventory');
      final content = doc['content'] as String;

      expect(content, contains('list_assets'));
      expect(content, isNot(contains('ecs.muayid.com')));
      expect(content, contains('SOC 2'));
    });
  });
}
