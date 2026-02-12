//
//  VideoReviewModels.swift
//  Tanzen mit Tatiana Drexler
//
//  Datenmodelle für Video-Einreichungen und Trainer-Reviews
//

import Foundation
import SwiftUI
import PencilKit

// MARK: - Trainer Review Settings (Admin-konfigurierbar)

/// Einstellungen für Video-Reviews pro Trainer (nur Admin darf Preise ändern)
struct TrainerReviewSettings: Codable, Identifiable {
    var id: String { trainerId }
    let trainerId: String
    var acceptsVideoSubmissions: Bool
    var reviewPricePerMinute: Decimal
    var minMinutes: Int
    var maxMinutes: Int
    var avgDeliveryDays: Int
    var description: String
    var updatedAt: Date
    var updatedBy: String? // Admin-ID
    
    init(
        trainerId: String,
        acceptsVideoSubmissions: Bool = false,
        reviewPricePerMinute: Decimal = 3.50,
        minMinutes: Int = 1,
        maxMinutes: Int = 10,
        avgDeliveryDays: Int = 5,
        description: String = "",
        updatedAt: Date = Date(),
        updatedBy: String? = nil
    ) {
        self.trainerId = trainerId
        self.acceptsVideoSubmissions = acceptsVideoSubmissions
        self.reviewPricePerMinute = reviewPricePerMinute
        self.minMinutes = minMinutes
        self.maxMinutes = maxMinutes
        self.avgDeliveryDays = avgDeliveryDays
        self.description = description
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
    }
    
    /// Berechnet den Preis für eine bestimmte Minutenzahl
    func calculatePrice(minutes: Int) -> Decimal {
        let clampedMinutes = max(minMinutes, min(maxMinutes, minutes))
        return Decimal(clampedMinutes) * reviewPricePerMinute
    }
    
    /// Formatierter Preis pro Minute
    var formattedPricePerMinute: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: reviewPricePerMinute as NSDecimalNumber) ?? "€\(reviewPricePerMinute)"
    }

    /// Coins pro Minute (gerundet)
    var coinsPerMinute: Int {
        DanceCoinConfig.coinsForPrice(reviewPricePerMinute)
    }

    var formattedCoinsPerMinute: String {
        "\(coinsPerMinute) Coins"
    }
}

// MARK: - Video Submission Status

/// Status einer Video-Einreichung
enum VideoSubmissionStatus: String, Codable, CaseIterable {
    case draft = "Entwurf"
    case awaitingPayment = "Warte auf Zahlung"
    case paid = "Bezahlt"
    case uploading = "Video wird hochgeladen"
    case submitted = "Eingereicht"
    case inReview = "In Bearbeitung"
    case feedbackDelivered = "Feedback bereit"
    case completed = "Abgeschlossen"
    case cancelled = "Abgebrochen"
    case refunded = "Erstattet"
    
    var icon: String {
        switch self {
        case .draft: return "doc"
        case .awaitingPayment: return "creditcard"
        case .paid: return "checkmark.circle"
        case .uploading: return "arrow.up.circle"
        case .submitted: return "paperplane"
        case .inReview: return "eye"
        case .feedbackDelivered: return "envelope.badge"
        case .completed: return "checkmark.seal"
        case .cancelled: return "xmark.circle"
        case .refunded: return "arrow.uturn.left.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .awaitingPayment: return .orange
        case .paid: return .blue
        case .uploading: return .purple
        case .submitted: return .cyan
        case .inReview: return .yellow
        case .feedbackDelivered: return .green
        case .completed: return .green
        case .cancelled: return .red
        case .refunded: return .red
        }
    }
    
    /// Erlaubte Übergänge
    func canTransitionTo(_ newStatus: VideoSubmissionStatus) -> Bool {
        switch self {
        case .draft:
            return [.awaitingPayment, .cancelled].contains(newStatus)
        case .awaitingPayment:
            return [.paid, .cancelled].contains(newStatus)
        case .paid:
            return [.uploading, .cancelled, .refunded].contains(newStatus)
        case .uploading:
            return [.submitted, .paid].contains(newStatus) // paid = retry
        case .submitted:
            return [.inReview, .cancelled, .refunded].contains(newStatus)
        case .inReview:
            return [.feedbackDelivered, .cancelled, .refunded].contains(newStatus)
        case .feedbackDelivered:
            return [.completed].contains(newStatus)
        case .completed, .cancelled, .refunded:
            return false
        }
    }
}

