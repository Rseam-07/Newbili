import Foundation

extension VideoDetailViewModel {
    func sendDanmaku(
        text: String,
        mode: DanmakuPostMode,
        fontSize: Int,
        color: UInt32
    ) async throws {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cid = selectedCID, cid > 0 else {
            throw BiliAPIError.api(code: -1, message: "当前视频还没有可发送弹幕的分 P 信息")
        }
        let playbackTime = max(0, stablePlayerViewModel?.currentTime ?? 0)
        let result = try await api.postDanmaku(
            bvid: detail.bvid,
            cid: cid,
            progress: playbackTime,
            text: normalizedText,
            mode: mode,
            fontSize: fontSize,
            color: color
        )

        let localItem = DanmakuItem(
            id: result?.identifier ?? "local-\(UUID().uuidString)",
            time: playbackTime + 0.12,
            mode: mode.rawValue,
            fontSize: Double(fontSize),
            color: color,
            text: normalizedText
        )
        updateDanmakuItems(sortedDanmakuItems(danmakuItems + [localItem]))
        if !isDanmakuEnabled {
            toggleDanmaku()
        }
    }
}
