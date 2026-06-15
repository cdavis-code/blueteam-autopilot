/// Backend service for BlueTeam Autopilot.
///
/// Provides REST API endpoints for incident management, AI-driven analysis
/// via Qwen Cloud, and persistence to Alibaba Cloud TableStore.
library;

// Config
export 'src/config/backend_config.dart';

// Handlers
export 'src/handlers/analysis_handler.dart';
export 'src/handlers/health_handler.dart';
export 'src/handlers/incident_handler.dart';

// Middleware
export 'src/middleware/cors_middleware.dart';

// Repositories
export 'src/repositories/incident_repository.dart';
export 'src/repositories/recommendation_repository.dart';

// Server
export 'src/server.dart';

// Services
export 'src/services/analysis_service.dart';
export 'src/services/qwen_client.dart';

// TableStore
export 'src/tablestore/tablestore_client.dart';
