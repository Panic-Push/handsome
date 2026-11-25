/// Where a Home tap leads after the entry (ad) screen.
enum EntryTarget: Hashable {
    case mode(WritingMode)
    case journeyMap(String)
    case journeyResume(String)
}

/// Places the app can navigate to.
enum Route: Hashable {
    /// The screen between Home and a destination (holds the second ad).
    case entry(EntryTarget)
    case letters(WritingMode)
    case sentences(LetterStyle, WritingMode, String?)
    case write(WritingMode, String)
    case set(WritingMode, String, [String])
    case journeyMap(String)
    case lesson(LessonPosition, review: Bool)
    case recap(String)
    case recorder
}

extension EntryTarget {
    /// The screen this entry continues to.
    var destination: Route {
        switch self {
        case .mode(let mode):
            return .letters(mode)
        case .journeyMap(let id):
            return .journeyMap(id)
        case .journeyResume(let id):
            guard let journey = JourneyLibrary.shared.journey(id: id) else { return .journeyMap(id) }
            let store = JourneyStore.shared
            // A new journey opens the map; a returning learner resumes the saved step.
            return store.hasStarted(journey) ? .lesson(store.position(in: journey), review: false) : .journeyMap(id)
        }
    }
}