/// Zahlungsstatus
enum VideoPaymentStatus: String, Codable, CaseIterable {
    case pending = "Ausstehend"
    case processing = "In Bearbeitung"
    case completed = "Abgeschlossen"
    case failed = "Fehlgeschlagen"
    case refunded = "Erstattet"
}

// MARK: - Video Submission

/// Eine Video-Einreichung eines Nutzers an einen Trainer
struct VideoSubmission: Codable, Identifiable {
    let id: String
    let userId: String
    let userName: String
    let userEmail: String
    let trainerId: String
    let trainerName: String
    
    // Buchungsdetails
    var requestedMinutes: Int
    var calculatedPrice: Decimal
    var currency: String
    
    // Status
    var submissionStatus: VideoSubmissionStatus
    var paymentStatus: VideoPaymentStatus
    
    // Video-Daten
    var userVideoURL: String?
    var userVideoDurationSeconds: Double?
    var userVideoSizeBytes: Int64?
    var userNotes: String
    
    // In-App Purchase
    var storeKitProductId: String?
    var storeKitTransactionId: String?
    
    // Zeitstempel
    let createdAt: Date
    var paidAt: Date?
    var uploadedAt: Date?
    var submittedAt: Date?
    var reviewStartedAt: Date?
    var deliveredAt: Date?
    var completedAt: Date?
    
    // Feedback-Referenz
    var feedbackId: String?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        userName: String,
        userEmail: String,
        trainerId: String,
        trainerName: String,
        requestedMinutes: Int,
        reviewPricePerMinute: Decimal,
        userNotes: String = ""
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userEmail = userEmail
        self.trainerId = trainerId
        self.trainerName = trainerName
        self.requestedMinutes = requestedMinutes
        self.calculatedPrice = Decimal(requestedMinutes) * reviewPricePerMinute
        self.currency = "EUR"
        self.submissionStatus = .draft
        self.paymentStatus = .pending
        self.userNotes = userNotes
        self.createdAt = Date()
    }
    
    /// Formatierter Preis
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: calculatedPrice as NSDecimalNumber) ?? "€\(calculatedPrice)"
    }

    var formattedCoinPrice: String {
        let coins = DanceCoinConfig.coinsForPrice(calculatedPrice)
        return "\(coins) Coins"
    }
    
    /// Submission-Nummer für Anzeige
    var submissionNumber: String {
        let year = Calendar.current.component(.year, from: createdAt)
        return "VR-\(year)-\(id.prefix(6).uppercased())"
    }
}

// MARK: - Review Feedback

/// Feedback eines Trainers zu einer Video-Einreichung
struct ReviewFeedback: Codable, Identifiable {
    let id: String
    let submissionId: String
    let trainerId: String
    
    // Annotationen (zeitbasiert)
    var annotations: [VideoAnnotation]
    
    // Audio-Kommentare
    var audioTracks: [AudioTrack]
    
    // Trainer-Beispielvideos
    var trainerVideos: [TrainerExampleVideo]
    
    // Text-Kommentare
    var comments: ReviewComments
    
    // Metadaten
    let createdAt: Date
    var updatedAt: Date
    var isDraft: Bool
    var deliveredAt: Date?
    
    init(
        id: String = UUID().uuidString,
        submissionId: String,
        trainerId: String
    ) {
        self.id = id
        self.submissionId = submissionId
        self.trainerId = trainerId
        self.annotations = []
        self.audioTracks = []
        self.trainerVideos = []
        self.comments = ReviewComments()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDraft = true
    }
}

// MARK: - Video Annotation

