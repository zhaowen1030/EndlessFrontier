import Foundation
import AppKit
import SwiftUI

enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case orange

    var id: String { rawValue }

    var labelZH: String {
        switch self {
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        case .orange: return "橙色"
        }
    }

    var labelEN: String {
        switch self {
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .pink: return "Pink"
        case .orange: return "Orange"
        }
    }

    var systemColor: NSColor {
        switch self {
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .pink: return .systemPink
        case .orange: return .systemOrange
        }
    }

    var swatchColor: Color {
        Color(nsColor: systemColor)
    }

    func backgroundColor(isDark: Bool) -> NSColor {
        systemColor.withAlphaComponent(isDark ? 0.36 : 0.29)
    }
}

struct TextHighlight: Codable, Hashable {
    var location: Int
    var length: Int
    var color: HighlightColor

    var range: NSRange {
        NSRange(location: location, length: length)
    }
}

struct HighlightSelection: Equatable {
    let fieldID: String
    let range: NSRange
}

struct ReportAnnotationDocument: Codable {
    var categoryID: String
    var reportGeneratedAt: Date
    var highlights: [String: [TextHighlight]]
    var updatedAt: Date
}

enum HighlightRangeEditor {
    /// Apply a new highlight (or clear) to `range`, preserving the non-selected
    /// portions of existing highlights. Returned ranges are sorted and merged.
    static func apply(
        _ existing: [TextHighlight],
        range: NSRange,
        color: HighlightColor?
    ) -> [TextHighlight] {
        guard range.location >= 0, range.length > 0 else { return existing }
        var pieces: [TextHighlight] = []

        for highlight in existing {
            let current = highlight.range
            let intersection = NSIntersectionRange(current, range)
            if intersection.length == 0 {
                pieces.append(highlight)
                continue
            }
            if intersection.location > current.location {
                pieces.append(TextHighlight(
                    location: current.location,
                    length: intersection.location - current.location,
                    color: highlight.color
                ))
            }
            let rightStart = NSMaxRange(intersection)
            let currentEnd = NSMaxRange(current)
            if rightStart < currentEnd {
                pieces.append(TextHighlight(
                    location: rightStart,
                    length: currentEnd - rightStart,
                    color: highlight.color
                ))
            }
        }

        if let color {
            pieces.append(TextHighlight(location: range.location, length: range.length, color: color))
        }

        pieces.sort {
            if $0.location == $1.location { return $0.length < $1.length }
            return $0.location < $1.location
        }

        var merged: [TextHighlight] = []
        for piece in pieces where piece.length > 0 {
            if var last = merged.last,
               last.color == piece.color,
               NSMaxRange(last.range) == piece.location {
                last.length += piece.length
                merged[merged.count - 1] = last
            } else {
                merged.append(piece)
            }
        }
        return merged
    }
}
