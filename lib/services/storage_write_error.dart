import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../models/storage_capacity.dart';

typedef StorageFailureReporter =
    void Function(Object error, StackTrace stackTrace);

class StorageWriteException implements Exception {
  const StorageWriteException({
    required this.kind,
    required this.operation,
    required this.cause,
  });

  final StorageFailureKind kind;
  final String operation;
  final Object cause;

  @override
  String toString() => 'Storage $operation failed ($kind): $cause';
}

StorageFailureKind classifyStorageFailure(Object error) {
  if (error is FileSystemException) return StorageFailureKind.fileSystem;
  if (error is DatabaseException) {
    final message = error.toString().toLowerCase();
    if (error.getResultCode() == 13 ||
        message.contains('disk is full') ||
        message.contains('no space left')) {
      return StorageFailureKind.capacity;
    }
    return StorageFailureKind.sqlite;
  }
  if (error is PlatformException || error is MissingPluginException) {
    return StorageFailureKind.platform;
  }
  return StorageFailureKind.unexpected;
}

Future<T> runStorageWrite<T>(
  String operation,
  Future<T> Function() write,
) async {
  try {
    return await write();
  } on StorageWriteException {
    rethrow;
  } catch (error, stackTrace) {
    final failure = StorageWriteException(
      kind: classifyStorageFailure(error),
      operation: operation,
      cause: error,
    );
    reportStorageFailure(failure, stackTrace);
    throw failure;
  }
}

void reportStorageFailure(Object error, StackTrace stackTrace) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'local storage',
    ),
  );
}
