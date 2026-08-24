import SwiftUI
import UIKit

struct DanmakuInteractionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: DanmakuItem
    let cid: Int?
    let api: BiliAPIClient
    let isLoggedIn: Bool

    @State private var isLiked = false
    @State private var isMutatingLike = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("弹幕内容") {
                    Text(item.text)
                        .font(.body)
                        .textSelection(.enabled)
                }

                Section {
                    Button {
                        mutateLike()
                    } label: {
                        Label(isLiked ? "取消点赞" : "点赞", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    }
                    .disabled(!supportsRemoteInteraction || isMutatingLike || !isLoggedIn)

                    Button {
                        UIPasteboard.general.string = item.text
                        message = "已复制弹幕"
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }

                    NavigationLink {
                        DanmakuReportReasonList(
                            item: item,
                            cid: cid,
                            api: api,
                            isLoggedIn: isLoggedIn
                        )
                    } label: {
                        Label("举报", systemImage: "exclamationmark.bubble")
                    }
                    .disabled(!supportsRemoteInteraction || !isLoggedIn)
                }

                if !isLoggedIn {
                    Section {
                        Label("登录后可点赞和举报；复制不受影响。", systemImage: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
                } else if !supportsRemoteInteraction {
                    Section {
                        Label("这条弹幕没有可用的服务端编号，只能复制。", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let message {
                    Section {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("弹幕操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var supportsRemoteInteraction: Bool {
        (cid ?? 0) > 0 && (item.dmid ?? 0) > 0
    }

    private func mutateLike() {
        guard let cid, let dmid = item.dmid else { return }
        let target = !isLiked
        isMutatingLike = true
        message = nil
        Task {
            do {
                let effectiveLiked = try await api.setDanmakuLiked(
                    cid: cid,
                    dmid: dmid,
                    liked: target
                )
                isLiked = effectiveLiked
                message = effectiveLiked ? "已点赞" : "已取消点赞"
            } catch {
                message = error.localizedDescription
            }
            isMutatingLike = false
        }
    }
}

private struct DanmakuReportReasonList: View {
    let item: DanmakuItem
    let cid: Int?
    let api: BiliAPIClient
    let isLoggedIn: Bool

    @State private var submittingReason: DanmakuReportReason?
    @State private var message: String?

    var body: some View {
        List {
            ForEach(DanmakuReportReason.allCases.filter { $0 != .other }) { reason in
                Button {
                    submit(reason)
                } label: {
                    HStack {
                        Text(reason.title)
                        Spacer()
                        if submittingReason == reason {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .disabled(submittingReason != nil || !isLoggedIn)
            }

            NavigationLink {
                DanmakuCustomReportForm(item: item, cid: cid, api: api)
            } label: {
                Text(DanmakuReportReason.other.title)
            }
            .disabled(submittingReason != nil || !isLoggedIn)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("选择举报原因")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit(_ reason: DanmakuReportReason) {
        guard let cid, let dmid = item.dmid else { return }
        submittingReason = reason
        message = nil
        Task {
            do {
                try await api.reportDanmaku(cid: cid, dmid: dmid, reason: reason)
                message = "举报已提交"
            } catch {
                message = error.localizedDescription
            }
            submittingReason = nil
        }
    }
}

private struct DanmakuCustomReportForm: View {
    let item: DanmakuItem
    let cid: Int?
    let api: BiliAPIClient

    @State private var content = ""
    @State private var isSubmitting = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("补充说明") {
                TextField("请描述举报原因", text: $content, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    submit()
                } label: {
                    HStack {
                        Text("提交举报")
                        Spacer()
                        if isSubmitting {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("其它原因")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        guard let cid, let dmid = item.dmid else { return }
        isSubmitting = true
        message = nil
        Task {
            do {
                try await api.reportDanmaku(
                    cid: cid,
                    dmid: dmid,
                    reason: .other,
                    content: content
                )
                message = "举报已提交"
            } catch {
                message = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
