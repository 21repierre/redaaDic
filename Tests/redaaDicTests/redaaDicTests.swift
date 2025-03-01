import Testing
import Foundation
@testable import redaaDic

@Test func loadDic() async throws {
    let dic = try RedaaDictionary.loadFromJson(path: URL(filePath: "/Users/repierre/Documents/mangas/Mokuro/YamadaKun To 7Nin No Majo/jitendex-yomitan"))
    print(dic)
    
    try dic.loadContent()
    print("\(dic.title) has \(dic.terms.count) terms")
    assert(dic.terms.count == 301355)
}

@Test func updateDic() async throws {
    var dic = try RedaaDictionary.loadFromJson(path: URL(filePath: "/Users/repierre/Documents/mangas/Mokuro/YamadaKun To 7Nin No Majo/jitendex-yomitan"))
    print(dic.hasUpdate)
    await dic.fetchUpdate()
//    print(dic.hasUpdate)
//    try await dic.update(targetDir: URL(filePath: "/var/folders/64/5893896s0d90691cz8spqql00000gn/T/tmp.c3H0GFokH4"))
}

@Test func deinflections() async throws {
    let verbs = [
        "している",
        "住んでいます",
        "来ます",
    ]
    
    for verb in verbs {
        print(verb, Inflection.deinflect(text: verb))
    }
}
