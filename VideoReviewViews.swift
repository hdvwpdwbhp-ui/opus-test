//
//  VideoReviewViews.swift
//  Tanzen mit Tatiana Drexler
//
//  Views für Video-Einreichungen und Reviews
//

import SwiftUI
import AVKit
import PhotosUI

// MARK: - Admin: Trainer Review Settings

/// Admin-View zum Konfigurieren der Video-Review-Settings pro Trainer
struct VideoReviewAdminView: View {
    @StateObject private var reviewManager = VideoReviewManager.shared
    @State private var selectedTrainer: AppUser?
    @State private var showEditSheet = false
    @State private var searchText = ""
    
    var trainers: [AppUser] {
        UserManager.shared.allUsers.filter { $0.group == .trainer }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(trainers) { trainer in
                        TrainerReviewSettingsRow(
                            trainer: trainer,
                            settings: reviewManager.trainerSettings[trainer.id]
                        )
                        .onTapGesture {
                            selectedTrainer = trainer
                            showEditSheet = true
                        }
                    }
                } header: {
                    Text(T("Trainer (%@)", "\(trainers.count)"))
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(T("Als Admin kannst du für jeden Trainer den Preis pro Minute, Min/Max-Minuten und geschätzte Lieferzeit festlegen."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Trainer suchen")
            .navigationTitle(T("Video-Reviews verwalten"))
            .refreshable {
                await reviewManager.loadAllTrainerSettings()
            }
            .sheet(isPresented: $showEditSheet) {
                if let trainer = selectedTrainer {
                    EditTrainerReviewSettingsView(trainer: trainer)
                }
            }
            .task {
                await reviewManager.loadAllTrainerSettings()
            }
        }
    }
}

struct TrainerReviewSettingsRow: View {
    let trainer: AppUser
    let settings: TrainerReviewSettings?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trainer.name)
                    .font(.headline)
                
