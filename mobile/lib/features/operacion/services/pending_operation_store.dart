import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/pending_operation.dart';

class PendingOperationStore {
  PendingOperationStore({this.rootDirectory});

  final Directory? rootDirectory;

  Future<List<PendingOperation>> readAll() async {
    final file = await _queueFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return decoded
          .cast<Map<String, dynamic>>()
          .map(PendingOperation.fromJson)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<PendingOperation> enqueue(
    PendingOperation operation, {
    String? sourcePhotoPath,
  }) async {
    var stored = operation;
    if (sourcePhotoPath != null) {
      final source = File(sourcePhotoPath);
      if (!await source.exists()) {
        throw FileSystemException('La fotografia local no existe.', sourcePhotoPath);
      }
      final directory = await _dataDirectory();
      final photos = Directory(
        '${directory.path}${Platform.pathSeparator}photos',
      );
      await photos.create(recursive: true);
      final suffix = sourcePhotoPath.toLowerCase().endsWith('.png')
          ? '.png'
          : '.jpg';
      final copy = await source.copy(
        '${photos.path}${Platform.pathSeparator}${operation.operationId}$suffix',
      );
      stored = operation.copyWith(photoPath: copy.path);
    }
    final operations = await readAll();
    operations.add(stored);
    await _writeAll(operations);
    return stored;
  }

  Future<PendingOperation> update(PendingOperation operation) async {
    final operations = await readAll();
    final index = operations.indexWhere(
      (item) => item.operationId == operation.operationId,
    );
    if (index < 0) throw StateError('Operacion local no encontrada.');
    operations[index] = operation;
    await _writeAll(operations);
    return operation;
  }

  Future<File> _queueFile() async {
    final directory = await _dataDirectory();
    return File('${directory.path}${Platform.pathSeparator}operations.json');
  }

  Future<Directory> _dataDirectory() async {
    final root = rootDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}pacific_control_operations',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _writeAll(List<PendingOperation> operations) async {
    final file = await _queueFile();
    await file.writeAsString(
      jsonEncode(operations.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}
