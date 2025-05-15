import Foundation

// 编译开关：设置为 true 启用语言切换测试功能，设置为 false 禁用
#if DEBUG
let ENABLE_LANGUAGE_SWITCHER = true
#else
let ENABLE_LANGUAGE_SWITCHER = true
#endif


// 语言管理类
class LocalizationManager {
    static let shared = LocalizationManager()
    
    // 当前语言
    private var currentLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    // 获取当前语言
    func getCurrentLanguage() -> String {
        return currentLanguage
    }
    
    // 切换语言
    func setLanguage(_ language: String) {
        currentLanguage = language
        // 保存用户选择的语言
        UserDefaults.standard.set(language, forKey: "UserSelectedLanguage")
        // 发送语言变更通知
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    // 获取本地化字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj")
        let bundle: Bundle
        if let path = path {
            bundle = Bundle(path: path) ?? Bundle.main
        } else {
            bundle = Bundle.main
        }
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
    
    // 获取所有支持的语言
    func getSupportedLanguages() -> [(code: String, name: String)] {
        let languages: [(code: String, name: String)] = [
            ("ar", "العربية"),                // Arabic
            ("bg", "Български"),             // Bulgarian
            ("bn", "বাংলা"),                  // Bengali
            ("ca", "Català"),                // Catalan
            ("cs", "Čeština"),               // Czech
            ("da", "Dansk"),                 // Danish
            ("de", "Deutsch"),               // German
            ("el", "Ελληνικά"),              // Greek
            ("en", "English"),               // English
            ("es", "Español"),               // Spanish
            ("et", "Eesti"),                 // Estonian
            ("fa", "فارسی"),                 // Persian
            ("fi", "Suomi"),                 // Finnish
            ("fo", "Føroyskt"),              // Faroese
            ("fr", "Français"),              // French
            ("hi", "हिन्दी"),                 // Hindi
            ("hr", "Hrvatski"),              // Croatian
            ("hu", "Magyar"),                // Hungarian
            ("id", "Bahasa Indonesia"),      // Indonesian
            ("is", "Íslenska"),              // Icelandic
            ("it", "Italiano"),              // Italian
            ("ja", "日本語"),                 // Japanese
            ("jv", "Basa Jawa"),             // Javanese
            ("ka", "ქართული"),              // Georgian
            ("kl", "Kalaallisut"),           // Greenlandic
            ("ko", "한국어"),                 // Korean
            ("lb", "Lëtzebuergesch"),        // Luxembourgish
            ("lt", "Lietuvių"),              // Lithuanian
            ("lv", "Latviešu"),              // Latvian
            ("mr", "मराठी"),                  // Marathi
            ("ms", "Bahasa Melayu"),         // Malay
            ("nl", "Nederlands"),            // Dutch
            ("no", "Norsk"),                 // Norwegian
            ("pa", "ਪੰਜਾਬੀ"),                 // Punjabi
            ("pl", "Polski"),                // Polish
            ("pt", "Português"),             // Portuguese
            ("ro", "Română"),                // Romanian
            ("ru", "Русский"),               // Russian
            ("sk", "Slovenčina"),            // Slovak
            ("sl", "Slovenščina"),           // Slovenian
            ("sv", "Svenska"),               // Swedish
            ("te", "తెలుగు"),                 // Telugu
            ("tg", "Тоҷикӣ"),                // Tajik
            ("th", "ไทย"),                   // Thai
            ("tr", "Türkçe"),                // Turkish
            ("uk", "Українська"),            // Ukrainian
            ("ur", "اردو"),                  // Urdu
            ("vi", "Tiếng Việt"),            // Vietnamese
            ("zh-Hans", "简体中文"),          // Chinese (Simplified)
            ("zh-Hant", "繁體中文")           // Chinese (Traditional)
        ]
        return languages
    }
    
    // 获取语言的本地化名称
    func getLanguageLocalizedName(for code: String) -> String {
        let languages = getSupportedLanguages()
        if let language = languages.first(where: { $0.code == code }) {
            return language.name
        }
        return code
    }
    
    // 初始化时加载用户之前选择的语言
    init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "UserSelectedLanguage") {
            currentLanguage = savedLanguage
        }
    }
}

// 简化本地化字符串的使用
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let localizedFormat = LocalizationManager.shared.localizedString(self)
        return String(format: localizedFormat, arguments: arguments)
    }
}

// 通知名称扩展
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}
