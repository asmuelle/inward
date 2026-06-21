# Design — Entry maintenance & on-device insights

_Status: proposal · no code yet_

Two related capabilities:

1. **Entry maintenance** — delete, post-hoc edit, and categorize (tags) kept entries.
2. **On-device insights** — use Apple's FoundationModels (with a deterministic
   fallback) to extract people / places / objects / topics from entries, classify
   them into tags, and surface a cross-journal **mind map**.

Both extend the existing grain rather than introduce a new architecture.

---

## Invariants this must honor

These already hold in the codebase and must continue to:

- **#2 — no egress.** Everything stays on device. FoundationModels and
  `NaturalLanguage` are on-device; the `NoEgress` test harness must still pass.
- **#4 — encrypted at rest.** New tables live in the same SQLCipher database.
- **#8 — reading/export never paywalled.** Maintenance (delete/edit) and viewing
  insights are free; only *new authored content* is gated by the trial.
- **#9 — model-optional.** Every AI feature degrades to a deterministic path when
  Apple Intelligence is unavailable. Extraction falls back to `NLTagger` NER.
- **Verified, not fabricated.** Like the weekly review's verified citations, any
  entity surfaced must actually occur in the user's own text.

---

## Part 1 — Entry maintenance

### 1A. Delete

**Store.** Add to `JournalStoring`:

```swift
func delete(entryID: UUID) async throws
```

- SQLCipher: `try EntryRecord.deleteOne(db, key: id.uuidString)`. The
  `transcription` table already declares `onDelete: .cascade`
  (`Records.swift`), so its row is removed automatically; the new `entry_entity`
  rows (Part 2) get the same cascade. The method also deletes the backing audio
  file at `audioFileRef` from disk if present.
- `EncryptedFileJournalStore`: filter the entry out and re-seal.
- **Hard delete, no tombstone** — consistent with "we can't recover it". (If
  cross-device sync lands later, deletes propagate as explicit tombstones in the
  sync module only, never in the local store.)

**UI.**
- Long-press **context menu** on `TimelineRow` → Delete.
- Delete action in `EntryDetailView`.
- Destructive **confirmation dialog**, then a ~5s **"Deleted · Undo" snackbar**:
  snapshot the `Entry` + `Transcription`, re-`save` on undo (the store inserts, so
  undo is a re-insert). All on-device; gone for good once it dismisses.

**Tests.** delete removes the entry and cascades its transcription; deleting a
missing id throws `entryNotFound`; file-store parity.

### 1B. Edit

Already present: `updateEditedText(entryID:textEdited:)` and
`Entry.withEditedText`, with `transcriptRaw` kept as immutable provenance
(**preserve this** — edits never touch the raw transcript). Missing piece is
post-hoc editing from the timeline.

- `EntryDetailView` gains an **Edit** mode reusing the `TranscriptEditorView`
  shape → `updateEditedText` → `summary` recomputes via `EntrySummary.make`.
- Allow editing `mood`.
- **Migration `v3`**: add `updatedAt` (also needed by the future sync design as
  the last-writer-wins field) and surface a subtle "edited" marker.
- On edit: re-index in `RecallKit` and re-extract insights (Part 2).

### 1C. Categorize (tags)

**Recommendation:** free-form **tags** plus **AI-suggested** tags the user confirms
(Part 2), not a rigid taxonomy. "Categories" are just higher-level theme-tags.

**Schema (migration `v4`)** — many-to-many, queryable:

```
tag(id TEXT PK, name TEXT UNIQUE, createdAt DATETIME)
entry_tag(entryId TEXT, tagId TEXT, PRIMARY KEY(entryId, tagId),
          FK entryId -> entry(id) ON DELETE CASCADE,
          FK tagId   -> tag(id)   ON DELETE CASCADE)
```

**Store methods** (kept off the hot `Entry` value type; fetched on demand):

```swift
func tags(for entryID: UUID) async throws -> [Tag]
func setTags(_ tags: [String], for entryID: UUID) async throws
func allTags() async throws -> [Tag]
func entries(withTag tag: String) async throws -> [Entry]
```

**UI.** tag chips on `EntryDetailView`, a tag editor (add/remove), and a **filter**
on the timeline (filter by tag). AI-suggested tags appear as confirmable chips.

---

## Part 2 — On-device insights (FoundationModels)

New module **`InsightKit`**, mirroring `ReflectKit`'s separation: it depends on
`SafetyKit` (normalizer / crisis vocabulary), **not** on `JournalStore`. The app
maps an `Entry` down to a small value type so the AI layer can never touch raw
storage — exactly how `ReviewableEntry` shields the review layer.

### 2A. Extraction

**Structured output** via `@Generable` (same idiom as `GeneratedWeeklyReview`):

```swift
@Generable struct EntryInsights {
    var people:      [String]   // @Guide: names of people mentioned
    var places:      [String]   // @Guide: locations mentioned
    var objects:     [String]   // @Guide: concrete things mentioned
    var topics:      [String]   // @Guide: short lowercase themes
    var events:      [GeneratedEvent]   // date + short description
    var sentiment:   String     // one calm word
    var actionItems: [String]
}
```

