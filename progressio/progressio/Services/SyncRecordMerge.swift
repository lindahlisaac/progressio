import Foundation

/// Conflict resolution for CloudKit-backed records with soft-delete tombstones.
enum SyncRecordMerge {

    /// Merges local and remote collections by stable ID.
    /// Tombstoned records remain in the merged payload for sync propagation.
    static func mergeByID<T>(
        local: [T],
        remote: [T],
        id: KeyPath<T, UUID>,
        updatedAt: KeyPath<T, Date?>,
        isDeleted: KeyPath<T, Bool>
    ) -> [T] {
        var merged: [UUID: T] = [:]
        for item in local {
            merged[item[keyPath: id]] = item
        }
        for remoteItem in remote {
            let remoteID = remoteItem[keyPath: id]
            if let existing = merged[remoteID] {
                merged[remoteID] = pick(
                    local: existing,
                    remote: remoteItem,
                    updatedAt: updatedAt,
                    isDeleted: isDeleted
                )
            } else {
                merged[remoteID] = remoteItem
            }
        }
        return Array(merged.values)
    }

    /// Picks the winning record when local and remote disagree.
    ///
    /// Policy (`docs/SyncAndMigration.md`):
    /// - Same deletion state: last-writer-wins on `updatedAt`.
    /// - Mixed deletion state: newer `updatedAt` wins unless that would resurrect a deleted record.
    /// - Resurrection is blocked when the newer copy is active but the other side is a tombstone.
    /// - Equal timestamps: prefer the tombstone.
    static func pick<T>(
        local: T,
        remote: T,
        updatedAt: KeyPath<T, Date?>,
        isDeleted: KeyPath<T, Bool>
    ) -> T {
        let localDate = local[keyPath: updatedAt] ?? .distantPast
        let remoteDate = remote[keyPath: updatedAt] ?? .distantPast
        let localDeleted = local[keyPath: isDeleted]
        let remoteDeleted = remote[keyPath: isDeleted]

        if localDeleted == remoteDeleted {
            return remoteDate >= localDate ? remote : local
        }

        if localDate == remoteDate {
            return localDeleted ? local : remote
        }

        if remoteDate > localDate {
            return remoteDeleted ? remote : local
        }

        return local
    }
}