/// Zeitbasierte Annotation/Zeichnung auf dem Video
struct VideoAnnotation: Codable, Identifiable {
    let id: String
    var type: AnnotationType
    var startTime: Double // Sekunden
    var endTime: Double? // nil = persistent
    var data: AnnotationData
    var color: String // Hex
    var strokeWidth: CGFloat
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        type: AnnotationType,
        startTime: Double,
        endTime: Double? = nil,
        data: AnnotationData,
        color: String = "#FFD700",
        strokeWidth: CGFloat = 3.0
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.data = data
        self.color = color
        self.strokeWidth = strokeWidth
        self.createdAt = Date()
    }
    
    /// Ist diese Annotation zu einem bestimmten Zeitpunkt sichtbar?
    func isVisible(at time: Double) -> Bool {
        if let endTime = endTime {
            return time >= startTime && time <= endTime
        }
        return time >= startTime // Persistent ab startTime
    }
}

/// Typ der Annotation
enum AnnotationType: String, Codable, CaseIterable {
    case freehand = "Freihand"
    case arrow = "Pfeil"
    case circle = "Kreis"
    case rectangle = "Rechteck"
    case highlight = "Highlight"
    case text = "Text"
    case marker = "Marker"
    
    var icon: String {
        switch self {
        case .freehand: return "pencil.tip"
        case .arrow: return "arrow.right"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .highlight: return "highlighter"
        case .text: return "textformat"
        case .marker: return "mappin"
        }
    }
}

/// Daten einer Annotation (Punkte, Text, etc.)
struct AnnotationData: Codable {
    // Für Freihand/Pfeil
    var points: [CGPointCodable]?
    
    // Für Kreis/Rechteck
    var origin: CGPointCodable?
    var size: CGSizeCodable?
    
    // Für Text/Marker
    var text: String?
    var position: CGPointCodable?
    
    // Für PencilKit (Base64-encoded)
    var pencilKitData: Data?
    
    init(
        points: [CGPoint]? = nil,
        origin: CGPoint? = nil,
        size: CGSize? = nil,
        text: String? = nil,
        position: CGPoint? = nil,
        pencilKitData: Data? = nil
    ) {
        self.points = points?.map { CGPointCodable($0) }
        self.origin = origin.map { CGPointCodable($0) }
        self.size = size.map { CGSizeCodable($0) }
        self.text = text
        self.position = position.map { CGPointCodable($0) }
        self.pencilKitData = pencilKitData
    }
}

/// Codable wrapper für CGPoint
struct CGPointCodable: Codable {
    var x: CGFloat
    var y: CGFloat
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

/// Codable wrapper für CGSize
struct CGSizeCodable: Codable {
    var width: CGFloat
    var height: CGFloat
    
    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }
    
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - Audio Track

/// Audio-Kommentar des Trainers
struct AudioTrack: Codable, Identifiable {
    let id: String
    var url: String
    var startTime: Double // Sekunden im Video
    var duration: Double // Dauer des Audios
    var transcript: String? // Optional: Transkript
    var title: String?
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        url: String,
        startTime: Double,
        duration: Double,
        transcript: String? = nil,
        title: String? = nil
    ) {
        self.id = id
        self.url = url
        self.startTime = startTime
        self.duration = duration
        self.transcript = transcript
        self.title = title
        self.createdAt = Date()
    }
    
