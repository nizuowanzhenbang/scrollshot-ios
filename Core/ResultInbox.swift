import Foundation
public enum SessionDestination: Identifiable {
    case editor(SessionManifest),result(SessionManifest)
    public var session: SessionManifest {switch self {case .editor(let s),.result(let s):return s}}
    public var id: String {switch self {case .editor(let s):return "editor-"+s.id.uuidString;case .result(let s):return "result-"+s.id.uuidString}}
}
public enum ResultInbox {
    public static func next(in sessions: [SessionManifest],after date: Date) -> SessionManifest? {
        guard let newest = sessions.max(by: {a,b in a.createdAt == b.createdAt ? a.id.uuidString < b.id.uuidString : a.createdAt < b.createdAt}),
              newest.createdAt > date,newest.state == .ready,!newest.frames.isEmpty else {return nil}
        return newest
    }
}
