import Foundation

// MARK: - Overlap Resolution

extension TimeClassifier {

    struct OverlapGroup {
        let overlapStart: Date
        let overlapEnd: Date
        var entries: [ClassifiedEntry]
    }

    func resolveOverlaps(_ entries: [ClassifiedEntry]) -> [ClassifiedEntry] {
        // Source priority (lower number = higher priority)
        func priority(for source: DataSource, category: String) -> Int {
            switch source {
            case .manual: return 0
            case .healthKit where category == "Sleep": return 1
            case .healthKit: return 2
            case .calendar: return 3
            case .aniList: return 4
            case .pocketCasts: return 4
            case .activityWatch: return 4
            case .coreMotion: return 5
            case .coreLocation: return 6
            }
        }

        // Sort by priority (highest first)
        let sorted = entries.sorted { priority(for: $0.source, category: $0.category) < priority(for: $1.source, category: $1.category) }

        var occupied: [(start: Date, end: Date)] = []
        var finalEntries: [ClassifiedEntry] = []

        for entry in sorted {
            var remainingSegments = [(start: entry.start, end: entry.end)]

            for occ in occupied {
                var newSegments: [(start: Date, end: Date)] = []
                for seg in remainingSegments {
                    // No overlap
                    if seg.end <= occ.start || seg.start >= occ.end {
                        newSegments.append(seg)
                    } else {
                        // Partial overlap — keep non-overlapping parts
                        if seg.start < occ.start {
                            newSegments.append((start: seg.start, end: occ.start))
                        }
                        if seg.end > occ.end {
                            newSegments.append((start: occ.end, end: seg.end))
                        }
                    }
                }
                remainingSegments = newSegments
            }

            // Add surviving segments
            for seg in remainingSegments {
                // Skip tiny segments (< 1 minute)
                guard seg.end.timeIntervalSince(seg.start) >= 60 else { continue }
                finalEntries.append((
                    start: seg.start,
                    end: seg.end,
                    category: entry.category,
                    source: entry.source,
                    confidence: entry.confidence,
                    metadata: entry.metadata
                ))
                occupied.append((start: seg.start, end: seg.end))
            }
        }

        return finalEntries.sorted { $0.start < $1.start }
    }

    func findSamePriorityOverlaps(_ entries: [ClassifiedEntry]) -> [OverlapGroup] {
        func priority(for source: DataSource, category: String) -> Int {
            switch source {
            case .manual: return 0
            case .healthKit where category == "Sleep": return 1
            case .healthKit: return 2
            case .calendar: return 3
            case .aniList: return 4
            case .pocketCasts: return 4
            case .activityWatch: return 4
            case .coreMotion: return 5
            case .coreLocation: return 6
            }
        }

        var groups: [OverlapGroup] = []

        for i in 0..<entries.count {
            for j in (i+1)..<entries.count {
                let a = entries[i]
                let b = entries[j]

                // Same priority?
                let pA = priority(for: a.source, category: a.category)
                let pB = priority(for: b.source, category: b.category)
                guard pA == pB else { continue }

                // Overlapping?
                let overlapStart = max(a.start, b.start)
                let overlapEnd = min(a.end, b.end)
                guard overlapStart < overlapEnd else { continue }
                guard overlapEnd.timeIntervalSince(overlapStart) >= 60 else { continue }

                groups.append(OverlapGroup(
                    overlapStart: overlapStart,
                    overlapEnd: overlapEnd,
                    entries: [a, b]
                ))
            }
        }

        return groups
    }
}
