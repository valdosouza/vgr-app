import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/feed_item_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/list_nearby_reports_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/nearby_feed_bloc.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/nearby_feed_event.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/nearby_feed_state.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockLocationGateway extends Mock implements LocationGateway {}

FeedItemEntity _item(int id) => FeedItemEntity(
      reportId: id,
      category: 'missing',
      subject: 'child',
      tier: 'medium',
      position: const GeoPoint(lat: -23.5, lng: -46.6),
      distanceKm: 1.5,
      createdAt: '2026-08-04T18:15:00.000Z',
    );

FeedPageEntity _page(List<int> ids, {int page = 1, bool hasMore = false}) =>
    FeedPageEntity(
      items: ids.map(_item).toList(),
      page: page,
      hasMore: hasMore,
      order: FeedOrder.recency,
    );

void main() {
  late MockReportRepository repository;
  late MockLocationGateway location;

  setUpAll(() {
    registerFallbackValue(const GeoPoint(lat: 0, lng: 0));
    registerFallbackValue(FeedOrder.recency);
  });

  setUp(() {
    repository = MockReportRepository();
    location = MockLocationGateway();
    when(() => location.currentPosition()).thenAnswer(
        (_) async => const Right(GeoPoint(lat: -23.5, lng: -46.6)));
  });

  NearbyFeedBloc build() =>
      NearbyFeedBloc(ListNearbyReportsUsecase(repository), location);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('emits Loading then Loaded with the first page', () async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(_page([1, 2], hasMore: true)));

    final bloc = build();
    final states = <NearbyFeedState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const FeedStarted());
    await settle();

    expect(states.first, isA<FeedLoading>());
    final loaded = states.last as FeedLoaded;
    expect(loaded.items.length, 2);
    expect(loaded.hasMore, isTrue);
    await sub.cancel();
  });

  test('zero results is Empty — its own state, not an error', () async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(_page([])));

    final bloc = build()..add(const FeedStarted());
    await settle();

    expect(bloc.state, isA<FeedEmpty>());
  });

  test('a denied position is a retryable Error', () async {
    when(() => location.currentPosition()).thenAnswer((_) async =>
        const Left(Failure(message: 'denied', code: 'LOCATION_DENIED')));

    final bloc = build()..add(const FeedStarted());
    await settle();

    expect((bloc.state as FeedError).failure.code, 'LOCATION_DENIED');

    when(() => location.currentPosition()).thenAnswer(
        (_) async => const Right(GeoPoint(lat: 1, lng: 2)));
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(_page([1])));
    bloc.add(const FeedStarted());
    await settle();

    expect(bloc.state, isA<FeedLoaded>());
  });

  test('next page appends WITHOUT duplicating entries (spec task 07)', () async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(_page([1, 2], hasMore: true)));
    // The feed moved under us: report 2 shows up again on page 2.
    when(() => repository.listNearby(any(), 2, FeedOrder.recency))
        .thenAnswer((_) async => Right(_page([2, 3], page: 2)));

    final bloc = build()..add(const FeedStarted());
    await settle();
    bloc.add(const FeedNextPageRequested());
    await settle();

    final loaded = bloc.state as FeedLoaded;
    expect(loaded.items.map((i) => i.reportId), [1, 2, 3]);
    expect(loaded.hasMore, isFalse);
  });

  test('a failed next page keeps the current items for a later retry', () async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(_page([1], hasMore: true)));
    when(() => repository.listNearby(any(), 2, FeedOrder.recency)).thenAnswer(
        (_) async => const Left(Failure(message: 'down', statusCode: 500)));

    final bloc = build()..add(const FeedStarted());
    await settle();
    bloc.add(const FeedNextPageRequested());
    await settle();

    final loaded = bloc.state as FeedLoaded;
    expect(loaded.items.single.reportId, 1);
    expect(loaded.loadingMore, isFalse);
    expect(loaded.hasMore, isTrue); // still retryable
  });

  test('changing the order reloads from page 1', () async {
    when(() => repository.listNearby(any(), 1, any()))
        .thenAnswer((_) async => Right(_page([1])));

    final bloc = build()..add(const FeedStarted());
    await settle();
    bloc.add(const FeedOrderChanged(FeedOrder.relevance));
    await settle();

    verify(() => repository.listNearby(any(), 1, FeedOrder.relevance)).called(1);
  });
}
