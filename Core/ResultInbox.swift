import Foundation
public enum SessionDestination: Identifiable {
    case editor(SessionManifest),result(SessionManifest)
    public var id: UUID {switch self {case .editor(let s),.result(let s):return s.id}}
}
public enum ResultInbox {
    public static func next(in sessions: [SessionManifest],after date: Date) -> SessionManifest? {nil}
}
