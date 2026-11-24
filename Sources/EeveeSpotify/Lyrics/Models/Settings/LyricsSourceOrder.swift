import Foundation

/// 「自动优选」询问歌词源的**顺序** —— 用户在设置里自己排，存在 `UserDefaults` 里。
///
/// ── 为什么要有它
/// 「我记得金牛座那边是不是可以自己排序歌词来源的？如果可以，默认排序这样：
/// amll - sl - pl - 网易云 - qq - 酷狗 - un - mxm - bini - gen」
///
/// Taurus 的做法（`SGLyricsOrder` / `SGKeyLyricsProviders`）是：存一份**键的数组**，
/// 数组的顺序就是询问顺序；数组里没有的源等于被关掉。我们只取"顺序"这一半 ——
/// 关掉某个源在单源选择器里已经能做，不必再发明一套开关。
///
/// ── 三条纪律
/// 1. **存键不存展示名**：`LyricsSource.description` 会随语言变（自动优选那一项甚至是
/// 本地化串），存进去就成了脏数据。用 `orderKey`（写死的英文标识）。
/// 2. **读取时自愈**：盘上有未知键 / 重复项 / 已下线的源，一律跳过；
/// 新版本加的源自动**补在末尾**，不改变用户已经排好的相对顺序。
/// 3. **空 = 用默认**：用户从没排过（或点了重置）时返回 `defaultOrder`。
enum LyricsSourceOrder {

    /// ⚠️ 这是**新的** UserDefaults 键，所以不带 `ngzhwm_` 前缀
    /// （那个前缀是早期键的历史包袱，见那次 l10n 清理）。
    static let userDefaultsKey = "lyricsSourceOrder"

    /// 默认顺序。
    ///
    /// **LRCLIB 第一位**，这是本轮修"热门歌也显示没歌词"的关键：
    /// 链路整条只有 `LyricsAutoSelect.totalBudget` 秒，而前面几个源要么要客户端密钥
    /// （Spicy）、要么要 region / 匿名令牌（MxM / 国内三家），一个慢请求就能把预算
    /// 烧光 —— 排在第 9 位的 LRCLIB 根本轮不到。把**唯一不需要任何配置**的源放首位，
    /// 意味着任何一首歌都先拿到一份带时间轴的歌词；后面那些源仍会在
    /// `upgradeBudget` 窗口内被问到，能升级成逐字照样升级（档次优先的判据在
    /// `LyricsAutoSelect.isBetter`，与顺序无关）。
    ///
    /// 其余沿用 `sl - pl - 网易云 - qq - 酷狗 - un - mxm - bini - gen` 的底子，
    /// 国内三家内部按 **酷狗 → 网易云 → QQ** 排（三家都能给逐字，顺序按命中稳定度定：
    /// 酷狗与网易云更稳，QQ 的搜索更容易落到翻唱 / 同长度版本上）。
    static let defaultOrder: [LyricsSource] = [
        .lrclib,       // 无令牌、带时间轴 —— 先保底
        .lrcRed,
        .lyricsPlus,
        .amllTtml,     // amll
        .spicy,        // sl
        .musixmatch,   // mxm
        .petit,        // pl
        .kugou,        // 酷狗
        .netease,      // 网易云
        .qqMusic,      // qq
        .unison,       // un
        .bini,         // bini
        .genius        // gen
    ]

    /// 当前的询问顺序。永远是一个**完整、去重、只含可排序源**的列表。
    static var current: [LyricsSource] {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
            var order: [LyricsSource] = []
            var seen = Set<LyricsSource>()

            for key in stored {
                guard let source = source(forKey: key), !seen.contains(source) else { continue }
                seen.insert(source)
                order.append(source)
            }

            // 新版本加的源（或从没存过）：补在末尾，不动已有的相对顺序。
            for source in defaultOrder where !seen.contains(source) {
                seen.insert(source)
                order.append(source)
            }

            return order
        }
        set {
            let keys = newValue.compactMap(\.orderKey)
            UserDefaults.standard.set(keys, forKey: userDefaultsKey)
        }
    }

    /// 回到默认顺序。
    ///
    /// 用 `removeObject` 而不是写一份默认值：写进去之后，将来改了 `defaultOrder`
    /// 对这台设备就再也不生效了 —— "重置"的语义应该是"回到出厂"，不是"回到今天的出厂"。
    static func reset() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// 键 → 源。认不出就是脏数据 ⇒ nil。
    ///
    /// 遍历 `allCases` 而不是手写一张表：将来加源时只改 `LyricsSource`，
    /// 这里不用跟着改（漏改的表现是"新源排不进顺序、每次都补到末尾"）。
    private static func source(forKey key: String) -> LyricsSource? {
        LyricsSource.allCases.first { $0.orderKey == key }
    }
}
