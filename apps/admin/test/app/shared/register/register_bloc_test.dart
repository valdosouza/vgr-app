import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/shared/register/register_bloc.dart';

class Item extends Equatable {
  const Item(this.id, this.name);

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

class Draft extends Equatable {
  const Draft(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

class MockRepository extends Mock implements RegisterRepository<Item, Draft> {}

typedef ItemBloc = RegisterBloc<Item, Draft>;

/// The register factory's bloc (decision 217): list ↔ form by STATE, the
/// query remembered across both, one-shot signals always followed by a
/// view.
void main() {
  late MockRepository repository;

  const a = Item(1, 'A');
  const b = Item(2, 'B');
  const failure = Failure(message: 'in use', statusCode: 409, code: 'IN_USE');

  PagedResult<Item> pageOf(List<Item> items, {int page = 1, int pageSize = 20, int? total}) =>
      PagedResult(items: items, page: page, pageSize: pageSize, total: total ?? items.length);

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(const Draft(''));
    registerFallbackValue(a);
  });

  setUp(() {
    repository = MockRepository();
    when(() => repository.list(any())).thenAnswer((_) async => Right(pageOf(const [a, b])));
  });

  Future<ItemBloc> loaded() async {
    final bloc = ItemBloc(repository)..add(const RegisterListRequested());
    await bloc.stream.firstWhere((state) => state is RegisterListLoaded<Item>);
    return bloc;
  }

  group('list', () {
    test('starts loading on the default query and lands on the page', () async {
      final bloc = ItemBloc(repository);
      expect(bloc.state, const RegisterListLoading<Item>(PagedQuery()));

      bloc.add(const RegisterListRequested());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterListLoading<Item>(PagedQuery()),
          RegisterListLoaded<Item>(const PagedQuery(), pageOf(const [a, b])),
        ]),
      );
      await bloc.close();
    });

    test('a failure is a view the screen can retry from', () async {
      when(() => repository.list(any())).thenAnswer((_) async => const Left(failure));
      final bloc = ItemBloc(repository)..add(const RegisterListRequested());

      await expectLater(
        bloc.stream,
        emitsThrough(const RegisterListError<Item>(PagedQuery(), failure)),
      );
      await bloc.close();
    });

    test('a new filter or page size goes back to page 1; a page keeps filter and size', () async {
      final bloc = await loaded();

      bloc.add(const RegisterListRequested(page: 3));
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<Item>);
      bloc.add(const RegisterListRequested(filter: 'ana'));
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<Item>);
      bloc.add(const RegisterListRequested(page: 2));
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<Item>);
      bloc.add(const RegisterListRequested(pageSize: 50));
      await bloc.stream.firstWhere((s) => s is RegisterListLoaded<Item>);

      final queries = verify(() => repository.list(captureAny())).captured.cast<PagedQuery>();
      expect(queries, const [
        PagedQuery(),
        PagedQuery(page: 3),
        PagedQuery(filter: 'ana'),
        PagedQuery(page: 2, filter: 'ana'),
        PagedQuery(pageSize: 50, filter: 'ana'),
      ]);
      await bloc.close();
    });

    test('past the last page (its last row just went away) it lands on the real last page', () async {
      when(() => repository.list(const PagedQuery(page: 3)))
          .thenAnswer((_) async => Right(pageOf(const [], page: 3, total: 40)));
      when(() => repository.list(const PagedQuery(page: 2)))
          .thenAnswer((_) async => Right(pageOf(const [b], page: 2, total: 40)));
      final bloc = await loaded();

      bloc.add(const RegisterListRequested(page: 3));
      await expectLater(
        bloc.stream,
        emitsThrough(RegisterListLoaded<Item>(const PagedQuery(page: 2), pageOf(const [b], page: 2, total: 40))),
      );
      await bloc.close();
    });
  });

  group('list ↔ form', () {
    test('new and edit open the form; back returns the same list without a refetch', () async {
      final bloc = await loaded();
      final listState = bloc.state;

      bloc.add(const RegisterNewPressed());
      await expectLater(bloc.stream, emits(const RegisterFormState<Item>(null)));
      bloc.add(const RegisterBackToListPressed());
      await expectLater(bloc.stream, emits(listState));

      bloc.add(const RegisterEditPressed(a));
      await expectLater(bloc.stream, emits(const RegisterFormState<Item>(a)));
      bloc.add(const RegisterBackToListPressed());
      await expectLater(bloc.stream, emits(listState));

      verify(() => repository.list(any())).called(1);
      await bloc.close();
    });
  });

  group('save', () {
    test('a new record is created, signalled and the list refreshed', () async {
      when(() => repository.create(const Draft('C'))).thenAnswer((_) async => const Right(Item(3, 'C')));
      final bloc = await loaded();
      bloc.add(const RegisterNewPressed());
      await bloc.stream.first;

      bloc.add(const RegisterSaveRequested(Draft('C')));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterFormState<Item>(null, busy: true),
          const RegisterActionSuccess<Item>('register.saved'),
          const RegisterListLoading<Item>(PagedQuery()),
          isA<RegisterListLoaded<Item>>(),
        ]),
      );
      verify(() => repository.create(const Draft('C'))).called(1);
      await bloc.close();
    });

    test('an edited record is updated with the row it was opened on', () async {
      when(() => repository.update(a, const Draft('A2'))).thenAnswer((_) async => const Right(Item(1, 'A2')));
      final bloc = await loaded();
      bloc.add(const RegisterEditPressed(a));
      await bloc.stream.first;

      bloc.add(const RegisterSaveRequested(Draft('A2')));
      await expectLater(bloc.stream, emitsThrough(const RegisterActionSuccess<Item>('register.saved')));
      verify(() => repository.update(a, const Draft('A2'))).called(1);
      verifyNever(() => repository.create(any()));
      await bloc.close();
    });

    test('a failure is signalled and the form comes back usable, nothing refetched', () async {
      when(() => repository.update(any(), any())).thenAnswer((_) async => const Left(failure));
      final bloc = await loaded();
      bloc.add(const RegisterEditPressed(a));
      await bloc.stream.first;

      bloc.add(const RegisterSaveRequested(Draft('A2')));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterFormState<Item>(a, busy: true),
          const RegisterActionFailure<Item>(failure),
          const RegisterFormState<Item>(a),
        ]),
      );
      verify(() => repository.list(any())).called(1);
      await bloc.close();
    });
  });

  group('delete', () {
    test('from the form: busy, signalled, list refreshed', () async {
      when(() => repository.delete(a)).thenAnswer((_) async => const Right(unit));
      final bloc = await loaded();
      bloc.add(const RegisterEditPressed(a));
      await bloc.stream.first;

      bloc.add(const RegisterDeleteRequested(a));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterFormState<Item>(a, busy: true),
          const RegisterActionSuccess<Item>('register.deleted'),
          const RegisterListLoading<Item>(PagedQuery()),
          isA<RegisterListLoaded<Item>>(),
        ]),
      );
      await bloc.close();
    });

    test('a refusal (IN_USE, SELF_LOCKOUT) is signalled and the form stays', () async {
      when(() => repository.delete(a)).thenAnswer((_) async => const Left(failure));
      final bloc = await loaded();
      bloc.add(const RegisterEditPressed(a));
      await bloc.stream.first;

      bloc.add(const RegisterDeleteRequested(a));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          const RegisterFormState<Item>(a, busy: true),
          const RegisterActionFailure<Item>(failure),
          const RegisterFormState<Item>(a),
        ]),
      );
      await bloc.close();
    });
  });
}
