import 'package:flutter_test/flutter_test.dart';
import 'package:purereader/startup/lazy_service_loader.dart';

class TestService {
  final String name;
  TestService(this.name);
}

void main() {
  group('LazyServiceLoader', () {
    setUp(() {
      LazyServiceLoader.clear();
    });

    test('should register and retrieve a service', () async {
      LazyServiceLoader.register<TestService>(() async => TestService('test'));
      
      final service = await LazyServiceLoader.getService<TestService>();
      
      expect(service, isA<TestService>());
      expect(service.name, 'test');
    });

    test('should return the same instance for multiple calls (singleton behavior)', () async {
      int createCount = 0;
      LazyServiceLoader.register<TestService>(() async {
        createCount++;
        return TestService('test');
      });
      
      final service1 = await LazyServiceLoader.getService<TestService>();
      final service2 = await LazyServiceLoader.getService<TestService>();
      
      expect(service1, same(service2));
      expect(createCount, 1);
    });

    test('should throw if service not registered', () async {
      expect(
        () => LazyServiceLoader.getService<TestService>(),
        throwsException,
      );
    });
    
    test('should return null for getServiceSync if not initialized', () {
      LazyServiceLoader.register<TestService>(() async => TestService('test'));
      expect(LazyServiceLoader.getServiceSync<TestService>(), isNull);
    });
    
    test('should return instance for getServiceSync if initialized', () async {
      LazyServiceLoader.register<TestService>(() async => TestService('test'));
      await LazyServiceLoader.getService<TestService>();
      
      expect(LazyServiceLoader.getServiceSync<TestService>(), isNotNull);
    });
  });
}
