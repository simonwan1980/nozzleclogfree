#!/usr/bin/swift

import Foundation

// Language codes and their corresponding translations
let languageTranslations: [(code: String, languageWord: String, selectLanguagePhrase: String, searchWord: String)] = [
    ("ar", "اللغة", "اختر اللغة", "بحث"),
    ("bg", "Език", "Избери език", "Търсене"),
    ("bn", "ভাষা", "ভাষা নির্বাচন করুন", "অনুসন্ধান"),
    ("ca", "Idioma", "Seleccionar idioma", "Cerca"),
    ("cs", "Jazyk", "Vybrat jazyk", "Hledat"),
    ("da", "Sprog", "Vælg sprog", "Søg"),
    ("de", "Sprache", "Sprache auswählen", "Suchen"),
    ("el", "Γλώσσα", "Επιλογή γλώσσας", "Αναζήτηση"),
    ("en", "Language", "Select Language", "Search"),
    ("es", "Idioma", "Seleccionar idioma", "Buscar"),
    ("et", "Keel", "Vali keel", "Otsing"),
    ("fa", "زبان", "انتخاب زبان", "جستجو"),
    ("fi", "Kieli", "Valitse kieli", "Haku"),
    ("fo", "Mál", "Vel mál", "Leita"),
    ("fr", "Langue", "Sélectionner la langue", "Rechercher"),
    ("hi", "भाषा", "भाषा चुनें", "खोज"),
    ("hr", "Jezik", "Odaberi jezik", "Pretraži"),
    ("hu", "Nyelv", "Nyelv kiválasztása", "Keresés"),
    ("id", "Bahasa", "Pilih Bahasa", "Cari"),
    ("is", "Tungumál", "Veldu tungumál", "Leita"),
    ("it", "Lingua", "Seleziona lingua", "Cerca"),
    ("ja", "言語", "言語を選択", "検索"),
    ("jv", "Basa", "Pilih Basa", "Golèk"),
    ("ka", "ენა", "აირჩიეთ ენა", "ძიება"),
    ("kl", "Oqaatsit", "Oqaatsit toqqaruk", "Ujarlerit"),
    ("ko", "언어", "언어 선택", "검색"),
    ("lb", "Sprooch", "Sprooch wielen", "Sichen"),
    ("lt", "Kalba", "Pasirinkti kalbą", "Paieška"),
    ("lv", "Valoda", "Izvēlēties valodu", "Meklēt"),
    ("mr", "भाषा", "भाषा निवडा", "शोध"),
    ("ms", "Bahasa", "Pilih Bahasa", "Cari"),
    ("nl", "Taal", "Taal selecteren", "Zoeken"),
    ("no", "Språk", "Velg språk", "Søk"),
    ("pa", "ਭਾਸ਼ਾ", "ਭਾਸ਼ਾ ਚੁਣੋ", "ਖੋਜ"),
    ("pl", "Język", "Wybierz język", "Szukaj"),
    ("pt", "Idioma", "Selecionar idioma", "Pesquisar"),
    ("ro", "Limbă", "Selectați limba", "Căutare"),
    ("ru", "Язык", "Выбрать язык", "Поиск"),
    ("sk", "Jazyk", "Vybrať jazyk", "Hľadať"),
    ("sl", "Jezik", "Izberi jezik", "Iskanje"),
    ("sv", "Språk", "Välj språk", "Sök"),
    ("te", "భాష", "భాషను ఎంచుకోండి", "శోధన"),
    ("tg", "Забон", "Интихоби забон", "Ҷустуҷӯ"),
    ("th", "ภาษา", "เลือกภาษา", "ค้นหา"),
    ("tr", "Dil", "Dil seçin", "Ara"),
    ("uk", "Мова", "Вибрати мову", "Пошук"),
    ("ur", "زبان", "زبان منتخب کریں", "تلاش"),
    ("vi", "Ngôn ngữ", "Chọn ngôn ngữ", "Tìm kiếm"),
    ("zh-Hans", "语言", "选择语言", "搜索"),
    ("zh-Hant", "語言", "選擇語言", "搜尋")
]

// 获取脚本所在目录的父目录（项目根目录）
let scriptURL = URL(fileURLWithPath: #file)
let projectDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
let noClogDir = (projectDir as NSString).appendingPathComponent("NoClog")

// Update localization strings for each language
for (code, languageWord, selectLanguagePhrase, searchWord) in languageTranslations {
    let lprojPath = (noClogDir as NSString).appendingPathComponent("\(code).lproj")
    let stringsPath = "\(lprojPath)/Localizable.strings"
    
    // Check if the directory exists
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: lprojPath) {
        print("Directory does not exist: \(lprojPath)")
        continue
    }
    
    // Read the existing localization file
    var content: String
    do {
        content = try String(contentsOfFile: stringsPath, encoding: .utf8)
    } catch {
        print("Cannot read file \(stringsPath): \(error)")
        continue
    }
    
    // Check if translations for "Language" and "Select Language" already exist
    if !content.contains("\"Language\" = ") {
        // Add Language translation in the MenuBarView section
        if let range = content.range(of: "// MenuBarView") {
            var lines = content.components(separatedBy: .newlines)
            var insertIndex = -1
            
            // Find the end position of the MenuBarView section
            for (index, line) in lines.enumerated() {
                if line.contains("// MenuBarView") {
                    insertIndex = index
                    break
                }
            }
            
            if insertIndex >= 0 {
                // Find the appropriate insertion position
                var insertPosition = insertIndex
                while insertPosition < lines.count {
                    if lines[insertPosition].contains("\"Configure Schedule\"") || 
                       lines[insertPosition].contains("\"Exit\"") {
                        insertPosition += 1
                        break
                    }
                    insertPosition += 1
                    if insertPosition >= lines.count {
                        insertPosition = insertIndex + 10 // 如果找不到合适位置，就在 MenuBarView 部分后面插入
                        break
                    }
                }
                
                // Insert translations
                lines.insert("\"Language\" = \"\(languageWord)\";", at: insertPosition)
                lines.insert("\"Select Language\" = \"\(selectLanguagePhrase)\";", at: insertPosition + 1)
                lines.insert("\"Search\" = \"\(searchWord)\";", at: insertPosition + 2)
                
                // Save the updated content
                content = lines.joined(separator: "\n")
                do {
                    try content.write(toFile: stringsPath, atomically: true, encoding: .utf8)
                    print("已更新 \(code) 的翻译")
                } catch {
                    print("Cannot write to file \(stringsPath): \(error)")
                }
            }
        }
    } else {
        print("\(code) already contains Language translation, skipping")
    }
}

print("All localization strings for all languages have been updated!")
