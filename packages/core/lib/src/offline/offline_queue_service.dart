import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a handler tells the queue about the task it just ran.
enum QueueTaskResult {
  /// Task finished — remove it and move on.
  done,

  /// Transient failure (no network, 5xx) — keep the task and STOP the
  /// flush: later tasks may depend on this one, order is the contract
  /// (a report must land before its media attaches).
  retry,

  /// Permanent failure — remove the task without running it again. The
  /// handler is responsible for logging/surfacing what was lost.
  drop,
}

typedef QueueTaskHandler = Future<QueueTaskResult> Function(Map<String, dynamic> payload);

/// Offline write queue (decision 28, spec task 16): pending writes survive
/// restarts and are dispatched in order once connectivity returns.
///
/// The queue is generic — feature modules `register` a handler per task
/// kind and `enqueue` payloads; nothing here knows what a report is.
/// Idempotency is the payload's job (decision 137: the `clientKey` travels
/// IN the payload, so a replayed dispatch is answered 200 by the API and
/// treated as success by the handler).
///
/// "Connectivity detected" is implemented as flush-on-boot plus a periodic
/// retry while anything is pending — a timer is dependency-free and
/// self-heals cases a connectivity plugin misses (captive portals, API
/// down while the radio is up).
class OfflineQueueService {
  OfflineQueueService({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  static const _storageKey = 'offline_queue_v1';

  final SharedPreferences? _injectedPrefs;
  final Map<String, QueueTaskHandler> _handlers = {};
  final List<Map<String, dynamic>> _tasks = [];

  /// Observable pending count — the form page renders its "queued" banner
  /// from this without polling.
  final ValueNotifier<int> pending = ValueNotifier<int>(0);

  bool _loaded = false;
  bool _flushing = false;
  Timer? _autoFlushTimer;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  /// Registers the dispatcher for a task kind. A kind with no handler is
  /// left untouched in the queue (never dropped — code that forgot to
  /// register must not destroy pending writes).
  void register(String kind, QueueTaskHandler handler) => _handlers[kind] = handler;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = (await _prefs).getString(_storageKey);
    if (raw != null) {
      _tasks.addAll(
        (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>(),
      );
    }
    _loaded = true;
    pending.value = _tasks.length;
  }

  Future<void> _persist() async {
    await (await _prefs).setString(_storageKey, jsonEncode(_tasks));
    pending.value = _tasks.length;
  }

  Future<void> enqueue(String kind, Map<String, dynamic> payload) async {
    await _ensureLoaded();
    _tasks.add({'kind': kind, 'payload': payload});
    await _persist();
  }

  Future<int> pendingCount() async {
    await _ensureLoaded();
    return _tasks.length;
  }

  /// Dispatches queued tasks strictly in order. Stops at the first
  /// [QueueTaskResult.retry] so a dependent task never runs before its
  /// predecessor. Handlers may [enqueue] follow-up tasks mid-flush (the
  /// upload→attach chain does); they are picked up in the same pass.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _ensureLoaded();
      while (_tasks.isNotEmpty) {
        final task = _tasks.first;
        final handler = _handlers[task['kind'] as String];
        if (handler == null) return; // preserve unknown kinds, stop in order

        final QueueTaskResult result;
        try {
          result = await handler((task['payload'] as Map).cast<String, dynamic>());
        } catch (_) {
          return; // an unexpected throw is a retry: keep the task, stop
        }

        if (result == QueueTaskResult.retry) return;
        // done and drop both remove the head. The handler may have
        // enqueued follow-ups meanwhile, so remove by identity, not index.
        _tasks.remove(task);
        await _persist();
      }
    } finally {
      _flushing = false;
    }
  }

  /// Retries pending tasks every [interval] until [dispose]. Idempotent.
  void startAutoFlush({Duration interval = const Duration(seconds: 30)}) {
    _autoFlushTimer ??= Timer.periodic(interval, (_) => flush());
  }

  void dispose() {
    _autoFlushTimer?.cancel();
    _autoFlushTimer = null;
    pending.dispose();
  }
}
