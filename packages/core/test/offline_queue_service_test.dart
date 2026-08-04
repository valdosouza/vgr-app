import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OfflineQueueService> _service() async {
  final prefs = await SharedPreferences.getInstance();
  return OfflineQueueService(prefs: prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OfflineQueueService (decision 28, spec task 16)', () {
    test('enqueued task survives a restart (new instance, same storage)', () async {
      final queue = await _service();
      await queue.enqueue('report_submit', {'clientKey': 'abc'});

      final reborn = await _service();
      expect(await reborn.pendingCount(), 1);
    });

    test('flush dispatches in order and removes completed tasks', () async {
      final queue = await _service();
      final seen = <String>[];
      queue.register('kind', (payload) async {
        seen.add(payload['id'] as String);
        return QueueTaskResult.done;
      });
      await queue.enqueue('kind', {'id': 'first'});
      await queue.enqueue('kind', {'id': 'second'});

      await queue.flush();

      expect(seen, ['first', 'second']);
      expect(await queue.pendingCount(), 0);
    });

    test('retry keeps the task and STOPS the flush — order is the contract', () async {
      final queue = await _service();
      final seen = <String>[];
      queue.register('kind', (payload) async {
        seen.add(payload['id'] as String);
        return payload['id'] == 'first' ? QueueTaskResult.retry : QueueTaskResult.done;
      });
      await queue.enqueue('kind', {'id': 'first'});
      await queue.enqueue('kind', {'id': 'second'});

      await queue.flush();

      expect(seen, ['first']); // second never ran ahead of its predecessor
      expect(await queue.pendingCount(), 2);
    });

    test('a throwing handler behaves as retry (transport errors bubble)', () async {
      final queue = await _service();
      queue.register('kind', (_) async => throw Exception('socket'));
      await queue.enqueue('kind', {});

      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });

    test('drop removes the task without blocking the rest', () async {
      final queue = await _service();
      final seen = <String>[];
      queue.register('kind', (payload) async {
        seen.add(payload['id'] as String);
        return payload['id'] == 'first' ? QueueTaskResult.drop : QueueTaskResult.done;
      });
      await queue.enqueue('kind', {'id': 'first'});
      await queue.enqueue('kind', {'id': 'second'});

      await queue.flush();

      expect(seen, ['first', 'second']);
      expect(await queue.pendingCount(), 0);
    });

    test('a handler may enqueue follow-ups picked up in the same flush', () async {
      final queue = await _service();
      final seen = <String>[];
      queue.register('upload', (payload) async {
        seen.add('upload');
        await queue.enqueue('attach', {'publicId': 'x'});
        return QueueTaskResult.done;
      });
      queue.register('attach', (payload) async {
        seen.add('attach');
        return QueueTaskResult.done;
      });
      await queue.enqueue('upload', {});

      await queue.flush();

      expect(seen, ['upload', 'attach']);
      expect(await queue.pendingCount(), 0);
    });

    test('a kind with no registered handler is preserved, never dropped', () async {
      final queue = await _service();
      await queue.enqueue('unknown', {});

      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });

    test('pending notifier tracks the actual queue size', () async {
      final queue = await _service();
      queue.register('kind', (_) async => QueueTaskResult.done);

      await queue.enqueue('kind', {});
      expect(queue.pending.value, 1);

      await queue.flush();
      expect(queue.pending.value, 0);
    });
  });
}
