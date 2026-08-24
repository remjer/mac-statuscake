import Foundation

/// A loosely-typed JSON value, used to decode StatusCake API responses the way
/// `normalizeCheck` in the reference implementation reads them: tolerantly,
/// because the API's own JSON typing is not something this client controls
/// (an id can arrive as a number or a string; a status can arrive absent).
enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    /// `String(x)` for a JS primitive: numbers lose a trailing `.0` the way
    /// `String(123)` does in JavaScript, so an integer id round-trips cleanly.
    var looseString: String? {
        switch self {
        case .string(let s): return s
        case .number(let n):
            if n.truncatingRemainder(dividingBy: 1) == 0, abs(n) < 1e15 {
                return String(Int64(n))
            }
            return String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null, .array, .object: return nil
        }
    }

    /// `parseFloat(String(x))` for the one field (`uptime`) that needs a
    /// number back rather than a display string.
    var looseDouble: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    /// `raw.x === true`, not merely truthy: used for `paused`, where anything
    /// short of a literal `true` must read as not-paused.
    var isTrue: Bool {
        if case .bool(true) = self { return true }
        return false
    }

    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
}
