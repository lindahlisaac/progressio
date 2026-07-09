import Foundation

/// Reads current on-disk legacy JSON shapes without modifying files.
enum LegacyDataDecoder {
  static let templatesFileName = "templates.json"
  static let enduranceTemplatesFileName = "enduranceTemplates.json"
  static let weeklyTemplatesFileName = "weeklyTemplates.json"
  static let unattachedRunsFileName = "unattachedRuns.json"
  static let weekPlanPrefix = "weekplan-"
  static let strengthLogPrefix = "strengthlog-"

  static func templatesURL() -> URL {
    StoragePaths.file(templatesFileName)
  }

  static func enduranceTemplatesURL() -> URL {
    StoragePaths.file(enduranceTemplatesFileName)
  }

  static func weeklyTemplatesURL() -> URL {
    StoragePaths.file(weeklyTemplatesFileName)
  }

  static func unattachedRunsURL() -> URL {
    StoragePaths.file(unattachedRunsFileName)
  }

  static func documentsDirectory(fileManager: FileManager = .default) -> URL {
    fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
  }

  static func weekPlanURLs(fileManager: FileManager = .default) -> [URL] {
    let directory = StoragePaths.baseDirectory
    guard let urls = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }
    return urls.filter { $0.lastPathComponent.hasPrefix(weekPlanPrefix) && $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  static func strengthLogURLs(fileManager: FileManager = .default) -> [URL] {
    let directory = documentsDirectory(fileManager: fileManager)
    guard let urls = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }
    return urls.filter { $0.lastPathComponent.hasPrefix(strengthLogPrefix) && $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  static func decodeTemplates(from url: URL = templatesURL()) throws -> [StrengthTemplate] {
    let data = try Data(contentsOf: url)
    return try jsonDecoder(includeDates: false).decode([StrengthTemplate].self, from: data)
  }

  static func decodeWeeklyTemplates(from url: URL = weeklyTemplatesURL()) throws -> [WeeklyTemplate] {
    let data = try Data(contentsOf: url)
    return try jsonDecoder(includeDates: true).decode([WeeklyTemplate].self, from: data)
  }

  static func decodeUnattachedRuns(from url: URL = unattachedRunsURL()) throws -> [UnattachedRun] {
    let data = try Data(contentsOf: url)
    return try jsonDecoder(includeDates: true).decode([UnattachedRun].self, from: data)
  }

  static func decodeWeekPlan(from url: URL) throws -> WeekPlan {
    let data = try Data(contentsOf: url)
    return try jsonDecoder(includeDates: true).decode(WeekPlan.self, from: data)
  }

  static func decodeStrengthLog(from url: URL) throws -> StrengthLogState {
    let data = try Data(contentsOf: url)
    return try jsonDecoder(includeDates: false).decode(StrengthLogState.self, from: data)
  }

  /// Smoke-test legacy files so later migration steps can assume decoders work.
  static func validateLegacyFiles(fileManager: FileManager = .default) -> [String] {
    var issues: [String] = []

    if fileManager.fileExists(atPath: templatesURL().path) {
      do {
        _ = try decodeTemplates()
      } catch {
        issues.append("templates.json: \(error.localizedDescription)")
      }
    }

    if fileManager.fileExists(atPath: weeklyTemplatesURL().path) {
      do {
        _ = try decodeWeeklyTemplates()
      } catch {
        issues.append("weeklyTemplates.json: \(error.localizedDescription)")
      }
    }

    if fileManager.fileExists(atPath: unattachedRunsURL().path) {
      do {
        _ = try decodeUnattachedRuns()
      } catch {
        issues.append("unattachedRuns.json: \(error.localizedDescription)")
      }
    }

    for url in weekPlanURLs(fileManager: fileManager) {
      do {
        _ = try decodeWeekPlan(from: url)
      } catch {
        issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
      }
    }

    for url in strengthLogURLs(fileManager: fileManager) {
      do {
        _ = try decodeStrengthLog(from: url)
      } catch {
        issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
      }
    }

    return issues
  }

  private static func jsonDecoder(includeDates: Bool) -> JSONDecoder {
    let decoder = JSONDecoder()
    if includeDates {
      decoder.dateDecodingStrategy = .iso8601
    }
    return decoder
  }
}
