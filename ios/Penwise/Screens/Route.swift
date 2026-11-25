/// Places the app can navigate to.
enum Route: Hashable {
    /// The screen between Home and a mode's letters (holds the second ad).
    case modeEntry(WritingMode)
    case letters(WritingMode)
    case write(WritingMode, String)
    case recorder
}
