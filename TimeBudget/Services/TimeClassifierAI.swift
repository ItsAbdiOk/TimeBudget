import Foundation
import FoundationModels

// MARK: - Apple Intelligence Integration

extension TimeClassifier {

    @available(iOS 26, *)
    func refineWithIntelligence(
        blocks: [AWActivityBlock],
        validCategories: [String]
    ) async -> [String: String] {
        let items = blocks.prefix(50).map { block in
            // Collect URLs from events for richer context
            let urls = block.events.compactMap { $0.url }.prefix(3)
            let urlString = urls.isEmpty ? nil : urls.joined(separator: ", ")
            let siteInfo = urlString ?? block.topSite

            return UncategorizedItem(
                id: block.id.uuidString,
                app: block.topApp,
                title: block.events.first?.windowTitle ?? "",
                site: siteInfo,
                durationMinutes: block.durationMinutes
            )
        }

        do {
            let results = try await IntelligenceService.shared.categorize(
                items: items,
                validCategories: validCategories
            )
            var mapping: [String: String] = [:]
            var refinedLog: [[String: String]] = []
            for item in results {
                mapping[item.id] = item.category
                // Find the original block to log the change
                if let block = blocks.first(where: { $0.id.uuidString == item.id }),
                   item.category != block.category {
                    refinedLog.append([
                        "app": block.topApp,
                        "site": block.topSite ?? "",
                        "from": block.category,
                        "to": item.category,
                        "confidence": String(format: "%.0f%%", item.confidence * 100)
                    ])
                }
            }
            print("[Intelligence] Categorized \(mapping.count)/\(items.count) blocks, \(refinedLog.count) refined")

            // Store the refinement log for the UI
            if !refinedLog.isEmpty {
                if let logData = try? JSONSerialization.data(withJSONObject: refinedLog),
                   let logString = String(data: logData, encoding: .utf8) {
                    UserDefaults.standard.set(logString, forKey: "intelligence_last_refinement_log")
                }
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "intelligence_last_categorization")
                UserDefaults.standard.set(refinedLog.count, forKey: "intelligence_last_refined_count")
            }

            return mapping
        } catch {
            print("[Intelligence] Categorization failed: \(error.localizedDescription)")
            return [:]
        }
    }

    @available(iOS 26, *)
    func resolveOverlapsWithIntelligence(
        _ entries: [ClassifiedEntry]
    ) async -> [ClassifiedEntry] {
        // First pass: standard priority-based resolution
        let priorityResolved = resolveOverlaps(entries)

        // Find same-priority overlaps among the resolved entries
        let conflictGroups = findSamePriorityOverlaps(priorityResolved)

        guard !conflictGroups.isEmpty else {
            return priorityResolved
        }

        // Ask the LLM to resolve same-priority conflicts
        let formatter = ISO8601DateFormatter()
        let groups = conflictGroups.map { group in
            ConflictGroup(
                groupId: UUID().uuidString,
                overlapStart: formatter.string(from: group.overlapStart),
                overlapEnd: formatter.string(from: group.overlapEnd),
                candidates: group.entries.map { entry in
                    ConflictCandidate(
                        source: entry.source.rawValue,
                        category: entry.category,
                        metadata: entry.metadata,
                        confidence: entry.confidence
                    )
                }
            )
        }

        do {
            let resolutions = try await IntelligenceService.shared.resolveConflicts(groups: groups)
            print("[Intelligence] Resolved \(resolutions.count) conflicts")

            // Apply resolutions: for each group, keep only the winner
            var winnersPerGroup: [String: (source: String, category: String)] = [:]
            for resolution in resolutions {
                winnersPerGroup[resolution.groupId] = (source: resolution.winnerSource, category: resolution.winnerCategory)
            }

            // Rebuild the result: keep non-conflicting entries as-is, apply winners for conflict groups
            var result = priorityResolved.filter { entry in
                // Keep entries not involved in any conflict group
                !conflictGroups.contains { group in
                    group.entries.contains { $0.start == entry.start && $0.source == entry.source }
                }
            }

            // Add winners from each conflict group
            for (i, group) in conflictGroups.enumerated() {
                let groupId = groups[i].groupId
                if let winner = winnersPerGroup[groupId] {
                    // Find the matching entry from the group
                    if let winnerEntry = group.entries.first(where: {
                        $0.source.rawValue == winner.source
                    }) {
                        result.append(winnerEntry)
                    } else if let first = group.entries.first {
                        result.append(first)
                    }
                } else if let first = group.entries.first {
                    // No resolution for this group, keep the first entry
                    result.append(first)
                }
            }

            return result.sorted { $0.start < $1.start }
        } catch {
            print("[Intelligence] Conflict resolution failed: \(error.localizedDescription), using priority-based result")
            return priorityResolved
        }
    }
}
