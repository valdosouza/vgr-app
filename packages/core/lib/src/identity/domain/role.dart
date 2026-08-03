/// A user's capacity within a Report: anonymous, reporter, helper, or
/// police. Transition to [police] is rejected outright until the
/// validation workflow exists (deferred, decision 12).
///
/// [admin] is a platform-administrator role — it never participates in
/// AnonymityMode/Report flows, it only gates `apps/admin` routes.
enum Role { anonymous, reporter, helper, police, admin }
