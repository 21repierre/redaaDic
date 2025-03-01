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

public struct TermJson {
    public let term: String
    public let reading: String
    public let definitionTags: [String]
    public let wordTypes: [WordType]
    public let score: Int
    public let definitions: [Any]
    public let sequence: Int
    public let termTags: [String]
}

public enum UpdateState: Codable {
    case unkown, upToDate, updateAvailable
}

public class RedaaDictionary: ObservableObject {
    
    @Published private var dictionary: DictionaryJson
    @Published public private(set) var hasUpdate: UpdateState = .unkown
    private var path: URL
    public private(set) var terms: [TermJson] = []
    
    private init(dictionary: DictionaryJson, path: URL) {
        self.dictionary = dictionary
        self.path = path
    }
    
    public var title: String {
        return dictionary.title
    }
    
    
    public var revision: String {
        return dictionary.revision
    }
    public var sequenced: Bool {
        return dictionary.sequenced
    }
    public var format: Int {
        return dictionary.format
    }
    public var author: String? {
        return dictionary.author
    }
    public var isUpdatable: Bool {
        return dictionary.isUpdatable
    }
    
    public var indexUrl: String? {
        return dictionary.indexUrl
    }
    public var downloadUrl: String? {
        return dictionary.downloadUrl
    }
    public var url: String? {
        return dictionary.url
    }
    public var description: String? {
        return dictionary.description
    }
    public var attribution: String? {
        return dictionary.attribution
    }
    public var sourceLanguage: String? {
        return dictionary.sourceLanguage
    }
    public var targetLanguage: String? {
        return dictionary.targetLanguage
    }
    public var frequencyMode: String? {
        return dictionary.frequencyMode
    }
    
    @MainActor
    public func update(targetDir: URL, progress: Progress? = nil) async throws {
        guard hasUpdate == .updateAvailable,
              let downloadUrl = dictionary.downloadUrl,
              let url = URL(string: downloadUrl) else {
            return
        }
        
        do {
            let (content, _) = try await URLSession.shared.data(from: url)
            let archive = try Archive(data: content, accessMode: .read)
            
            var totalUnitCount = Int64(0)
            if let progress = progress {
                totalUnitCount = archive.reduce(0, { $0 + archive.totalUnitCountForReading($1) })
                progress.totalUnitCount = totalUnitCount
            }
            
            let fileManager = FileManager.default
            let targetContent = try fileManager.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: [])
            for item in targetContent {
                try fileManager.removeItem(at: item.standardized)
            }
            
            for item in archive {
                let extractPath = targetDir.appendingPathComponent(item.path)
                guard extractPath.isContained(in: targetDir) else {
                    throw "path traversal error"
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
            
            await MainActor.run {
                self.hasUpdate = .upToDate
            }
        } catch {
            print("failed to update dictionary:", error)
            throw error
        }
    }
    
    @MainActor
    public func fetchUpdate() async {
        guard let indexUrl = self.dictionary.indexUrl,
              let url = URL(string: indexUrl) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONDecoder().decode(DictionaryJson.self, from: data)
            
            let currentRevSplit = self.dictionary.revision.split(separator: ".")
            let newRevSplit = json.revision.split(separator: ".")
            
            if currentRevSplit.count != newRevSplit.count { return }
            
            for i in 0..<currentRevSplit.count {
                guard let currentI = Int(currentRevSplit[i]),
                      let newI = Int(newRevSplit[i]) else { return }
                
                if newI > currentI {
                    await MainActor.run {
                        self.hasUpdate = .updateAvailable
                    }
                    return
                }
            }
            
            await MainActor.run {
                self.hasUpdate = .upToDate
            }
        } catch {
            print("failed to fetch update:", error)
        }
    }
    
    
    public static func loadFromJson(path: URL) throws -> RedaaDictionary{
        let content = try Data(contentsOf: path.appending(component: "index.json"))
        let dic = try JSONDecoder().decode(DictionaryJson.self, from: content)
        return RedaaDictionary(dictionary: dic, path: path)
    }
    
    public func loadContent() throws {
        
        // Load terms
        var i = 1
        while true {
            let filename = "term_bank_\(i).json"
            let filepath = self.path.appending(component: filename)
            
            guard let fileContent = try? Data(contentsOf: filepath) else {
                break
            }
            let termsJson = try JSONSerialization.jsonObject(with: fileContent)
            guard let termsJson = termsJson as? [[Any]] else {
                throw "invalid file format"
            }
            
            for t in termsJson {
                guard let term = t[0] as? String,
                      let reading = t[1] as? String,
                      let wordTypesJson = t[3] as? String,
                      let score = t[4] as? Int,
                      let definitions = t[5] as? [Any],
                      let sequence  = t[6] as? Int,
                      let termTagsJson = t[7]  as? String
                else {
                    throw "invalid terms format"
                }
                let definitionTagsJson = t[2] as? String ?? ""
                let definitionTags = definitionTagsJson.components(separatedBy: " ")
                let termTags = termTagsJson.components(separatedBy: " ")
                let wordTypesArray = wordTypesJson.components(separatedBy: " ")
                let wordTypes = wordTypesArray.compactMap {
                    WordType.fromString(s: $0)
                }
                
                let termJson = TermJson(term: term, reading: reading, definitionTags: definitionTags, wordTypes: wordTypes, score: score, definitions: definitions, sequence: sequence, termTags: termTags)
                
                self.terms.append(termJson)
            }
            
            i += 1
        }
    }
    
}
