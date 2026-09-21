import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/authenticated_api_client.dart';
import '../models/agent_response.dart';
import '../providers/agent_provider.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});
  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final _controller = TextEditingController();
  AgentResponse? _response;
  String? _error;
  bool _loading = false;
  static const _quickQuestions = [
    'Dame un resumen operativo del día',
    '¿Cuántos guardias están en turno?',
    'Resume las novedades abiertas',
    '¿Qué guardias registraron asistencia hoy?',
  ];

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _consult([String? quickQuestion]) async {
    final question = (quickQuestion ?? _controller.text).trim();
    if (question.isEmpty) { setState(() => _error = 'Escribe una pregunta antes de consultar.'); return; }
    if (quickQuestion != null) _controller.text = quickQuestion;
    setState(() { _loading = true; _error = null; _response = null; });
    try {
      final response = await ref.read(agentServiceProvider).consult(question);
      if (mounted) setState(() => _response = response);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No fue posible consultar al asistente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _newQuery() { _controller.clear(); setState(() { _response = null; _error = null; }); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ASISTENTE PACIFIC')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Consulta información operativa registrada en Pacific Control. Las respuestas se generan únicamente con datos autorizados del sistema.'),
      const SizedBox(height: 18),
      TextField(
        controller: _controller, enabled: !_loading, maxLength: 500, minLines: 2, maxLines: 4,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Pregunta', hintText: 'Ej.: ¿Cuántos guardias están en turno?', border: OutlineInputBorder()),
        onSubmitted: (_) => _consult(),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final question in _quickQuestions) ActionChip(label: Text(question), onPressed: _loading ? null : () => _consult(question))]),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _loading ? null : _consult, icon: const Icon(Icons.auto_awesome), label: const Text('Consultar')),
      if (_loading) ...[const SizedBox(height: 24), const Center(child: CircularProgressIndicator())],
      if (_error != null) ...[const SizedBox(height: 18), Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))],
      if (_response != null) ...[
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Respuesta', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), SelectableText(_response!.answer), const SizedBox(height: 12),
          Text('Fuentes internas: ${_response!.internalSources.join(', ')}', style: Theme.of(context).textTheme.bodySmall),
        ]))),
        const SizedBox(height: 10), OutlinedButton(onPressed: _newQuery, child: const Text('Nueva consulta')),
      ],
    ])),
  );
}
