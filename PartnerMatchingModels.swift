import Foundation

struct PartnerProfile: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var displayName: String
    var age: Int?
    var gender: Gender?
    var lookingForGender: Gender?
    var danceStyles: [DanceStyle]
    var skillLevel: SkillLevel
    var bio: String
    var city: String
    var cityLowercased: String
    var isVisible: Bool
    var lastActive: Date
    var profileImageURL: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Erweiterte Felder für Tanzpartner-Anzeigen
    var photoURLs: [String]          // Bis zu 5 Fotos
    var videoURLs: [String]          // Bis zu 2 Videos
    var height: Int?                 // Größe in cm
    var danceExperienceYears: Int?   // Jahre Tanzerfahrung
    var preferredDays: [DayOfWeek]   // Bevorzugte Trainingstage
    var preferredTimes: [TimeOfDay]  // Bevorzugte Zeiten
    var searchRadius: Int?           // Suchradius in km
    var contactPreference: ContactPreference // Wie kontaktiert werden
    var instagramHandle: String?     // Instagram Username
    var phoneNumber: String?         // Telefonnummer (optional)
    var lookingForType: PartnerType  // Was wird gesucht
    var availableForEvents: Bool     // Für Events/Turniere verfügbar
    var hasOwnStudio: Bool           // Eigener Übungsraum vorhanden
    var headline: String             // Kurze Überschrift für die Anzeige

    enum Gender: String, Codable, CaseIterable {
        case male = "Männlich"
        case female = "Weiblich"
        case other = "Andere"
        case any = "Egal"
    }

    enum SkillLevel: String, Codable, CaseIterable {
        case beginner = "Anfänger"
        case intermediate = "Mittelstufe"
        case advanced = "Fortgeschritten"
        case professional = "Profi"
    }
    
    enum DayOfWeek: String, Codable, CaseIterable {
        case monday = "Montag"
        case tuesday = "Dienstag"
        case wednesday = "Mittwoch"
        case thursday = "Donnerstag"
        case friday = "Freitag"
        case saturday = "Samstag"
        case sunday = "Sonntag"
    }
    
    enum TimeOfDay: String, Codable, CaseIterable {
        case morning = "Morgens (6-12 Uhr)"
        case afternoon = "Nachmittags (12-18 Uhr)"
        case evening = "Abends (18-22 Uhr)"
        case night = "Nachts (22-6 Uhr)"
    }
    
    enum ContactPreference: String, Codable, CaseIterable {
        case appOnly = "Nur in der App"
        case instagram = "Instagram"
        case phone = "Telefon"
        case all = "Alle Wege"
    }
    
    enum PartnerType: String, Codable, CaseIterable {
        case regularPartner = "Fester Tanzpartner"
        case practicePartner = "Übungspartner"
        case eventPartner = "Event-/Turnierpartner"
        case socialDancing = "Social Dancing"
        case any = "Offen für alles"
    }

    static func create(userId: String, name: String) -> PartnerProfile {
        let now = Date()
        return PartnerProfile(
            id: userId,
            userId: userId,
            displayName: name,
            age: nil,
            gender: nil,
            lookingForGender: .any,
            danceStyles: [],
            skillLevel: .beginner,
            bio: "",
            city: "",
            cityLowercased: "",
            isVisible: false,
            lastActive: now,
            profileImageURL: nil,
            createdAt: now,
            updatedAt: now,
            photoURLs: [],
            videoURLs: [],
            height: nil,
            danceExperienceYears: nil,
            preferredDays: [],
            preferredTimes: [],
            searchRadius: 50,
            contactPreference: .appOnly,
            instagramHandle: nil,
            phoneNumber: nil,
            lookingForType: .any,
            availableForEvents: false,
            hasOwnStudio: false,
            headline: ""
        )
    }
}

struct PartnerRequest: Codable, Identifiable, Hashable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String?
    let message: String
    var status: RequestStatus
    let createdAt: Date
    var updatedAt: Date

    enum RequestStatus: String, Codable {
        case pending = "Ausstehend"
        case accepted = "Angenommen"
        case declined = "Abgelehnt"
        case cancelled = "Storniert"
    }
}

struct PartnerMatch: Codable, Identifiable, Hashable {
    let id: String
    let userIds: [String]
    let createdAt: Date
    var lastMessageAt: Date?
}

struct PartnerMatchSummary: Identifiable, Hashable {
    let id: String
    let match: PartnerMatch
    let partner: PartnerProfile
}

struct PartnerMessage: Codable, Identifiable, Hashable {
    let id: String
    let matchId: String
    let senderId: String
    let content: String
    let createdAt: Date
    var readBy: [String]
}

struct PartnerBlock: Codable, Identifiable, Hashable {
    let id: String
    let blockerId: String
    let blockedId: String
    let createdAt: Date
}

struct PartnerReport: Codable, Identifiable, Hashable {
    let id: String
    let reporterId: String
    let reportedUserId: String
    let reason: String
    let details: String
    let createdAt: Date
    var status: ReportStatus

    enum ReportStatus: String, Codable {
        case open = "Offen"
        case reviewed = "Geprüft"
        case closed = "Geschlossen"
    }
}

enum PartnerSortOption: String, CaseIterable, Identifiable {
    case lastActive = "Zuletzt aktiv"
    case newest = "Neueste"
    case ageAscending = "Alter aufsteigend"
    case ageDescending = "Alter absteigend"

    var id: String { rawValue }
}
