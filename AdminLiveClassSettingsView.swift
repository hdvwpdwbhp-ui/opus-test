//
//  AdminLiveClassSettingsView.swift
//  Tanzen mit Tatiana Drexler
//

import SwiftUI
import FirebaseFirestore

struct AdminLiveClassSettingsView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var globalSettings = LiveClassGlobalSettings.defaults()
    @State private var trainerSettings: [LiveClassTrainerSettings] = []
    @State private var isSaving = false

    private let db = Firestore.firestore()

    var body: some View {
        List {
            Section(T("Globale Einstellungen")) {
                Stepper("Auto-Cancel: \(globalSettings.autoCancelHoursBeforeStart)h", value: $globalSettings.autoCancelHoursBeforeStart, in: 1...24)
                Stepper("Join Cutoff: \(globalSettings.joinCutoffMinutesAfterStart) Min", value: $globalSettings.joinCutoffMinutesAfterStart, in: 5...120, step: 5)
                Button(isSaving ? "Speichern..." : "Globale Einstellungen speichern") {
                    Task { await saveGlobal() }
                }
                .disabled(isSaving)
            }

            Section(T("Trainer Einstellungen")) {
                ForEach(trainerSettings) { setting in
                    NavigationLink(setting.id) {
                        AdminTrainerLiveClassSettingsEditor(setting: setting)
                    }
                }
            }
        }
        .navigationTitle(T("Live Settings"))
        .task {
            await loadGlobal()
            await loadTrainerSettings()
        }
    }

    private func loadGlobal() async {
        do {
            let doc = try await db.collection("liveClassGlobalSettings").document("global").getDocument()
            if let data = try? doc.data(as: LiveClassGlobalSettings.self) {
                globalSettings = data
            }
        } catch {}
    }

    private func loadTrainerSettings() async {
        do {
            let snapshot = try await db.collection("liveClassTrainerSettings").getDocuments()
            trainerSettings = snapshot.documents.compactMap { try? $0.data(as: LiveClassTrainerSettings.self) }
        } catch {}
    }

    private func saveGlobal() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try db.collection("liveClassGlobalSettings").document("global").setData(from: globalSettings)
        } catch {}
    }
}

struct AdminTrainerLiveClassSettingsEditor: View {
    @State var setting: LiveClassTrainerSettings
    private let db = Firestore.firestore()

    var body: some View {
        Form {
            Toggle("Trainer darf hosten", isOn: $setting.canHostLiveClasses)
            Picker("Preismodus", selection: $setting.priceMode) {
                Text(T("Admin setzt pro Event")).tag(LiveClassPriceMode.adminSetsPerEvent)
                Text(T("Trainer waehlt innerhalb Range")).tag(LiveClassPriceMode.trainerChoosesWithinRange)
                Text(T("Fix pro Trainer")).tag(LiveClassPriceMode.fixedPerTrainer)
            }
            Stepper("Min Coins: \(setting.minCoinPrice)", value: $setting.minCoinPrice, in: 10...1000, step: 10)
            Stepper("Max Coins: \(setting.maxCoinPrice)", value: $setting.maxCoinPrice, in: 10...2000, step: 10)
            Stepper("Default Coins: \(setting.defaultCoinPrice)", value: $setting.defaultCoinPrice, in: 10...2000, step: 10)
            Stepper("Min Teilnehmer: \(setting.minParticipantsLimit)", value: $setting.minParticipantsLimit, in: 1...50)
            Stepper("Max Teilnehmer: \(setting.maxParticipantsLimit)", value: $setting.maxParticipantsLimit, in: 2...200)
            Stepper("Max Dauer: \(setting.maxDurationMinutes) Min", value: $setting.maxDurationMinutes, in: 30...240, step: 15)

            Button(T("Speichern")) { Task { await save() } }
        }
        .navigationTitle(T("Trainer Settings"))
    }

    private func save() async {
        setting.updatedAt = Date()
        try? db.collection("liveClassTrainerSettings").document(setting.id).setData(from: setting)
    }
}
