import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_provider.dart';
import '../services/agent_service.dart';

final agentServiceProvider = Provider<AgentService>((ref) => AgentService(ref.read(authenticatedApiClientProvider)));
