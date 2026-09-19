import 'package:flutter/material.dart';

class TurnoSelector extends StatelessWidget {
  const TurnoSelector({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onChanged,
  });

  final List<String> opciones;
  final String? seleccion;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Tipo de turno',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final opcion in opciones)
              ButtonSegment<String>(value: opcion, label: Text(opcion)),
          ],
          selected: seleccion == null ? <String>{} : {seleccion!},
          emptySelectionAllowed: true,
          onSelectionChanged: (values) {
            onChanged(values.isEmpty ? null : values.first);
          },
        ),
        if (seleccion == null) ...[
          const SizedBox(height: 8),
          const Text('Seleccione el tipo de turno.'),
        ],
      ],
    );
  }
}
