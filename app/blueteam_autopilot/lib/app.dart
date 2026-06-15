import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'api/backend_client.dart';
import 'cubits/action_panel/action_panel_cubit.dart';
import 'cubits/incident_detail/incident_detail_cubit.dart';
import 'cubits/incident_list/incident_list_cubit.dart';
import 'theme/app_theme.dart';
import 'views/incident_detail/incident_detail_view.dart';
import 'views/incident_list/incident_list_view.dart';

class BlueTeamApp extends StatelessWidget {
  final BackendClient backendClient;

  const BlueTeamApp({super.key, required this.backendClient});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => IncidentListCubit(backendClient)),
        BlocProvider(create: (_) => IncidentDetailCubit(backendClient)),
        BlocProvider(create: (_) => ActionPanelCubit(backendClient)),
      ],
      child: MaterialApp.router(
        title: 'BlueTeam Autopilot',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        routerConfig: _buildRouter(),
      ),
    );
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'incidents',
          builder: (context, state) =>
              const _AppShell(child: IncidentListView()),
        ),
        GoRoute(
          path: '/incidents/:id',
          name: 'incident-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return _AppShell(
              showBack: true,
              child: IncidentDetailView(incidentId: id),
            );
          },
        ),
      ],
    );
  }
}

/// App shell with app bar and scaffold.
class _AppShell extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const _AppShell({required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Image.network(
                  'https://img.icons8.com/fluency/48/shield.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, error, stack) =>
                      const Icon(Icons.shield, color: Color(0xFF3B82F6)),
                ),
              ),
        title: const Text('BlueTeam Autopilot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Color(0xFF94A3B8)),
            tooltip: 'Trigger AI Analysis',
            onPressed: () {
              _showAnalysisDialog(context);
            },
          ),
        ],
      ),
      body: child,
    );
  }

  void _showAnalysisDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Trigger AI Analysis'),
        content: const Text(
          'This will trigger AI analysis of the latest security events '
          'from Alibaba Cloud. New incidents will appear in the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<IncidentListCubit>().refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Analysis triggered')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }
}