                if let settings = settings {
                    HStack(spacing: 8) {
                        Label(settings.formattedPricePerMinute + "/Min", systemImage: "eurosign.circle")
                        Label("\(settings.minMinutes)-\(settings.maxMinutes) Min", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    Text(T("Noch nicht konfiguriert"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let settings = settings {
                Circle()
                    .fill(settings.acceptsVideoSubmissions ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EditTrainerReviewSettingsView: View {
    let trainer: AppUser
    @StateObject private var reviewManager = VideoReviewManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var acceptsSubmissions: Bool = false
    @State private var pricePerMinute: String = "3.50"
    @State private var minMinutes: Int = 1
    @State private var maxMinutes: Int = 10
    @State private var avgDeliveryDays: Int = 5
    @State private var description: String = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        AsyncImage(url: URL(string: trainer.profileImageURL ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text(trainer.name)
                                .font(.headline)
                            Text(trainer.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(T("Aktivierung")) {
                    Toggle("Video-Einreichungen akzeptieren", isOn: $acceptsSubmissions)
                }
                
                Section(T("Preisgestaltung (nur Admin)")) {
                    HStack {
                        Text(T("Preis pro Minute"))
                        Spacer()
                        TextField(T("€"), text: $pricePerMinute)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(T("€"))
                    }
                    
                    Stepper("Mindestminuten: \(minMinutes)", value: $minMinutes, in: 1...maxMinutes)
                    Stepper("Maximalminuten: \(maxMinutes)", value: $maxMinutes, in: minMinutes...30)
                    Stepper("Ø Lieferzeit: \(avgDeliveryDays) Tage", value: $avgDeliveryDays, in: 1...30)
                }
                
                Section(T("Beschreibung")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section {
                    // Preisvorschau
                    VStack(alignment: .leading, spacing: 8) {
                        Text(T("Preisvorschau:"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let price = Decimal(string: pricePerMinute.replacingOccurrences(of: ",", with: ".")) {
                            ForEach([1, 3, 5, 10], id: \.self) { minutes in
                                if minutes >= minMinutes && minutes <= maxMinutes {
                                    HStack {
                                        Text("\(minutes) Minuten")
                                        Spacer()
                                        Text(formatPrice(Decimal(minutes) * price))
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(T("Review-Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Speichern")) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert(T("Hinweis"), isPresented: $showAlert) {
                Button(T("OK")) { dismiss() }
            } message: {
                Text(alertMessage)
            }
            .onAppear { loadExisting() }
        }
    }
    
    private func loadExisting() {
        if let settings = reviewManager.trainerSettings[trainer.id] {
            acceptsSubmissions = settings.acceptsVideoSubmissions
            pricePerMinute = "\(settings.reviewPricePerMinute)"
            minMinutes = settings.minMinutes
            maxMinutes = settings.maxMinutes
            avgDeliveryDays = settings.avgDeliveryDays
            description = settings.description
        }
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        guard let price = Decimal(string: pricePerMinute.replacingOccurrences(of: ",", with: ".")) else {
            alertMessage = "Ungültiger Preis"
            showAlert = true
            return
        }
        
        let success = await reviewManager.updateTrainerPricing(
            trainerId: trainer.id,
            pricePerMinute: price,
            minMinutes: minMinutes,
            maxMinutes: maxMinutes,
            avgDeliveryDays: avgDeliveryDays,
            description: description
        )
        
        if success {
            // Auch Toggle speichern
            _ = await reviewManager.toggleAcceptsSubmissions(trainerId: trainer.id, accepts: acceptsSubmissions)
            alertMessage = "Einstellungen gespeichert!"
            showAlert = true
        } else {
            alertMessage = reviewManager.errorMessage ?? "Fehler beim Speichern"
            showAlert = true
        }
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: price as NSDecimalNumber) ?? "€\(price)"
    }
}

// MARK: - User: Browse Trainers for Video Review

/// User sieht alle Trainer, die Video-Reviews anbieten
struct VideoReviewTrainerListView: View {
    @StateObject private var reviewManager = VideoReviewManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if reviewManager.trainersAcceptingSubmissions().isEmpty {
                    ContentUnavailableView(
                        "Keine Trainer verfügbar",
                        systemImage: "video.slash",
                        description: Text(T("Aktuell bietet kein Trainer Video-Reviews an."))
                    )
                } else {
                    List(reviewManager.trainersAcceptingSubmissions()) { trainer in
                        NavigationLink {
                            VideoReviewBookingView(trainer: trainer)
                        } label: {
                            TrainerReviewCard(
                                trainer: trainer,
                                settings: reviewManager.trainerSettings[trainer.id]
                            )
                        }
                    }
                }
            }
            .navigationTitle(T("Video-Review buchen"))
            .task {
                await reviewManager.loadAllTrainerSettings()
            }
        }
    }
}

struct TrainerReviewCard: View {
    let trainer: AppUser
    let settings: TrainerReviewSettings?
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: trainer.profileImageURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }
            .frame(width: 70, height: 70)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trainer.name)
                    .font(.headline)
                
                if let settings = settings {
                    Text("ab \(settings.formattedCoinsPerMinute)/Minute")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    HStack(spacing: 12) {
                        Label("\(settings.minMinutes)-\(settings.maxMinutes) Min", systemImage: "clock")
                        Label("~\(settings.avgDeliveryDays) Tage", systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User: Booking Flow

struct VideoReviewBookingView: View {
    let trainer: AppUser
    @StateObject private var reviewManager = VideoReviewManager.shared
    @StateObject private var coinManager = CoinManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMinutes: Int = 3
    @State private var userNotes: String = ""
    @State private var step: BookingStep = .selectMinutes
    @State private var createdSubmission: VideoSubmission?
    @State private var showVideoUploader = false
    @State private var isProcessing = false
    
    enum BookingStep {
        case selectMinutes
        case payment
        case uploadVideo
        case confirmation
    }
    
    var settings: TrainerReviewSettings? {
        reviewManager.trainerSettings[trainer.id]
    }
    
    var calculatedPrice: Decimal {
        settings?.calculatePrice(minutes: selectedMinutes) ?? 0
    }
    
    var coinAmount: Int {
        coinManager.coinsNeededForVideoReview(priceEUR: calculatedPrice)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            ProgressView(value: Double(step.rawValue), total: 3)
                .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Trainer Header
                    trainerHeader
                    
                    Divider()
                    
                    switch step {
                    case .selectMinutes:
                        minuteSelectionView
                    case .payment:
                        paymentView
                    case .uploadVideo:
                        videoUploadView
                    case .confirmation:
                        confirmationView
                    }
                }
                .padding()
            }
        }
        .navigationTitle(T("Video einreichen"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var trainerHeader: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: trainer.profileImageURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(T("Review von"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(trainer.name)
                    .font(.headline)
            }
            
            Spacer()
            
            if let settings = settings {
                Text(settings.formattedCoinsPerMinute + "/Min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var minuteSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(T("Schritt 1: Minuten wählen"))
                .font(.headline)
            
            if let settings = settings {
                Text(T("Wähle, wie viele Minuten Feedback du erhalten möchtest."))
                    .foregroundColor(.secondary)
                
                // Minute Stepper
                HStack {
                    Button(action: { if selectedMinutes > settings.minMinutes { selectedMinutes -= 1 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(selectedMinutes > settings.minMinutes ? .blue : .gray)
                    }
                    
                    Text("\(selectedMinutes)")
                        .font(.system(size: 48, weight: .bold))
                        .frame(width: 100)
                    
                    Button(action: { if selectedMinutes < settings.maxMinutes { selectedMinutes += 1 } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(selectedMinutes < settings.maxMinutes ? .blue : .gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                Text(T("Minuten Feedback"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                // Notizen
                Text(T("Worauf soll der Trainer achten?"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextEditor(text: $userNotes)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                
                Divider()
                
                // Preis
                HStack {
                    Text(T("Gesamtpreis"))
                        .font(.headline)
                    Spacer()
                    Text("\(coinAmount) Coins")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Lieferzeit
                HStack {
                    Image(systemName: "calendar")
                    Text(T("Geschätzte Lieferzeit: ~%@ Tage", "\(settings.avgDeliveryDays)"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Weiter Button
                Button(action: { step = .payment }) {
                    Text(T("Weiter zur Zahlung"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
        }
    }
    
    private var paymentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(T("Schritt 2: Zahlung"))
                .font(.headline)
            
            // Zusammenfassung
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(T("Trainer:"))
                    Spacer()
                    Text(trainer.name)
                }
                HStack {
                    Text(T("Feedback-Minuten:"))
                    Spacer()
                    Text("\(selectedMinutes) Min")
                }
                Divider()
                HStack {
                    Text(T("Gesamt:"))
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(coinAmount) Coins")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Coins Zahlung
            Button(action: {
                Task { await processPayment() }
            }) {
                HStack {
                    Image(systemName: "bitcoinsign.circle")
                    Text(isProcessing ? "Verarbeite..." : "Mit Coins bezahlen")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentGold)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
            
            Text(T("Coins werden vor dem Upload abgebucht."))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(T("Zurück")) {
                step = .selectMinutes
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var videoUploadView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(T("Schritt 3: Video hochladen"))
                .font(.headline)
            
            if let submission = createdSubmission {
                Text(T("Zahlung erfolgreich! Lade jetzt dein Tanzvideo hoch."))
                    .foregroundColor(.secondary)
                
                // Upload-Limits
                VStack(alignment: .leading, spacing: 4) {
                    Label(T("Max. 500 MB"), systemImage: "doc")
                    Label(T("Max. 10 Minuten"), systemImage: "clock")
                    Label(T("Formate: MP4, MOV"), systemImage: "film")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Video Picker
                VideoPickerButton(submissionId: submission.id) { success in
                    if success {
                        step = .confirmation
                    }
                }
            }
        }
    }
    
    private var confirmationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text(T("Video eingereicht!"))
                .font(.title2)
                .fontWeight(.bold)
            
            if let submission = createdSubmission {
                Text(T("Einreichungsnummer: %@", submission.submissionNumber))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(trainer.name) wird dein Video bearbeiten und dir Feedback geben.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(T("Fertig")) {
                dismiss()
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
    }
    
    private func processPayment() async {
        isProcessing = true
        defer { isProcessing = false }
        
        guard coinManager.canAffordVideoReview(priceEUR: calculatedPrice) else {
            return
        }
        
        // 1. Submission erstellen
        guard let submission = await reviewManager.createSubmission(
            trainerId: trainer.id,
            requestedMinutes: selectedMinutes,
            userNotes: userNotes
        ) else {
            return
        }
        
        createdSubmission = submission
        
        // 2. Coins abbuchen
        let chargeSuccess = await coinManager.chargeVideoReview(
            submissionNumber: submission.submissionNumber,
            coinAmount: coinAmount
        )
        guard chargeSuccess else {
            return
        }
        
        // 3. Nach erfolgreicher Zahlung markieren
        let paymentSuccess = await reviewManager.markAsPaid(
            submissionId: submission.id,
            transactionId: "coins_\(Date().timeIntervalSince1970)"
        )
        
        if paymentSuccess {
            step = .uploadVideo
        }
    }
}

extension VideoReviewBookingView.BookingStep: RawRepresentable {
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .selectMinutes
        case 1: self = .payment
        case 2: self = .uploadVideo
        case 3: self = .confirmation
        default: return nil
        }
    }
    
    var rawValue: Int {
        switch self {
        case .selectMinutes: return 0
        case .payment: return 1
        case .uploadVideo: return 2
        case .confirmation: return 3
        }
    }
}

// MARK: - Video Picker

struct VideoPickerButton: View {
    let submissionId: String
    let onComplete: (Bool) -> Void
    
    @StateObject private var reviewManager = VideoReviewManager.shared
    @State private var showPicker = false
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        VStack(spacing: 16) {
            if isUploading {
                VStack {
                    ProgressView(value: uploadProgress)
                    Text("\(Int(uploadProgress * 100))% hochgeladen")
                        .font(.caption)
                }
            } else {
                Button(action: { showPicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 40))
                        Text(T("Video auswählen"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            VideoPicker { url in
                if let url = url {
                    selectedVideoURL = url
                    Task { await uploadVideo(url) }
                }
            }
        }
    }
    
    private func uploadVideo(_ url: URL) async {
        isUploading = true
        
        let result = await reviewManager.uploadVideo(
            submissionId: submissionId,
            videoURL: url
        ) { progress in
            uploadProgress = progress
        }
        
        isUploading = false
        
        switch result {
        case .success:
            onComplete(true)
        case .failure(let error):
            print("Upload failed: \(error)")
            onComplete(false)
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    let onSelect: (URL?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (URL?) -> Void
        
        init(onSelect: @escaping (URL?) -> Void) {
            self.onSelect = onSelect
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                onSelect(nil)
                return
            }
            
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    DispatchQueue.main.async { self.onSelect(nil) }
                    return
                }
                
                // Copy to temp location
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                
                DispatchQueue.main.async { self.onSelect(tempURL) }
            }
        }
    }
}

// MARK: - User: My Submissions List

struct MyVideoSubmissionsView: View {
    @StateObject private var reviewManager = VideoReviewManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if let user = UserManager.shared.currentUser {
                    let submissions = reviewManager.submissionsForUser(user.id)
                    
                    if submissions.isEmpty {
                        ContentUnavailableView(
                            "Keine Einreichungen",
                            systemImage: "video",
                            description: Text(T("Du hast noch kein Video zur Bewertung eingereicht."))
                        )
                    } else {
                        List(submissions) { submission in
                            NavigationLink {
                                VideoSubmissionDetailView(submission: submission)
                            } label: {
                                VideoSubmissionRow(submission: submission)
                            }
                        }
                    }
                }
            }
            .navigationTitle(T("Meine Einreichungen"))
            .task {
                if let userId = UserManager.shared.currentUser?.id {
                    await reviewManager.loadSubmissionsForUser(userId)
                }
            }
        }
    }
}

struct VideoSubmissionRow: View {
    let submission: VideoSubmission
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(submission.trainerName)
                    .font(.headline)
                Text(submission.submissionNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(submission.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Label(submission.submissionStatus.rawValue, systemImage: submission.submissionStatus.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(submission.submissionStatus.color.opacity(0.2))
                    .foregroundColor(submission.submissionStatus.color)
                    .cornerRadius(8)
                
                Text("\(submission.requestedMinutes) Min • \(submission.formattedCoinPrice)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VideoSubmissionDetailView: View {
    let submission: VideoSubmission
    @StateObject private var reviewManager = VideoReviewManager.shared
    @State private var feedback: ReviewFeedback?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Card
                statusCard
                
                // Submission Details
                detailsCard
                
                // Feedback (wenn vorhanden)
                if submission.submissionStatus == .feedbackDelivered || submission.submissionStatus == .completed {
                    if let feedback = feedback {
                        feedbackCard(feedback)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(submission.submissionNumber)
        .task {
            feedback = await reviewManager.loadFeedback(submissionId: submission.id)
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            Image(systemName: submission.submissionStatus.icon)
                .font(.system(size: 40))
                .foregroundColor(submission.submissionStatus.color)
            
            Text(submission.submissionStatus.rawValue)
                .font(.headline)
            
            if submission.submissionStatus == .feedbackDelivered {
                Text(T("Dein Feedback ist da! 🎉"))
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(submission.submissionStatus.color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(T("Details"))
                .font(.headline)
            
            DetailRow(label: "Trainer", value: submission.trainerName)
            DetailRow(label: "Minuten", value: "\(submission.requestedMinutes)")
            DetailRow(label: "Preis", value: submission.formattedCoinPrice)
            DetailRow(label: "Eingereicht am", value: submission.createdAt.formatted(date: .abbreviated, time: .shortened))
            
            if !submission.userNotes.isEmpty {
                Divider()
                Text(T("Deine Notizen:"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(submission.userNotes)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func feedbackCard(_ feedback: ReviewFeedback) -> some View {
        NavigationLink {
            FeedbackViewerView(submission: submission, feedback: feedback)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Feedback ansehen"))
                        .font(.headline)
                    Text(T("Zeichnungen, Audio & Kommentare"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}

// MARK: - Feedback Viewer (User sieht trainer's feedback)

struct FeedbackViewerView: View {
    let submission: VideoSubmission
    let feedback: ReviewFeedback

    @State private var player: AVPlayer?
    @State private var currentTime: Double = 0
    @State private var showAnnotations = true
    @State private var selectedAudioTrack: AudioTrack?
    @State private var timeObserver: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Video Player mit Annotation Overlay
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                }

                if showAnnotations {
                    AnnotationOverlayView(
                        annotations: feedback.annotations,
                        currentTime: currentTime
                    )
                }
            }

            // Controls
            HStack {
                Toggle("Annotationen", isOn: $showAnnotations)
                    .toggleStyle(.button)
            }
            .padding(.horizontal)

            // Tabs
            TabView {
                // Kommentare
                CommentsTabView(comments: feedback.comments)
                    .tabItem { Label(T("Kommentare"), systemImage: "text.bubble") }

                // Audio-Tracks
                AudioTracksTabView(tracks: feedback.audioTracks)
                    .tabItem { Label(T("Audio"), systemImage: "waveform") }

                // Beispielvideos
                ExampleVideosTabView(videos: feedback.trainerVideos)
                    .tabItem { Label(T("Beispiele"), systemImage: "video") }
            }
        }
        .navigationTitle(T("Feedback"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if player == nil, let url = URL(string: submission.userVideoURL ?? "") {
                let newPlayer = AVPlayer(url: url)
                player = newPlayer
                timeObserver = newPlayer.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                    queue: .main
                ) { time in
                    currentTime = CMTimeGetSeconds(time)
                }
            }
        }
        .onDisappear {
            if let observer = timeObserver, let player = player {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
        }
    }
}

struct AnnotationOverlayView: View {
    let annotations: [VideoAnnotation]
    let currentTime: Double
    
    var visibleAnnotations: [VideoAnnotation] {
        annotations.filter { $0.isVisible(at: currentTime) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(visibleAnnotations) { annotation in
                    AnnotationShapeView(annotation: annotation, size: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct AnnotationShapeView: View {
    let annotation: VideoAnnotation
    let size: CGSize
    
    var body: some View {
        Group {
            switch annotation.type {
            case .text:
                if let text = annotation.data.text,
                   let position = annotation.data.position {
                    Text(text)
                        .font(.caption)
                        .padding(4)
                        .background(Color(hex: annotation.color).opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .position(x: position.x * size.width, y: position.y * size.height)
                }
            case .arrow, .freehand:
                if let points = annotation.data.points, points.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x * size.width, y: points[0].y * size.height))
                        for point in points.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                        }
                    }
                    .stroke(Color(hex: annotation.color), lineWidth: annotation.strokeWidth)
                }
            case .circle:
                if let origin = annotation.data.origin,
                   let annotationSize = annotation.data.size {
                    Circle()
                        .stroke(Color(hex: annotation.color), lineWidth: annotation.strokeWidth)
                        .frame(width: annotationSize.width * size.width, height: annotationSize.height * size.height)
                        .position(x: origin.x * size.width, y: origin.y * size.height)
                }
            case .rectangle:
                if let origin = annotation.data.origin,
                   let annotationSize = annotation.data.size {
                    Rectangle()
                        .stroke(Color(hex: annotation.color), lineWidth: annotation.strokeWidth)
                        .frame(width: annotationSize.width * size.width, height: annotationSize.height * size.height)
                        .position(x: origin.x * size.width, y: origin.y * size.height)
                }
            default:
                EmptyView()
            }
        }
    }
}

struct CommentsTabView: View {
    let comments: ReviewComments
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !comments.summary.isEmpty {
                    CommentSection(title: "Zusammenfassung", icon: "doc.text", content: comments.summary)
                }
                
                if !comments.topMistakes.isEmpty {
                    ListSection(title: "Top Fehler", icon: "exclamationmark.triangle", items: comments.topMistakes, color: .red)
                }
                
                if !comments.topDrills.isEmpty {
                    ListSection(title: "Empfohlene Übungen", icon: "figure.walk", items: comments.topDrills, color: .blue)
                }
                
                if !comments.nextSteps.isEmpty {
                    ListSection(title: "Nächste Schritte", icon: "arrow.right.circle", items: comments.nextSteps, color: .green)
                }
                
                if !comments.additionalNotes.isEmpty {
                    CommentSection(title: "Weitere Hinweise", icon: "note.text", content: comments.additionalNotes)
                }
            }
            .padding()
        }
    }
}

struct CommentSection: View {
    let title: String
    let icon: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            Text(content)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ListSection: View {
    let title: String
    let icon: String
    let items: [String]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text(items[index])
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AudioTracksTabView: View {
    let tracks: [AudioTrack]
    @State private var playingTrackId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if tracks.isEmpty {
                    Text(T("Keine Audio-Kommentare"))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(tracks) { track in
                        AudioTrackRow(track: track, isPlaying: playingTrackId == track.id) {
                            playingTrackId = playingTrackId == track.id ? nil : track.id
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct AudioTrackRow: View {
    let track: AudioTrack
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(track.title ?? T("Audio-Kommentar"))
                        .font(.subheadline)
                    Text(T("Ab %@ • %@s", track.formattedStartTime, "\(Int(track.duration))"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isPlaying ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ExampleVideosTabView: View {
    let videos: [TrainerExampleVideo]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if videos.isEmpty {
                    Text(T("Keine Beispielvideos"))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(videos) { video in
                        ExampleVideoRow(video: video)
                    }
                }
            }
            .padding()
        }
    }
}

struct ExampleVideoRow: View {
    let video: TrainerExampleVideo
    @State private var showPlayer = false
    
    var body: some View {
        Button(action: { showPlayer = true }) {
            HStack {
                Image(systemName: "video.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading) {
                    Text(video.title)
                        .font(.subheadline)
                    if let timestamp = video.relatedTimestamp {
                        Text(T("Zu Zeitpunkt %@", formatTime(timestamp)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.fill")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPlayer) {
            if let url = URL(string: video.url) {
                VideoPlayer(player: AVPlayer(url: url))
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
