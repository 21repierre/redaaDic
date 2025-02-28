//
//  Dictionary.swift
//  
//
//  Created by Pierre on 2025/02/28.
//

import Foundation
import ZIPFoundation

private struct DictionaryJson: Codable {
    
    let title: String
    let revision: String
    
    let sequenced: Bool
    let format: Int
    let author: String?
    let isUpdatable: Bool
    let indexUrl: String?
    let downloadUrl: String?
    let url: String?
    let description: String?
    let attribution: String?
    let sourceLanguage: String?
    let targetLanguage: String?
    let frequencyMode: String?
}

enum UpdateState: Codable {
    case unkown, upToDate, updateAvailable
}

struct RedaaDictionary: Codable {
    
    private let dictionary: DictionaryJson
    private(set) var hasUpdate: UpdateState = UpdateState.unkown
    
    public mutating func update(targetDir: URL, progress: Progress? = nil) throws {
        if hasUpdate == UpdateState.updateAvailable {
            guard let downloadUrl = self.dictionary.downloadUrl else {
                return
            }
            guard let url = URL(string: downloadUrl) else {
                return
            }
            let content = try Data(contentsOf: url)
            let archive = try Archive(data: content, accessMode: .read)
            
            var totalUnitCount = Int64(0)
            if let progress = progress {
                totalUnitCount = archive.reduce(0, { $0 + archive.totalUnitCountForReading($1) })
                progress.totalUnitCount = totalUnitCount
            }
            let fileManager = FileManager()
            let targetContent = try fileManager.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: [])
            for item in targetContent {
                try fileManager.removeItem(at: item.standardized)
            }
            
            for item in archive {
                let extractPath = targetDir.appendingPathComponent(item.path)
                guard extractPath.isContained(in: targetDir) else {
                    throw "path traversal"
                }
                let crc32: CRC32
                if let progress = progress {
                    let entryProgress = Progress(totalUnitCount: archive.totalUnitCountForReading(item))
                    progress.addChild(entryProgress, withPendingUnitCount: entryProgress.totalUnitCount)
                    crc32 = try archive.extract(item, to: extractPath, skipCRC32: false, progress: entryProgress)
                } else {
                    crc32 = try archive.extract(item, to: extractPath, skipCRC32: false)
                }
                guard crc32 == item.checksum else {
                    throw "invalid checksum for file \(item.path)"
                }
            }
        }
    }
    
    public mutating func fetchUpdate() throws {
        guard let indexUrl = self.dictionary.indexUrl else {
            return
        }
        guard let url = URL(string: indexUrl) else {
            return
        }
        let content = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: content, options: []) as? [String: Any] else {
            return
        }
        guard let revision = json["revision"] as? String else {
            return
        }
        let currentRevSplit = self.dictionary.revision.split(separator: ".")
        let newRevSplit = revision.split(separator: ".")
        if currentRevSplit.count != newRevSplit.count {
            throw "mismatch revisions"
        }
        for i in 0...currentRevSplit.count {
            guard let currentI = Int(currentRevSplit[i]) else {
                throw "invalid current revision"
            }
            guard let newI = Int(newRevSplit[i]) else {
                throw "invalid new revision"
            }
            if newI > currentI {
                self.hasUpdate = UpdateState.updateAvailable
                return
            }
        }
        self.hasUpdate = UpdateState.upToDate
    }
    
    
    public static func loadFromJson(path: URL) throws -> RedaaDictionary{
        let content = try Data(contentsOf: path)
        let dic = try JSONDecoder().decode(DictionaryJson.self, from: content)
        return RedaaDictionary(dictionary: dic)
    }
    
}
