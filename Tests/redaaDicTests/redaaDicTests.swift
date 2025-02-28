import Testing
import Foundation
@testable import redaaDic

@Test func loadDic() async throws {
    let dic = try RedaaDictionary.loadFromJson(path: URL(filePath: "/Users/repierre/Documents/mangas/Mokuro/YamadaKun To 7Nin No Majo/jitendex-yomitan/index.json"))
    print(dic)
}

@Test func updateDic() async throws {
    var dic = try RedaaDictionary.loadFromJson(path: URL(filePath: "/Users/repierre/Documents/mangas/Mokuro/YamadaKun To 7Nin No Majo/jitendex-yomitan/index.json"))
    print(dic.hasUpdate)
    try dic.fetchUpdate()
    print(dic.hasUpdate)
    try dic.update(targetDir: URL(filePath: "/var/folders/64/5893896s0d90691cz8spqql00000gn/T/tmp.c3H0GFokH4"))
}
