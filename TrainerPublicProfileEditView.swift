//
//  TrainerPublicProfileEditView.swift
//  Tanzen mit Tatiana Drexler
//
//  Trainer können hier ihr öffentliches Profil bearbeiten
//

import SwiftUI
import PhotosUI
import AVKit

struct TrainerPublicProfileEditView: View {
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var bio = ""
    @State private var specialties: [String] = []
    @State private var newSpecialty = ""
    @State private var instagramURL = ""
    @State private var youtubeURL = ""
    @State private var websiteURL = ""
    @State private var teachingLanguages: Set<String> = ["de"]
    @State private var introVideoURL = ""
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showVideoPicker = false
    @State private var showVideoPlayer = false
    @State private var isUploadingVideo = false
    @State private var uploadProgress: Double = 0
    
    // Verfügbare Sprachen für Unterricht
    private let availableLanguages: [(code: String, flag: String, name: String)] = [
        ("de", "🇩🇪", "Deutsch"),
        ("en", "🇬🇧", "English"),
        ("ru", "🇷🇺", "Русский"),
        ("sk", "🇸🇰", "Slovenčina"),
        ("cs", "🇨🇿", "Čeština")
    ]
    
    var currentUser: AppUser? {
        userManager.currentUser
    }
    
    var body: some View {
        Form {
            // Vorschau-Section
            Section {
                VStack(spacing: TDSpacing.md) {
                    // Profilbild
                    ZStack {
                        Circle()
                            .fill(Color.accentGold.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        if let imageURL = currentUser?.profileImageURL, !imageURL.isEmpty {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(Color.accentGold)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.largeTitle)
                                .foregroundColor(Color.accentGold)
                        }
                    }
                    
                    Text(currentUser?.name ?? "Trainer")
                        .font(TDTypography.title2)
                    
                    Text(T("So sehen User dein öffentliches Profil"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            // Unterrichtssprachen
            Section {
                ForEach(availableLanguages, id: \.code) { language in
                    Button {
                        toggleLanguage(language.code)
                    } label: {
                        HStack {
                            Text(language.flag)
                                .font(.title2)
                            Text(language.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if teachingLanguages.contains(language.code) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.accentGold)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray.opacity(0.4))
                            }
                        }
                    }
                }
            } header: {
                Text(T("Unterrichtssprachen"))
            } footer: {
                Text(T("Wähle alle Sprachen, in denen du Privatstunden geben kannst. Diese werden Usern bei der Buchung angezeigt."))
            }
            
            // Vorstellungsvideo
            Section {
                if !introVideoURL.isEmpty {
                    // Video-Vorschau
                    VStack(spacing: TDSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: TDRadius.md)
                                .fill(Color.black)
                                .frame(height: 180)
                            
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .onTapGesture {
                            showVideoPlayer = true
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(T("Vorstellungsvideo hochgeladen"))
                                .font(TDTypography.caption1)
                            Spacer()
                            Button(T("Ändern")) {
                                showVideoPicker = true
                            }
                            .font(TDTypography.caption1)
                        }
                        
                        Button(role: .destructive) {
                            introVideoURL = ""
                        } label: {
                            Label(T("Video entfernen"), systemImage: "trash")
                                .font(TDTypography.caption1)
                        }
                    }
                } else {
                    // Upload-Button
                    Button {
                        showVideoPicker = true
                    } label: {
                        VStack(spacing: TDSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: TDRadius.md)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .foregroundColor(Color.accentGold.opacity(0.5))
                                    .frame(height: 120)
                                
                                if isUploadingVideo {
                                    VStack(spacing: 8) {
                                        ProgressView()
                                        Text("\(Int(uploadProgress * 100))%")
                                            .font(TDTypography.caption1)
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "video.badge.plus")
                                            .font(.system(size: 36))
                                            .foregroundColor(Color.accentGold)
                                        Text(T("Vorstellungsvideo hochladen"))
                                            .font(TDTypography.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(isUploadingVideo)
                }
            } header: {
                HStack {
                    Text(T("Vorstellungsvideo"))
                    Spacer()
                    Text(T("Optional"))
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text(T("Ein kurzes Video (max. 2 Min.), in dem du dich vorstellst. Dies hilft Usern, dich besser kennenzulernen."))
            }
            
            // Bio
            Section {
                TextEditor(text: $bio)
                    .frame(minHeight: 100)
            } header: {
                Text(T("Über mich"))
            } footer: {
                Text(T("Erzähle den Usern etwas über dich, deine Erfahrung und deinen Unterrichtsstil."))
            }
            
            // Spezialisierungen
            Section {
                ForEach(specialties, id: \.self) { specialty in
                    HStack {
                        Text(specialty)
                        Spacer()
                        Button {
                            specialties.removeAll { $0 == specialty }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                HStack {
                    TextField(T("Neue Spezialisierung"), text: $newSpecialty)
                    Button {
                        if !newSpecialty.isEmpty {
                            specialties.append(newSpecialty)
                            newSpecialty = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color.accentGold)
                    }
                    .disabled(newSpecialty.isEmpty)
                }
            } header: {
                Text(T("Spezialisierungen"))
            } footer: {
                Text(T("z.B. Salsa, Tango, Hochzeitstanz, Kinder-Tanzkurse"))
            }
            
            // Social Media
            Section(T("Social Media & Links")) {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.pink)
                        .frame(width: 24)
                    TextField(T("Instagram URL"), text: $instagramURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                HStack {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    TextField(T("YouTube URL"), text: $youtubeURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    TextField(T("Website URL"), text: $websiteURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            
            // Speichern Button
            Section {
                Button {
                    Task { await saveProfile() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(T("Profil speichern"))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentGold)
                .foregroundColor(.white)
                .disabled(isSaving || teachingLanguages.isEmpty)
            }
        }
        .navigationTitle(T("Öffentliches Profil"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadProfile() }
        .alert(T("✅ Gespeichert"), isPresented: $showSaveSuccess) {
            Button(T("OK")) { }
        } message: {
            Text(T("Dein öffentliches Profil wurde aktualisiert."))
        }
        .sheet(isPresented: $showVideoPicker) {
            TrainerVideoPickerView(videoURL: $introVideoURL, isUploading: $isUploadingVideo, uploadProgress: $uploadProgress)
        }
        .sheet(isPresented: $showVideoPlayer) {
            if !introVideoURL.isEmpty, let url = URL(string: introVideoURL) {
                VideoPlayerSheet(url: url)
            }
        }
    }
    
    private func toggleLanguage(_ code: String) {
        if teachingLanguages.contains(code) {
            // Mindestens eine Sprache muss ausgewählt sein
            if teachingLanguages.count > 1 {
                teachingLanguages.remove(code)
            }
        } else {
            teachingLanguages.insert(code)
        }
    }
    
    private func loadProfile() {
        guard let profile = currentUser?.trainerProfile else { return }
        bio = profile.bio
        specialties = profile.specialties
        instagramURL = profile.socialLinks["instagram"] ?? ""
        youtubeURL = profile.socialLinks["youtube"] ?? ""
        websiteURL = profile.socialLinks["website"] ?? ""
        teachingLanguages = Set(profile.teachingLanguages)
        introVideoURL = profile.introVideoURL ?? ""
        if teachingLanguages.isEmpty {
            teachingLanguages = ["de"]
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        
        var socialLinks: [String: String] = [:]
        if !instagramURL.isEmpty { socialLinks["instagram"] = instagramURL }
        if !youtubeURL.isEmpty { socialLinks["youtube"] = youtubeURL }
        if !websiteURL.isEmpty { socialLinks["website"] = websiteURL }
        
        var profile = userManager.currentUser?.trainerProfile ?? TrainerProfile.empty()
        profile.bio = bio
        profile.specialties = specialties
        profile.socialLinks = socialLinks
        profile.teachingLanguages = Array(teachingLanguages)
        profile.introVideoURL = introVideoURL.isEmpty ? nil : introVideoURL
        
        let (success, _) = await userManager.updateTrainerProfile(profile)
        
        if success {
            showSaveSuccess = true
        }
    }
}

// MARK: - Video Picker für Trainer
struct TrainerVideoPickerView: View {
    @Binding var videoURL: String
    @Binding var isUploading: Bool
    @Binding var uploadProgress: Double
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var manualURL = ""
    @State private var useManualURL = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: TDSpacing.xl) {
                // Header
                VStack(spacing: TDSpacing.sm) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(Color.accentGold)
                    
                    Text(T("Vorstellungsvideo hinzufügen"))
                        .font(TDTypography.title2)
                    
                    Text(T("Wähle ein Video aus deiner Galerie oder gib eine URL ein"))
                        .font(TDTypography.caption1)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, TDSpacing.xl)
                
                // Optionen
                VStack(spacing: TDSpacing.md) {
                    // Aus Galerie wählen
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text(T("Aus Galerie wählen"))
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.accentGold.opacity(0.1))
                        .foregroundColor(Color.accentGold)
                        .cornerRadius(TDRadius.md)
                    }
                    
                    Text(T("oder"))
                        .foregroundColor(.secondary)
                    
                    // Manuelle URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text(T("Video-URL eingeben"))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                        
                        TextField(T("https://..."), text: $manualURL)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                        
                        if !manualURL.isEmpty {
                            Button {
                                videoURL = manualURL
                                dismiss()
                            } label: {
                                Text(T("URL verwenden"))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentGold)
                                    .foregroundColor(.white)
                                    .cornerRadius(TDRadius.md)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(TDRadius.md)
                }
                .padding(.horizontal)
                
                // Upload Progress
                if isUploading {
                    VStack(spacing: 8) {
                        ProgressView(value: uploadProgress)
                            .tint(Color.accentGold)
                        Text(T("Video wird hochgeladen..."))
                            .font(TDTypography.caption1)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Hinweis
                VStack(spacing: 4) {
                    Text(T("📹 Tipps für dein Vorstellungsvideo:"))
                        .font(TDTypography.caption1)
                        .fontWeight(.medium)
                    Text("• Halte es kurz (30 Sek. - 2 Min.)\n• Stelle dich und deinen Tanzstil vor\n• Zeige deine Persönlichkeit")
                        .font(TDTypography.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(TDRadius.md)
                .padding(.horizontal)
            }
            .padding(.bottom)
            .navigationTitle(T("Video hinzufügen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await handleVideoSelection(newItem)
                }
            }
            .alert(T("Fehler"), isPresented: $showError) {
                Button(T("OK")) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isUploading = true
        uploadProgress = 0
        
        do {
            // Simuliere Upload-Progress
            for i in 1...10 {
                try await Task.sleep(nanoseconds: 200_000_000)
                uploadProgress = Double(i) / 10.0
            }
            
            // Lade Video-Daten (für lokale Vorschau)
            if let data = try await item.loadTransferable(type: Data.self) {
                // Speichere temporär und erstelle URL
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("intro_video_\(UUID().uuidString).mp4")
                try data.write(to: tempURL)
                
                // In echte App: Video zu Firebase Storage hochladen
                // Hier simulieren wir mit lokaler URL
                videoURL = tempURL.absoluteString
                
                dismiss()
            }
        } catch {
            errorMessage = "Video konnte nicht geladen werden: \(error.localizedDescription)"
            showError = true
        }
        
        isUploading = false
    }
}

// MARK: - Video Player Sheet
struct VideoPlayerSheet: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .navigationTitle(T("Vorstellungsvideo"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(T("Fertig")) { dismiss() }
                    }
                }
        }
    }
}
