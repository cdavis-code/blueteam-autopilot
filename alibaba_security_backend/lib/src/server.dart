import 'package:alibaba_security_api/alibaba_security_api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config/backend_config.dart';
import 'handlers/analysis_handler.dart';
import 'handlers/health_handler.dart';
import 'handlers/incident_handler.dart';
import 'middleware/cors_middleware.dart';
import 'repositories/incident_repository.dart';
import 'repositories/recommendation_repository.dart';
import 'services/analysis_service.dart';
import 'services/qwen_client.dart';
import 'tablestore/tablestore_client.dart';

/// The BlueTeam Autopilot backend server.
///
/// Wires together the Shelf router, repositories, Qwen client, and
/// Alibaba Cloud API services. Exposes REST endpoints for incident
/// management and AI-driven analysis.
class BackendServer {
  final BackendConfig config;
  late final Router _router;
  late final IncidentRepository incidentRepo;
  late final RecommendationRepository recommendationRepo;
  late final AnalysisService analysisService;

  BackendServer(this.config) {
    _initialize();
  }

  void _initialize() {
    // --- TableStore client (optional) ---
    TableStoreClient? tableStoreClient;
    if (config.hasTableStore) {
      try {
        final credentials = AlibabaCredentials.fromEnvironment();
        tableStoreClient = TableStoreClient(
          credentials: credentials,
          endpoint: config.tablestoreEndpoint,
          instanceName: config.tablestoreInstance,
        );
      } catch (_) {
        // Fall back to in-memory if credentials aren't available
        tableStoreClient = null;
      }
    }

    // --- Repositories ---
    incidentRepo = IncidentRepository(
      client: tableStoreClient,
      config: config,
    );
    recommendationRepo = RecommendationRepository(
      client: tableStoreClient,
      config: config,
    );

    // --- Alibaba Cloud API client ---
    AlibabaApiClient? apiClient;
    SecurityCenterService? securityCenter;
    CloudSiemService? cloudSiem;
    try {
      apiClient = AlibabaApiClient.fromEnvironment();
      securityCenter = SecurityCenterService(apiClient);
      cloudSiem = CloudSiemService(apiClient);
    } catch (_) {
      // API client not available — analysis features will be limited
    }

    // --- Qwen client ---
    QwenClient? qwenClient;
    if (config.hasQwen) {
      qwenClient = QwenClient.fromConfig(config);
    }

    // --- Analysis service ---
    if (securityCenter != null && cloudSiem != null && qwenClient != null) {
      analysisService = AnalysisService(
        securityCenter: securityCenter,
        cloudSiem: cloudSiem,
        qwenClient: qwenClient,
        incidentRepo: incidentRepo,
        recommendationRepo: recommendationRepo,
        config: config,
      );
    } else {
      // Create a stub analysis service that returns errors
      analysisService = _createStubAnalysisService();
    }

    // --- Handlers ---
    final healthHandler = HealthHandler(config);
    final incidentHandler = IncidentHandler(incidentRepo, recommendationRepo);
    final analysisHandler = AnalysisHandler(analysisService, recommendationRepo);

    // --- Router ---
    _router = Router()
      ..mount('/', healthHandler.router.call)
      ..mount('/', incidentHandler.router.call)
      ..mount('/', analysisHandler.router.call);
  }

  AnalysisService _createStubAnalysisService() {
    // Create a minimal API client with dummy credentials for the stub
    final dummyClient = AlibabaApiClient(
      credentials: const AlibabaCredentials(
        accessKeyId: 'stub',
        accessKeySecret: 'stub',
      ),
      region: config.region,
    );

    return AnalysisService(
      securityCenter: SecurityCenterService(dummyClient),
      cloudSiem: CloudSiemService(dummyClient),
      qwenClient: QwenClient(apiKey: ''),
      incidentRepo: incidentRepo,
      recommendationRepo: recommendationRepo,
      config: config,
    );
  }

  /// The Shelf [Handler] for this server (with CORS middleware applied).
  Handler get handler =>
      const Pipeline().addMiddleware(corsMiddleware()).addHandler(_router.call);

  /// Returns the underlying [Router] for testing.
  Router get router => _router;
}
