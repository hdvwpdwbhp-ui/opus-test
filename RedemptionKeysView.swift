//
//  RedemptionKeysView.swift
//  Tanzen mit Tatiana Drexler
//

import SwiftUI

struct RedemptionKeysView: View {
    @StateObject private var keyManager = RedemptionKeyManager.shared
    @EnvironmentObject var courseViewModel: CourseViewModel
    @State private var showCreateSheet = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(T("Aktive Keys"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        Text("\(activeKeysCount)")
                            .font(TDTypography.title1)
                            .foregroundColor(Color.accentGold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(T("Einlösungen gesamt"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        Text("\(totalRedemptions)")
                            .font(TDTypography.title1)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                if keyManager.keys.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(T("Keine Keys erstellt"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(keyManager.keys.sorted { $0.createdAt > $1.createdAt }) { key in
                        RedemptionKeyRow(key: key, courses: courseViewModel.courses)
                    }
                    .onDelete(perform: deleteKeys)
                }
            } header: {
                Text(T("Alle Keys (%@)", "\(keyManager.keys.count)"))
            }
        }
        .navigationTitle(T("Gutschein-Codes"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color.accentGold)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateRedemptionKeyView(courses: courseViewModel.courses)
        }
        .refreshable { await keyManager.loadFromCloud() }
    }
    
    private var activeKeysCount: Int {
        keyManager.keys.filter { $0.isValid }.count
    }
    
    private var totalRedemptions: Int {
        keyManager.keys.reduce(0) { $0 + $1.currentUses }
    }
    
    private func deleteKeys(at offsets: IndexSet) {
        let sortedKeys = keyManager.keys.sorted { $0.createdAt > $1.createdAt }
        Task {
            for index in offsets {
                await keyManager.deleteKey(sortedKeys[index])
            }
        }
    }
}

struct RedemptionKeyRow: View {
    let key: RedemptionKey
    let courses: [Course]
    @State private var showDetails = false
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key.key)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    UIPasteboard.general.string = key.key
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied ? .green : Color.accentGold)
                }
            }
            
            HStack {
                Text(key.isValid ? "Aktiv" : "Abgelaufen")
                    .font(TDTypography.caption1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(key.isValid ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(key.isValid ? .green : .red)
                    .cornerRadius(4)
                
                Text(key.usesDisplay)
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(key.courseIds.count) Kurs(e)")
                    .font(TDTypography.caption1)
                    .foregroundColor(.secondary)
            }
            
            if showDetails {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Kurse:")).font(TDTypography.caption1).fontWeight(.semibold)
                    ForEach(key.courseIds, id: \.self) { courseId in
                        if let course = courses.first(where: { $0.id == courseId }) {
                            Text("• \(course.title)")
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let expiresAt = key.expiresAt {
                        Text(T("Läuft ab: %@", expiresAt.formatted(date: .abbreviated, time: .omitted)))
                            .font(TDTypography.caption1)
                            .foregroundColor(expiresAt < Date() ? .red : .secondary)
                    }
                    if !key.note.isEmpty {
                        Text(T("Notiz: %@", key.note))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { showDetails.toggle() } }
    }
}

struct CreateRedemptionKeyView: View {
    let courses: [Course]
    @Environment(\.dismiss) var dismiss
    @StateObject private var keyManager = RedemptionKeyManager.shared
    
    @State private var selectedCourseIds: Set<String> = []
    @State private var maxUses = 1
    @State private var hasExpiration = false
    @State private var expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var note = ""
    @State private var isCreating = false
    @State private var createdKey: RedemptionKey?
    
    var body: some View {
        NavigationStack {
            Form {
                if let key = createdKey {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            Text(T("Key erstellt!")).font(TDTypography.title2)
                            Text(key.key)
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(Color.accentGold)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            Button {
                                UIPasteboard.general.string = key.key
                            } label: {
                                Label(T("Code kopieren"), systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentGold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                    Section {
                        Button(T("Weiteren Key erstellen")) {
                            createdKey = nil
                            selectedCourseIds.removeAll()
                        }
                        Button(T("Fertig")) { dismiss() }
                    }
                } else {
                    Section {
                        ForEach(courses) { course in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(course.title).font(TDTypography.body)
                                    Text(course.level.rawValue)
                                        .font(TDTypography.caption1)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedCourseIds.contains(course.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedCourseIds.contains(course.id) ? Color.accentGold : .gray)
                                    .font(.title2)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedCourseIds.contains(course.id) {
                                    selectedCourseIds.remove(course.id)
                                } else {
                                    selectedCourseIds.insert(course.id)
                                }
                            }
                        }
                        HStack {
                            Button(T("Alle auswählen")) {
                                selectedCourseIds = Set(courses.map { $0.id })
                            }
                            .font(TDTypography.caption1)
                            Spacer()
                            Button(T("Keine")) { selectedCourseIds.removeAll() }
                                .font(TDTypography.caption1)
                        }
                        .foregroundColor(Color.accentGold)
                    } header: {
                        Text(T("Kurse auswählen (%@)", "\(selectedCourseIds.count)"))
                    }
                    
                    Section {
                        Stepper(value: $maxUses, in: 0...1000) {
                            HStack {
                                Text(T("Maximale Nutzungen"))
                                Spacer()
                                Text(maxUses == 0 ? "Unbegrenzt" : "\(maxUses)×")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: { Text(T("Nutzungslimit")) }
                    
                    Section {
                        Toggle("Ablaufdatum setzen", isOn: $hasExpiration)
                        if hasExpiration {
                            DatePicker("Gültig bis", selection: $expirationDate, in: Date()..., displayedComponents: .date)
                        }
                    } header: { Text(T("Gültigkeit")) }
                    
                    Section {
                        TextField(T("z.B. 'Gewinnspiel Februar'"), text: $note)
                    } header: { Text(T("Notiz (optional)")) }
                    
                    Section {
                        Button { createKey() } label: {
                            HStack {
                                Spacer()
                                if isCreating {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(T("Key erstellen")).fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(selectedCourseIds.isEmpty || isCreating)
                        .listRowBackground(selectedCourseIds.isEmpty ? Color.gray : Color.accentGold)
                        .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle(T("Neuer Gutschein-Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
        }
    }
    
    private func createKey() {
        isCreating = true
        Task {
            let key = await keyManager.createKey(
                courseIds: Array(selectedCourseIds),
                maxUses: maxUses,
                expiresAt: hasExpiration ? expirationDate : nil,
                note: note
            )
            isCreating = false
            createdKey = key
        }
    }
}

struct RedeemKeyView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeViewModel: StoreViewModel
    @StateObject private var keyManager = RedemptionKeyManager.shared
    @StateObject private var coinManager = CoinManager.shared
    @StateObject private var userManager = UserManager.shared
    
    @State private var keyCode = ""
    @State private var isRedeeming = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    @State private var showResult = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "gift.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.accentGold)
                Text(T("Gutschein einlösen")).font(TDTypography.title1)
                Text(T("Gib deinen Code ein um Kurse oder DanceCoins freizuschalten"))
                    .font(TDTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField(T("XXXX-XXXX-XXXX"), text: $keyCode)
                    .font(.system(.title2, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Button { redeemKey() } label: {
                    HStack {
                        if isRedeeming {
                            ProgressView().tint(.white)
                        } else {
                            Text(T("Einlösen")).fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(keyCode.count >= 6 ? Color.accentGold : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(keyCode.count < 6 || isRedeeming)
                .padding(.horizontal)
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Schließen")) { dismiss() }
                }
            }
            .alert(isSuccess ? "🎉 Erfolgreich!" : "❌ Fehler", isPresented: $showResult) {
                Button(T("OK")) { if isSuccess { dismiss() } }
            } message: {
                Text(resultMessage)
            }
            .task { 
                await keyManager.loadFromCloud()
                // Initialisiere Coin-Wallet falls User eingeloggt
                if let userId = userManager.currentUser?.id, coinManager.wallet == nil {
                    await coinManager.initialize(for: userId)
                }
            }
        }
    }
    
    private func redeemKey() {
        isRedeeming = true
        Task {
            let normalizedCode = keyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Prüfe zuerst ob es ein Coin-Code ist (beginnt mit "DANCE-")
            if normalizedCode.hasPrefix("DANCE-") {
                // Coin-Code einlösen
                let result = await coinManager.redeemCoinKey(code: normalizedCode)
                isRedeeming = false
                isSuccess = result.success
                resultMessage = result.message
                showResult = true
            } else {
                // Normaler Kurs-Gutschein
                let result = await keyManager.redeemKey(keyCode, storeViewModel: storeViewModel)
                isRedeeming = false
                isSuccess = result.success
                resultMessage = result.message
                showResult = true
            }
        }
    }
}
