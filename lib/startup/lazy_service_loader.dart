import 'package:flutter/foundation.dart';

class LazyServiceLoader {
  static final Map<Type, dynamic> _services = {};
  static final Map<Type, Future<dynamic> Function()> _factories = {};

  static void register<T>(Future<T> Function() factory) {
    _factories[T] = factory;
  }

  static Future<T> getService<T>() async {
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }

    if (!_factories.containsKey(T)) {
      throw Exception('Service of type $T not registered');
    }

    final service = await _factories[T]!();
    _services[T] = service;
    return service;
  }
  
  static T? getServiceSync<T>() {
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    return null;
  }

  @visibleForTesting
  static void clear() {
    _services.clear();
    _factories.clear();
  }
}
