//
//  LiveClassJoinView.swift
//  Tanzen mit Tatiana Drexler
//

import SwiftUI

struct LiveClassJoinView: View {
    let eventId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveManager = LiveClassManager.shared
    @State private var joinInfo: JoinTokenResponse?

    var body: some View {
        VStack {
            if let joinInfo = joinInfo {
                LiveClassVideoView(joinInfo: joinInfo)
            } else {
                ProgressView("Verbinde...")
            }
        }
        .task {
            joinInfo = await liveManager.requestJoinToken(eventId: eventId)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(T("Schließen")) { dismiss() }
            }
        }
    }
}

struct LiveClassVideoView: View {
    let joinInfo: JoinTokenResponse

    var body: some View {
        #if canImport(AgoraRtcKit)
        AgoraLiveView(joinInfo: joinInfo)
        #else
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
            Text(T("Agora SDK fehlt"))
                .font(.headline)
            Text(T("Bitte AgoraRtcKit per SPM hinzufügen."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        #endif
    }
}

#if canImport(AgoraRtcKit)
import AgoraRtcKit

struct AgoraLiveView: UIViewRepresentable {
    let joinInfo: JoinTokenResponse

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let engine = AgoraRtcEngineKit.sharedEngine(withAppId: "", delegate: nil)
        engine.enableVideo()
        engine.joinChannel(byToken: joinInfo.token, channelId: joinInfo.channelName, info: nil, uid: UInt(joinInfo.uid)) { _, _, _ in }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
