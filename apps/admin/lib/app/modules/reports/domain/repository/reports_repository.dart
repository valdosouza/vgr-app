import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/report_entities.dart';

/// Contract of the panel report front, phase B1 (decisions 158–167):
/// search, detail, the audited exact position, and the freeze calls the
/// detail EMBEDS (165 — `/api/case-freeze` is reused, never redesigned).
/// Every mutation answers nothing: the bloc re-fetches, so the screen only
/// ever renders what the SERVER says the case is.
abstract class ReportsRepository {
  Future<Either<Failure, ReportPageEntity>> search(
    ReportFiltersEntity filters,
    int page,
    int pageSize,
  );

  /// Audited server-side per call (decision 166).
  Future<Either<Failure, ReportPanelDetailEntity>> getDetail(int reportId);

  /// Needs the `report_exact_position` grant; audited per call (159).
  Future<Either<Failure, ReportExactPositionEntity>> getExactPosition(int reportId);

  Future<Either<Failure, ReportFreezeStateEntity>> getFreezeState(int reportId);
  Future<Either<Failure, void>> freeze(int reportId, String reason);
  Future<Either<Failure, void>> requestUnfreeze(int reportId, String reason);
  Future<Either<Failure, void>> approveUnfreeze(int reportId);

  // Moderation (B2, decisions 162/163/165/167). Each call is ONE human
  // with the `reports` UPDATE grant, a catalog [reasonCode] and an
  // optional [note] (mandatory when `other`) — the API audits every one,
  // reverting included. Nothing here touches retention.
  Future<Either<Failure, void>> hide(int reportId, String reasonCode, String? note);
  Future<Either<Failure, void>> unhide(int reportId, String reasonCode, String? note);
  Future<Either<Failure, void>> blockMedia(String publicId, String reasonCode, String? note);
  Future<Either<Failure, void>> unblockMedia(String publicId, String reasonCode, String? note);
}
