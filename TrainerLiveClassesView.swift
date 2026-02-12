//
//  TrainerLiveClassesView.swift
//  Tanzen mit Tatiana Drexler
//

import SwiftUI

struct TrainerLiveClassesView: View {
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showCreate = false

    private var myEvents: [LiveClassEvent] {
        guard let trainerId = userManager.currentUser?.id else { return [] }
        return liveManager.events.filter { $0.trainerId == trainerId }
    }

    var body: some View {
        List {
            ForEach(myEvents) { event in
                NavigationLink {
                    LiveClassDetailView(event: event)
                } label: {
                    LiveClassCard(event: event)
                }
            }
        }
        .navigationTitle(T("Meine Livestreams"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            LiveClassEditorView()
        }
        .task {
            liveManager.startListeningToEvents()
        }
    }
}

struct LiveClassEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared

    @State private var title = ""
    @State private var description = ""
    @State private var level: LiveClassLevel = .beginner
    @State private var styleTags = ""
    @State private var startTime = Date().addingTimeInterval(3600)
    @State private var durationMinutes = 60
    @State private var coinPrice = 120
    @State private var minParticipants = 3
    @State private var maxParticipants = 20
    @State private var visibility: LiveClassVisibility = .public

    var body: some View {
        NavigationStack {
            Form {
                Section(T("Details")) {
                    TextField(T("Titel"), text: $title)
                    TextField(T("Beschreibung"), text: $description)
                    Picker("Level", selection: $level) {
                        ForEach(LiveClassLevel.allCases) { lvl in
                            Text(lvl.rawValue).tag(lvl)
                        }
                    }
                    TextField(T("Styles (kommagetrennt)"), text: $styleTags)
                }

                Section(T("Zeit")) {
                    DatePicker("Start", selection: $startTime)
                    Stepper("Dauer: \(durationMinutes) Min", value: $durationMinutes, in: 30...180, step: 15)
                }

                Section(T("Teilnehmer & Coins")) {
                    Stepper("Min: \(minParticipants)", value: $minParticipants, in: 1...50)
                    Stepper("Max: \(maxParticipants)", value: $maxParticipants, in: 2...100)
                    Stepper("Coins: \(coinPrice)", value: $coinPrice, in: 10...1000, step: 10)
                }

                Section(T("Sichtbarkeit")) {
                    Picker("Sichtbarkeit", selection: $visibility) {
                        Text(T("Öffentlich")).tag(LiveClassVisibility.public)
                        Text(T("Nur Follower")).tag(LiveClassVisibility.followersOnly)
                        Text(T("Nur Link")).tag(LiveClassVisibility.linkOnly)
                    }
                }
            }
            .navigationTitle(T("Gruppenstunde planen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Speichern")) {
                        Task { await save() }
                    }
                }
            }
        }
    }

    private func save() async {
        guard let trainerId = userManager.currentUser?.id else { return }
        let endTime = startTime.addingTimeInterval(TimeInterval(durationMinutes) * 60)
        let payload: [String: Any] = [
            "trainerId": trainerId,
            "title": title,
            "description": description,
            "level": level.rawValue,
            "styleTags": styleTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            "startTime": startTime.iso8601,
            "endTime": endTime.iso8601,
            "minParticipants": minParticipants,
            "maxParticipants": maxParticipants,
            "coinPrice": coinPrice,
            "visibility": visibility == .public ? "public" : (visibility == .followersOnly ? "followersOnly" : "linkOnly")
        ]
        _ = await liveManager.createEvent(payload: payload)
        dismiss()
    }
}

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}