    /// Formatierte Startzeit
    var formattedStartTime: String {
        let minutes = Int(startTime) / 60
        let seconds = Int(startTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Trainer Example Video

/// Beispielvideo des Trainers zur Korrektur
struct TrainerExampleVideo: Codable, Identifiable {
    let id: String
    var url: String
    var title: String
    var description: String?
    var relatedTimestamp: Double? // Bezieht sich auf diese Stelle im User-Video
    var durationSeconds: Double?
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        url: String,
        title: String,
        description: String? = nil,
        relatedTimestamp: Double? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.description = description
        self.relatedTimestamp = relatedTimestamp
        self.durationSeconds = durationSeconds
        self.createdAt = Date()
    }
}

// MARK: - Review Comments

/// Strukturierte Text-Kommentare
struct ReviewComments: Codable {
    var summary: String
    var topMistakes: [String]
    var topDrills: [String]
    var nextSteps: [String]
    var additionalNotes: String
    
    init(
        summary: String = "",
        topMistakes: [String] = [],
        topDrills: [String] = [],
        nextSteps: [String] = [],
        additionalNotes: String = ""
    ) {
        self.summary = summary
        self.topMistakes = topMistakes
        self.topDrills = topDrills
        self.nextSteps = nextSteps
        self.additionalNotes = additionalNotes
    }
    
    /// Hat der Trainer irgendwelche Kommentare geschrieben?
    var hasContent: Bool {
        !summary.isEmpty ||
        !topMistakes.isEmpty ||
        !topDrills.isEmpty ||
        !nextSteps.isEmpty ||
        !additionalNotes.isEmpty
    }
}

// MARK: - Video Upload Progress

/// Fortschritt beim Video-Upload
struct VideoUploadProgress: Identifiable {
    let id: String
    var submissionId: String
    var bytesUploaded: Int64
    var totalBytes: Int64
    var state: UploadState
    var error: String?
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesUploaded) / Double(totalBytes)
    }
    
    var formattedProgress: String {
        let percent = Int(progress * 100)
        return "\(percent)%"
    }
    
    enum UploadState: String {
        case preparing
        case uploading
        case paused
        case completed
        case failed
    }
}

// MARK: - StoreKit Product IDs

/// Product IDs für In-App Purchases (Video Reviews)
enum VideoReviewProduct {
    static let prefix = "com.tanzenmittatiana.videoreview"
    
    /// Generiert eine Product-ID für eine bestimmte Minutenzahl
    static func productId(minutes: Int) -> String {
        "\(prefix).\(minutes)min"
    }
    
    /// Credits-basiertes Modell (alternative)
    static let creditsSmall = "\(prefix).credits.5"   // 5 Credits
    static let creditsMedium = "\(prefix).credits.15" // 15 Credits
    static let creditsLarge = "\(prefix).credits.30"  // 30 Credits
    
    /// 1 Credit = 1 Minute Review
    static let creditValue: Decimal = 1.0
}

// MARK: - Extensions

extension VideoSubmission {
    /// Aktualisiert den Status mit Validierung
    mutating func updateStatus(to newStatus: VideoSubmissionStatus) -> Bool {
        guard submissionStatus.canTransitionTo(newStatus) else {
            return false
        }
        
        submissionStatus = newStatus
        
        // Zeitstempel aktualisieren
        switch newStatus {
        case .paid:
            paidAt = Date()
        case .submitted:
            submittedAt = Date()
        case .inReview:
            reviewStartedAt = Date()
        case .feedbackDelivered:
            deliveredAt = Date()
        case .completed:
            completedAt = Date()
        default:
            break
        }
        
        return true
    }
}

// MARK: - Video Validation

/// Validierungsregeln für Video-Uploads
struct VideoUploadLimits {
    static let maxFileSizeBytes: Int64 = 500 * 1024 * 1024 // 500 MB
    static let maxDurationSeconds: Double = 600 // 10 Minuten
    static let allowedFormats = ["mp4", "mov", "m4v"]
    static let minDurationSeconds: Double = 10 // Mindestens 10 Sekunden
    
    static func validate(fileSize: Int64, duration: Double, format: String) -> VideoValidationResult {
        var errors: [String] = []
        
        if fileSize > maxFileSizeBytes {
            let maxMB = maxFileSizeBytes / (1024 * 1024)
            errors.append("Video ist zu groß (max. \(maxMB) MB)")
        }
        
        if duration > maxDurationSeconds {
            let maxMin = Int(maxDurationSeconds / 60)
            errors.append("Video ist zu lang (max. \(maxMin) Minuten)")
        }
        
        if duration < minDurationSeconds {
            errors.append("Video ist zu kurz (min. \(Int(minDurationSeconds)) Sekunden)")
        }
        
        let formatLower = format.lowercased()
        if !allowedFormats.contains(formatLower) {
            errors.append("Ungültiges Format. Erlaubt: \(allowedFormats.joined(separator: ", "))")
        }
        
        return VideoValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

struct VideoValidationResult {
    let isValid: Bool
    let errors: [String]
}
