import Foundation

/// One incremental local data migration step. Steps must be idempotent.
protocol MigrationStep {
  /// Human-readable step name for logging.
  var name: String { get }

  /// App data version after this step completes successfully.
  var resultingVersion: Int { get }

  /// Perform migration work for this step.
  func migrate(from currentVersion: Int) throws
}
