import Foundation

extension VideoDetailViewModel {
    @discardableResult
    func addToWatchLater() async -> Bool {
        guard sessionStore.isLoggedIn else {
            interactionMessage = "请先登录后再加入稍后再看"
            return false
        }
        let aid = detail.aid
        let bvid = detail.bvid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (aid ?? 0) > 0 || bvid.lowercased().hasPrefix("bv") else {
            interactionMessage = "当前内容没有可用的 AV 号或 BV 号"
            return false
        }

        interactionMessage = nil
        isMutatingInteraction = true
        defer { isMutatingInteraction = false }
        do {
            try await api.addVideoToWatchLater(aid: aid, bvid: bvid)
            interactionMessage = "已加入稍后再看"
            return true
        } catch {
            interactionMessage = "加入稍后再看失败：\(error.localizedDescription)"
            return false
        }
    }
}
