/// Moderation reason catalog (decision 163) — fixed in CODE, canonical
/// English codes. Mirrors `MODERATION_REASONS` in
/// `api/src/shared/moderation/moderation-reason.ts`; the API is the
/// authority and rejects anything else with `INVALID_OPTION` (83).
///
/// `other` is the one code that REQUIRES a free-text note (3–500 chars);
/// for every other code the note is optional. The screen builds its
/// validator list from this rule (`ModerationReasonForm`).
const moderationReasons = <String>[
  'spam',
  'abuse',
  'illegal_content',
  'duplicate',
  'personal_data',
  'other',
];

/// The code whose note is mandatory (163).
const moderationReasonOther = 'other';

/// `moderationReasonDto.note: z.string().max(500)`.
const moderationNoteMaxLength = 500;

/// `refine`: when `reasonCode === 'other'` the note is required and ≥ 3.
const moderationNoteMinLengthWhenOther = 3;
