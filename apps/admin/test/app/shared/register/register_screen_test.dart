import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/shared/feedback/feedback.dart';
import 'package:vgr_admin/app/shared/register/register_bloc.dart';
import 'package:vgr_admin/app/shared/register/register_field.dart';
import 'package:vgr_admin/app/shared/register/register_screen.dart';
import 'package:vgr_admin/app/shared/register/register_search_page.dart';
import 'package:vgr_admin/app/shared/session/current_interface.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../helpers/pump_localized.dart';

class Item extends Equatable {
  const Item(this.id, this.name, {this.code = ''});

  final int id;
  final String name;
  final String code;

  @override
  List<Object?> get props => [id, name, code];
}

class Draft extends Equatable {
  const Draft(this.name, this.code, this.active);

  final String name;
  final String code;
  final bool active;

  @override
  List<Object?> get props => [name, code, active];
}

class MockRepository extends Mock implements RegisterRepository<Item, Draft> {}

/// The register factory end to end on a throwaway entity: list, filter,
/// pager, form, one-pendency validation, server field anchoring, delete
/// by askDecision, privileges (PS2 — decisions 217/220/221).
void main() {
  late MockRepository repository;

  const a = Item(1, 'Alpha', code: 'AL');
  const b = Item(2, 'Beta', code: 'BE');
  const screen = CurrentInterface('items');

  PagedResult<Item> pageOf(List<Item> items, {int page = 1, int total = 2}) =>
      PagedResult(items: items, page: page, pageSize: 20, total: total);

  setUpAll(() {
    registerFallbackValue(const PagedQuery());
    registerFallbackValue(const Draft('', '', true));
    registerFallbackValue(a);
  });

  setUp(() {
    repository = MockRepository();
    when(() => repository.list(any())).thenAnswer((_) async => Right(pageOf(const [a, b])));
    SessionAccess.instance.applyPermissions(const {
      'items': [Privileges.view, Privileges.insert, Privileges.update, Privileges.delete],
    });
  });

  tearDown(SessionAccess.instance.clear);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalized(
      tester,
      BlocProvider<RegisterBloc<Item, Draft>>(
        create: (_) => RegisterBloc<Item, Draft>(repository)..add(const RegisterListRequested()),
        child: RegisterScreen<Item, Draft>(
          title: 'Items',
          screen: screen,
          rowId: (item) => item.id,
          rowBuilder: (context, item) => RegisterRow(title: item.name, subtitle: item.code),
          formTitle: (current) => current == null ? 'New item' : 'Item ${current.name}',
          fields: (current) => [
            RegisterTextField(
              name: 'name',
              label: 'Name',
              initialValue: current?.name ?? '',
              validators: [VgrValidators.minLength(2)],
            ),
            RegisterTextField(
              name: 'code',
              label: 'Code',
              initialValue: current?.code ?? '',
              validators: [VgrValidators.upperSnakeCase],
            ),
            const RegisterFlagField(name: 'active', label: 'Active', initialValue: true),
          ],
          draftOf: (_, values) =>
              Draft(values.text('name').trim(), values.text('code').trim(), values.flag('active')),
        ),
      ),
    );
  }

  Finder field(String name) => find.byKey(Key('register-field-$name'));

  group('list', () {
    testWidgets('rows, the pager summary and the new button', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('vgr-page-title')), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.rowKey(1)), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Page 1 of 1 · 2 records'), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.newButtonKey), findsOneWidget);
    });

    testWidgets('the filter is sent on Enter and resets to page 1', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byKey(VgrSearchBar.fieldKey), 'alp');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(() => repository.list(const PagedQuery(filter: 'alp'))).called(1);
    });

    testWidgets('the pager asks for the next page', (tester) async {
      when(() => repository.list(any())).thenAnswer((_) async => Right(pageOf(const [a, b], total: 45)));
      await pumpScreen(tester);

      expect(find.text('Page 1 of 3 · 45 records'), findsOneWidget);
      await tester.tap(find.byKey(VgrPagingBar.nextKey));
      await tester.pumpAndSettle();

      verify(() => repository.list(const PagedQuery(page: 2))).called(1);
    });

    testWidgets('empty list: the empty state, filtered wording when a filter is on', (tester) async {
      when(() => repository.list(any())).thenAnswer((_) async => const Right(PagedResult.empty()));
      await pumpScreen(tester);
      expect(find.text('No records yet.'), findsOneWidget);
      expect(find.byKey(VgrPagingBar.summaryKey), findsNothing);

      await tester.enterText(find.byKey(VgrSearchBar.fieldKey), 'zzz');
      await tester.tap(find.byKey(VgrSearchBar.buttonKey));
      await tester.pumpAndSettle();
      expect(find.text('No records match the search.'), findsOneWidget);
    });

    testWidgets('a list failure shows the translated error and retries', (tester) async {
      var calls = 0;
      when(() => repository.list(any())).thenAnswer((_) async => ++calls == 1
          ? const Left(Failure(message: 'Forbidden', statusCode: 403, code: 'FORBIDDEN'))
          : Right(pageOf(const [a, b])));
      await pumpScreen(tester);

      expect(find.byKey(RegisterSearchPage.errorKey), findsOneWidget);
      await tester.tap(find.byKey(RegisterSearchPage.retryKey));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('without INSERT there is no new button', (tester) async {
      SessionAccess.instance.applyPermissions(const {'items': [Privileges.view]});
      await pumpScreen(tester);

      expect(find.byKey(RegisterSearchPage.newButtonKey), findsNothing);
    });
  });

  group('form', () {
    testWidgets('new → the form replaces the list on the same screen; back returns to it', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('New item'), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.rowKey(1)), findsNothing);
      expect(find.byKey(VgrFormShell.deleteKey), findsNothing);

      await tester.tap(find.byKey(VgrFormShell.backKey));
      await tester.pumpAndSettle();
      expect(find.byKey(RegisterSearchPage.rowKey(1)), findsOneWidget);
      verify(() => repository.list(any())).called(1);
    });

    testWidgets('validation reports ONE pendency: the first failing field, then focuses it', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();

      // Both fields are wrong; only the first is reported.
      await tester.enterText(field('code'), 'lower');
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('Name: Required field.'), findsOneWidget);
      expect(find.textContaining('Code:'), findsNothing);
      await tester.tap(find.byKey(feedbackCloseKey));
      await tester.pumpAndSettle();

      final name = tester.widget<VgrTextField>(field('name'));
      expect(name.focusNode!.hasFocus, isTrue);
      expect(name.errorText, 'Required field.');
      expect(tester.widget<VgrTextField>(field('code')).errorText, isNull);
      verifyNever(() => repository.create(any()));
    });

    testWidgets('Enter moves to the next field and submits from the last one', (tester) async {
      when(() => repository.create(any())).thenAnswer((_) async => const Right(Item(3, 'Gamma')));
      await pumpScreen(tester);
      await tester.tap(find.byKey(RegisterSearchPage.newButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(field('name'), 'Gamma');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<VgrTextField>(field('code')).focusNode!.hasFocus, isTrue);

      await tester.enterText(field('code'), 'GA');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      verify(() => repository.create(const Draft('Gamma', 'GA', true))).called(1);
      expect(find.text('Record saved.'), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.rowKey(1)), findsOneWidget);
    });

    testWidgets('a server field error lands on its field; the typed values stay', (tester) async {
      when(() => repository.update(any(), any())).thenAnswer((_) async => const Left(Failure(
            message: 'Validation failed',
            statusCode: 422,
            code: 'VALIDATION_FAILED',
            fields: [FieldFailure(field: 'code', message: 'Too long', code: 'TOO_LONG', params: {'max': '60'})],
          )));
      await pumpScreen(tester);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(1)));
      await tester.pumpAndSettle();

      await tester.enterText(field('name'), 'Alpha 2');
      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      expect(find.text('Code: Maximum of 60 characters.'), findsOneWidget);
      await tester.tap(find.byKey(feedbackCloseKey));
      await tester.pumpAndSettle();
      expect(tester.widget<VgrTextField>(field('code')).focusNode!.hasFocus, isTrue);
      expect(find.text('Alpha 2'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failure naming no form field falls back to the bridge by severity', (tester) async {
      when(() => repository.update(any(), any())).thenAnswer((_) async => const Left(
            Failure(message: 'Email already in use', statusCode: 409, code: 'DUPLICATE'),
          ));
      await pumpScreen(tester);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(VgrFormShell.saveKey));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Item Alpha'), findsOneWidget); // still on the form
    });

    testWidgets('delete asks first; "no" sends nothing, "yes" deletes and returns to the list',
        (tester) async {
      when(() => repository.delete(a)).thenAnswer((_) async => const Right(unit));
      await pumpScreen(tester);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(VgrFormShell.deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(decisionNoKey));
      await tester.pumpAndSettle();
      verifyNever(() => repository.delete(any()));

      await tester.tap(find.byKey(VgrFormShell.deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(decisionYesKey));
      await tester.pumpAndSettle();

      verify(() => repository.delete(a)).called(1);
      expect(find.text('Record deleted.'), findsOneWidget);
      expect(find.byKey(RegisterSearchPage.rowKey(2)), findsOneWidget);
    });

    testWidgets('without UPDATE / DELETE a row opens read-only: no save, no delete', (tester) async {
      SessionAccess.instance.applyPermissions(const {'items': [Privileges.view]});
      await pumpScreen(tester);
      await tester.tap(find.byKey(RegisterSearchPage.rowKey(1)));
      await tester.pumpAndSettle();

      expect(find.text('Item Alpha'), findsOneWidget);
      expect(find.byKey(VgrFormShell.saveKey), findsNothing);
      expect(find.byKey(VgrFormShell.deleteKey), findsNothing);
      expect(tester.widget<VgrTextField>(field('name')).readOnly, isTrue);
      expect(tester.widget<VgrSwitchTile>(field('active')).onChanged, isNull);
    });
  });
}
