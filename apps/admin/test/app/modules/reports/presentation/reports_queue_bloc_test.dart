import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/repository/reports_repository.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_queue_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_queue_event.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_queue_state.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

QueueItemEntity item(int id) => QueueItemEntity(
      item: ReportListItemEntity(
        reportId: id,
        category: 'assault',
        freeTag: null,
        subject: 'child',
        tier: 'high',
        status: 'open',
        anonymous: true,
        frozen: false,
        purged: false,
        mediaCount: 1,
        position: null,
        createdAt: '2026-09-01T10:00:00.000Z',
        resolvedAt: null,
      ),
      priority: 'high',
      hasMedia: true,
      ageHours: 12,
    );

final _pageOne = QueuePageEntity(items: [item(7), item(8)], page: 1, pageSize: 20, total: 45);
final _pageTwo = QueuePageEntity(items: [item(9)], page: 2, pageSize: 20, total: 45);
final _pageOneAfter = QueuePageEntity(items: [item(8)], page: 1, pageSize: 20, total: 44);

/// B3 (decision 161): the proactive queue. Reading it is a list read (not
/// audited, 166); marking reviewed is ONE human with `reports` UPDATE,
/// audited server-side, after which the queue is RE-FETCHED — the server
/// alone decides what is still pending.
void main() {
  late MockReportsRepository repository;

  setUp(() => repository = MockReportsRepository());

  ReportsQueueBloc build() => ReportsQueueBloc(repository);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts idle; a load fetches page 1 and emits the queue', () async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => Right(_pageOne));

    final bloc = build();
    expect(bloc.state, const ReportsQueueInitial());

    bloc.add(const ReportsQueueRequested());
    await settle();

    expect(bloc.state, ReportsQueueLoaded(_pageOne));
  });

  test('page navigation asks the requested page', () async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => Right(_pageOne));
    when(() => repository.queue(2, 20)).thenAnswer((_) async => Right(_pageTwo));
    final bloc = build()..add(const ReportsQueueRequested());
    await settle();

    bloc.add(const ReportsQueuePageRequested(2));
    await settle();

    expect(bloc.state, ReportsQueueLoaded(_pageTwo));
  });

  test('a failed load (no grant, network) is an error state', () async {
    const failure = Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN');
    when(() => repository.queue(1, 20)).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const ReportsQueueRequested());
    await settle();

    expect(bloc.state, const ReportsQueueError(failure));
  });

  test('mark reviewed posts and RE-FETCHES the same page (the case leaves the queue '
      'only because the server says so)', () async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => Right(_pageOne));
    final bloc = build()..add(const ReportsQueueRequested());
    await settle();

    when(() => repository.markReviewed(7)).thenAnswer((_) async => const Right(null));
    when(() => repository.queue(1, 20)).thenAnswer((_) async => Right(_pageOneAfter));

    bloc.add(const ReportsQueueMarkReviewed(7));
    await settle();

    expect(bloc.state, ReportsQueueLoaded(_pageOneAfter));
    verify(() => repository.markReviewed(7)).called(1);
    verify(() => repository.queue(1, 20)).called(2);
  });

  test('a refused mark (409 DUPLICATE — already reviewed) keeps the queue with the failure',
      () async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => Right(_pageOne));
    final bloc = build()..add(const ReportsQueueRequested());
    await settle();

    const failure = Failure(message: 'already', statusCode: 409, code: 'DUPLICATE');
    when(() => repository.markReviewed(7)).thenAnswer((_) async => const Left(failure));

    bloc.add(const ReportsQueueMarkReviewed(7));
    await settle();

    expect(bloc.state, ReportsQueueLoaded(_pageOne, failure: failure));
    verify(() => repository.queue(1, 20)).called(1);
  });

  test('a mark before any load is a no-op', () async {
    final bloc = build()..add(const ReportsQueueMarkReviewed(7));
    await settle();

    expect(bloc.state, const ReportsQueueInitial());
    verifyNever(() => repository.markReviewed(any()));
  });
}
