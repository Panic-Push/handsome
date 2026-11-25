/// Places the app can navigate to.
enum Route: Hashable {
    case letters(WritingMode)
    case write(WritingMode, String)
    case recorder
}
