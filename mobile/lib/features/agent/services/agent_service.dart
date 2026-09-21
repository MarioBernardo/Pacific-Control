import '../../../services/authenticated_api_client.dart';
import '../models/agent_response.dart';

class AgentService {
  const AgentService(this._client);
  final AuthenticatedApiClient _client;
  Future<AgentResponse> consult(String question) async {
    final response = await _client.post('/agente/consultar', body: {'pregunta': question.trim()}) as Map<String, dynamic>;
    return AgentResponse.fromJson(response['data'] as Map<String, dynamic>);
  }
}
