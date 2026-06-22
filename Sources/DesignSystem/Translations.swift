import Foundation

/// Per-language translation tables for `Copy`, keyed by the Copy property name.
/// Machine-generated; flagged for native-speaker review before release. English
/// is the in-code default and intentionally absent here. The brand name
/// ("Inward") is never translated, so `appName`/`timelineTitle` are omitted.
///
/// Each language lives in its own `Translations+<Language>.swift` extension so no
/// single file grows unwieldy. Completeness across languages is enforced by
/// `LocalizationCompletenessTests`.
enum Translations {}