**Provider protocol** + two implementations (`availability()` gate like the
review provider):

```swift
public protocol EntityExtracting: Sendable {
    func availability() async -> InsightAvailability
    func extract(from entry: ExtractableEntry) async throws -> EntryInsights
}
```

- **`FoundationModelsEntityExtractor`** — `LanguageModelSession` + guided
  generation (Apple Intelligence).
- **`NaturalLanguageEntityExtractor`** — deterministic floor using `NLTagger`
  with `.nameType` (`personalName` / `placeName` / `organizationName`). Works with
  no model present (**invariant #9**); the model only adds objects, topics,
  events, sentiment.

**Verified, not fabricated.** Persist only entities whose normalized form
actually occurs in the entry text (`SafetyKit.TextNormalizer`). Fabricated names
can never reach a surface — the same trust contract as verified citations.

**When.** Extract at **save time** (precompute like `EntrySummary`), persist to
encrypted tables, re-extract on edit, and backfill existing entries in the
**background at low priority, throttled** (a few at a time) so the app stays
responsive. Reuse the existing `TokenBudgeter` to stay under the context window.

**Schema (migration `v5`)**:

```
entity(id TEXT PK, kind TEXT, name TEXT, normalized TEXT, UNIQUE(kind, normalized))
entry_entity(entryId TEXT, entityId TEXT, PRIMARY KEY(entryId, entityId),
             FK entryId  -> entry(id)   ON DELETE CASCADE,
             FK entityId -> entity(id)  ON DELETE CASCADE)
```

### 2B. Classify → tags

Auto-suggest tags from extracted `topics`, surfaced as confirmable chips in the
tag editor — closing the loop with Part 1C. A topic the user accepts becomes a
tag; declined suggestions are remembered so they aren't re-offered.

### 2C. Mind map

Built by **aggregating the stored entity tables** — no re-running the model:

- **Nodes** = entities, weighted by mention count.
- **Edges** = co-occurrence within the same entry, weighted by shared-entry count.
- New `EntityGraph` value type + a pure builder in `InsightKit` (deterministic,
  unit-testable).
- Every node and edge **links back to its entries** (tap a node → filtered
  timeline; tap an edge → entries where both appear) — points back at the user's
  own words, like citations.

**UI.** A new top-level **Mind Map** surface (alongside Weekly Review): SwiftUI
`Canvas` with a calm **radial-cluster** layout grouped by entity kind (people /
places / topics), capped to top-N nodes by mention, filterable by kind, with a
**Reduce-Motion** static-layout fallback.

---

## Migrations summary

| Version | Adds |
|--------:|------|
| `v3` | `entry.updatedAt` |
| `v4` | `tag`, `entry_tag` |
| `v5` | `entity`, `entry_entity` |

All registered on `JournalSchema.migrator` (additive, backward-compatible). The
`EncryptedFileJournalStore` fallback already tolerates new optional `Entry` fields
via `decodeIfPresent`; tags/entities are SQLCipher-only and simply absent in the
fallback (graceful degradation).

## Module / file map

- `JournalStore` / `JournalStoreSQLCipher` — `delete`, tag + entity storage,
  `updatedAt`, migrations `v3`–`v5`.
- **`InsightKit`** (new SPM target) — `EntityExtracting`, `EntryInsights`,
  `FoundationModelsEntityExtractor`, `NaturalLanguageEntityExtractor`,
  `EntityGraph` + builder. Depends on `SafetyKit`.
- App — `EntryDetailView` (edit/delete/tags), timeline filter + context menu,
  `MindMapView`, tag editor, suggested-tag chips.

## Test plan

- Store: delete + cascade, tag CRUD, entity persistence, `updatedAt` on edit.
- `NaturalLanguageEntityExtractor`: deterministic NER on fixtures (no model).
- Extraction verification: fabricated entity (not in text) is dropped.
- `EntityGraph` builder: pure, deterministic node/edge aggregation.
- Mock `EntityExtracting` for app-level flows; visual checks for the mind map.

## Sequencing

1. **Maintenance core** — delete + post-hoc edit + `updatedAt`. No AI.
2. **Manual tags** + timeline filter.
3. **InsightKit extraction** — NLTagger floor + FoundationModels, verified,
   persisted at save.
4. **Auto-suggested tags** (ties 2 + 3).
5. **Mind-map view.**

Each phase is independently shippable and testable.

## Decisions (resolved)

- **Delete UX** — destructive confirmation **plus a ~5s "Deleted · Undo" snackbar**
  (undo re-inserts, on-device). Forgiving against accidental taps.
- **Tag model** — **free-form tags + AI-suggested** (from extracted topics, as
  confirmable chips). No curated/prescribed labels — stays on-brand.
- **Mind-map layout** — **radial clusters** grouped by entity kind (calm, cheaper,
  Reduce-Motion-friendly), not a force-directed graph.
- **Backfill** — **background, throttled, low-priority** after launch (a few
  entries at a time); the app stays responsive and the map fills in over a
  session or two. New entries extract at save.
