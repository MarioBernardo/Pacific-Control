class AgentResponse {
  const AgentResponse({required this.answer, required this.data, required this.internalSources, required this.generatedByAi});
  final String answer;
  final Map<String, dynamic> data;
  final List<String> internalSources;
  final bool generatedByAi;
  factory AgentResponse.fromJson(Map<String, dynamic> json) => AgentResponse(
    answer: json['respuesta'] as String,
    data: Map<String, dynamic>.from(json['datos'] as Map),
    internalSources: (json['fuentes_internas'] as List<dynamic>).map((item) => item.toString()).toList(growable: false),
    generatedByAi: json['generado_por_ia'] as bool? ?? false,
  );
}
