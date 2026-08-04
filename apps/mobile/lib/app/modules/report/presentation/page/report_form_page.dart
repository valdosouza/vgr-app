import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/category_form_schema_entity.dart';
import '../../domain/entity/report_taxonomy.dart';
import '../bloc/report_form_bloc.dart';
import '../bloc/report_form_event.dart';
import '../bloc/report_form_state.dart';

/// Sentinel category value meaning "describe freely" (decision 9's free
/// tag — the XOR alternative to a catalog category).
const _freeTagOption = '_free_tag';

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key});

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  String? _category;
  String? _subject;
  bool _anonymous = true;
  final _freeTagController = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, bool> _boolValues = {};
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    context.read<ReportFormBloc>().add(const ReportFormStarted());
  }

  @override
  void dispose() {
    _freeTagController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String fieldName) =>
      _fieldControllers.putIfAbsent(fieldName, TextEditingController.new);

  List<CategoryFormField> _schemaFor(ReportFormState state) =>
      _category == null || _category == _freeTagOption
          ? const []
          : (state.forms[_category] ?? const []);

  /// Offline pre-validation from the cached catalog (decision 47) — the
  /// server stays the authority; this only saves a round trip.
  bool _validate(ReportFormState state) {
    final errors = <String, String>{};
    if (_category == _freeTagOption && _freeTagController.text.trim().isEmpty) {
      errors[_freeTagOption] = 'report.form.required'.tr();
    }
    for (final field in _schemaFor(state)) {
      if (field.type == 'boolean' || !field.required_) continue;
      if (_controllerFor(field.name).text.trim().isEmpty) {
        errors[field.name] = 'report.form.required'.tr();
      }
    }
    setState(() => _fieldErrors = errors);
    return errors.isEmpty;
  }

  Map<String, dynamic> _collectDetailFields(ReportFormState state) {
    final fields = <String, dynamic>{};
    for (final field in _schemaFor(state)) {
      if (field.type == 'boolean') {
        fields[field.name] = _boolValues[field.name] ?? false;
        continue;
      }
      final text = _controllerFor(field.name).text.trim();
      if (text.isEmpty) continue;
      fields[field.name] = field.type == 'number' ? (num.tryParse(text) ?? text) : text;
    }
    return fields;
  }

  void _submit(ReportFormState state) {
    if (_subject == null || _category == null || !_validate(state)) return;
    context.read<ReportFormBloc>().add(ReportSubmitPressed(
          category: _category == _freeTagOption ? null : _category,
          freeTag: _category == _freeTagOption ? _freeTagController.text.trim() : null,
          subject: _subject!,
          detailFields: _collectDetailFields(state),
          anonymous: _anonymous,
        ));
  }

  Future<void> _togglePhotoKeep(int index, bool currentlyKept) async {
    final bloc = context.read<ReportFormBloc>();
    if (currentlyKept) {
      // Turning the choice OFF needs no warning — discard is the default.
      bloc.add(ReportPhotoKeepOriginalChanged(index, keep: false));
      return;
    }
    // Decisions 130/139: warning text v1, reinforced in the anonymous flow.
    final message = _anonymous
        ? '${'report.exif.warning'.tr()}\n\n${'report.exif.anonymousWarning'.tr()}'
        : 'report.exif.warning'.tr();
    final keep = await showVgrConfirm(
      context,
      title: 'report.exif.title'.tr(),
      message: message,
      confirmLabel: 'report.exif.keep'.tr(),
      cancelLabel: 'report.exif.discard'.tr(),
      confirmKey: const Key('report-exif-keep-button'),
      cancelKey: const Key('report-exif-discard-button'),
    );
    if (keep) bloc.add(ReportPhotoKeepOriginalChanged(index, keep: true));
  }

  void _startNewReport() {
    setState(() {
      _category = null;
      _subject = null;
      _freeTagController.clear();
      for (final controller in _fieldControllers.values) {
        controller.clear();
      }
      _boolValues.clear();
      _fieldErrors = {};
    });
    context.read<ReportFormBloc>().add(const ReportFormReset());
  }

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityBloc>().state;
    final isAnonymousUser = identity.role == Role.anonymous;
    if (isAnonymousUser) _anonymous = true;

    return VgrScaffold(
      title: 'report.title'.tr(),
      body: BlocBuilder<ReportFormBloc, ReportFormState>(
        builder: (context, state) {
          final submitted = state.submitStatus == SubmitStatus.submittedOnline ||
              state.submitStatus == SubmitStatus.queuedOffline;
          if (submitted) return _SuccessView(state: state, onNewReport: _startNewReport);
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._taxonomyFields(state),
                ..._detailFields(state),
                const VgrGap.md(),
                _positionRow(state),
                const VgrGap.md(),
                ..._photoSection(state),
                if (!isAnonymousUser)
                  VgrSwitchTile(
                    key: const Key('report-anonymous-switch'),
                    label: 'report.anonymousChoice'.tr(),
                    value: _anonymous,
                    onChanged: (value) => setState(() => _anonymous = value),
                  )
                else
                  VgrText.caption('report.anonymousInfo'.tr()),
                const VgrGap.md(),
                if (state.submitStatus == SubmitStatus.failed && state.failure != null)
                  ..._failureSection(state.failure!),
                VgrPrimaryButton(
                  key: const Key('report-submit-button'),
                  label: 'report.submit'.tr(),
                  busy: state.submitStatus == SubmitStatus.submitting,
                  onPressed: state.canSubmit && _subject != null && _category != null
                      ? () => _submit(state)
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _taxonomyFields(ReportFormState state) => [
        // Two mandatory axes (decision 140): what happened...
        VgrDropdownField<String>(
          key: const Key('report-category-dropdown'),
          label: 'report.categoryLabel'.tr(),
          value: _category,
          options: [
            ...reportCategories
                .map((c) => VgrOption(value: c, label: 'report.category.$c'.tr())),
            VgrOption(value: _freeTagOption, label: 'report.category.freeTag'.tr()),
          ],
          onChanged: (value) => setState(() {
            _category = value;
            _fieldErrors = {};
          }),
        ),
        if (_category == _freeTagOption) ...[
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('report-freetag-field'),
            controller: _freeTagController,
            label: 'report.freeTagLabel'.tr(),
            maxLength: 50,
            errorText: _fieldErrors[_freeTagOption],
          ),
        ],
        const VgrGap.sm(),
        // ...and to whom/what ("other" is the one-tap fallback, 140/123).
        VgrDropdownField<String>(
          key: const Key('report-subject-dropdown'),
          label: 'report.subjectLabel'.tr(),
          value: _subject,
          options: reportSubjects
              .map((s) => VgrOption(value: s, label: 'report.subject.$s'.tr()))
              .toList(),
          onChanged: (value) => setState(() => _subject = value),
        ),
      ];

  /// Detail fields rendered from the admin-configured schema (decision 47)
  /// — no per-category hardcoded widget (spec task 21).
  List<Widget> _detailFields(ReportFormState state) {
    final schema = _schemaFor(state);
    return [
      for (final field in schema) ...[
        const VgrGap.sm(),
        // The label is the admin-configured field name (decision 47) —
        // the schema carries no translations in the MVP.
        if (field.type == 'boolean')
          VgrCheckboxTile(
            key: Key('report-field-${field.name}'),
            label: field.name,
            value: _boolValues[field.name] ?? false,
            onChanged: (value) => setState(() => _boolValues[field.name] = value),
          )
        else
          VgrTextField(
            key: Key('report-field-${field.name}'),
            controller: _controllerFor(field.name),
            label: field.name,
            keyboard: field.type == 'number' ? VgrKeyboard.number : VgrKeyboard.text,
            helperText: field.type == 'date' ? 'report.form.dateHint'.tr() : null,
            errorText: _fieldErrors[field.name],
          ),
      ],
    ];
  }

  Widget _positionRow(ReportFormState state) => switch (state.positionStatus) {
        PositionStatus.locating => VgrRow(children: [
            const VgrInlineProgress(),
            const VgrGap.hSm(),
            VgrText('report.position.locating'.tr()),
          ]),
        PositionStatus.ready => VgrRow(children: [
            const VgrIcon(VgrIconName.location),
            const VgrGap.hSm(),
            VgrText('report.position.ready'.tr()),
          ]),
        PositionStatus.failed => VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrText.error(state.positionFailure == null
                  ? 'report.position.failed'.tr()
                  : failureText(state.positionFailure!)),
              VgrTextButton(
                key: const Key('report-position-retry'),
                label: 'report.position.retry'.tr(),
                onPressed: () => context
                    .read<ReportFormBloc>()
                    .add(const ReportPositionRetryRequested()),
              ),
            ],
          ),
      };

  List<Widget> _photoSection(ReportFormState state) {
    final atLimit = state.photos.length >= maxPhotosPerReport;
    return [
      VgrText.title('report.photos.title'.tr()),
      const VgrGap.sm(),
      if (state.photos.isNotEmpty) ...[
        VgrWrap(
          children: [
            for (var i = 0; i < state.photos.length; i++)
              VgrPhotoThumb(
                key: Key('report-photo-$i'),
                imagePath: state.photos[i].path,
                badgeText:
                    state.photos[i].keepOriginal ? 'report.exif.badge'.tr() : null,
                onTap: () => _togglePhotoKeep(i, state.photos[i].keepOriginal),
                onRemove: () =>
                    context.read<ReportFormBloc>().add(ReportPhotoRemoved(i)),
              ),
          ],
        ),
        const VgrGap.sm(),
      ],
      VgrRow(children: [
        VgrSecondaryButton(
          key: const Key('report-add-camera-button'),
          label: 'report.photos.camera'.tr(),
          onPressed: atLimit
              ? null
              : () => context
                  .read<ReportFormBloc>()
                  .add(const ReportPhotoPickRequested(fromCamera: true)),
        ),
        const VgrGap.hSm(),
        VgrSecondaryButton(
          key: const Key('report-add-gallery-button'),
          label: 'report.photos.gallery'.tr(),
          onPressed: atLimit
              ? null
              : () => context
                  .read<ReportFormBloc>()
                  .add(const ReportPhotoPickRequested(fromCamera: false)),
        ),
      ]),
      VgrText.caption('report.photos.hint'.tr()),
    ];
  }

  List<Widget> _failureSection(Failure failure) => [
        VgrText.error(failureText(failure), key: const Key('report-submit-error')),
        for (final field in failure.fields ?? const <FieldFailure>[])
          VgrText.error('${field.field}: ${fieldFailureText(field)}'),
        const VgrGap.sm(),
      ];
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.state, required this.onNewReport});

  final ReportFormState state;
  final VoidCallback onNewReport;

  @override
  Widget build(BuildContext context) {
    final queued = state.submitStatus == SubmitStatus.queuedOffline;
    return VgrCenter(
      child: VgrColumn(
        key: const Key('report-success-view'),
        children: [
          const VgrIcon(VgrIconName.check, size: 48),
          const VgrGap.md(),
          VgrText.headline('report.success.title'.tr()),
          const VgrGap.sm(),
          if (queued)
            // Queued is a promise, not an error (decisions 28/123): said
            // plainly, without a spinner pretending it is still trying.
            VgrCard(
              child: VgrPadding(
                child: VgrText(
                  'report.success.queuedBanner'.tr(),
                  key: const Key('report-queued-banner'),
                ),
              ),
            )
          else
            VgrText('report.success.sent'.tr()),
          const VgrGap.lg(),
          VgrPrimaryButton(
            key: const Key('report-new-report-button'),
            label: 'report.success.newReport'.tr(),
            onPressed: onNewReport,
          ),
        ],
      ),
    );
  }
}
