//
//  LiveClassModels.swift
//  Tanzen mit Tatiana Drexler
//
//  Livestream-Gruppenstunden Modelle
//

import Foundation

enum LiveClassRecurrenceRule: String, Codable, CaseIterable {
    case none
    case weekly
    case custom
}

enum LiveClassLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

enum LiveClassVisibility: String, Codable, CaseIterable {
    case `public`
    case followersOnly
    case linkOnly
}

enum LiveClassStatus: String, Codable, CaseIterable {
    case scheduled
    case live
    case ended
    case cancelledByMinNotMet
    case cancelledByTrainer
    case cancelledByAdmin
}

enum LiveClassStreamProvider: String, Codable, CaseIterable {
    case agora
    case muxLive
    case webRTC
    case external
}

struct LiveClassTemplate: Codable, Identifiable {
    let id: String
    let trainerId: String
    var title: String
    var description: String
    var level: LiveClassLevel
    var styleTags: [String]
    var durationMinutes: Int
    var timezone: String
    var recurrenceRule: LiveClassRecurrenceRule
    var defaultMinParticipants: Int
    var defaultMaxParticipants: Int
    var defaultCoinPrice: Int?
    let createdAt: Date
    var updatedAt: Date

    static func create(trainerId: String) -> LiveClassTemplate {
        LiveClassTemplate(
            id: UUID().uuidString,
            trainerId: trainerId,
            title: "",
            description: "",
            level: .beginner,
            styleTags: [],
            durationMinutes: 60,
            timezone: TimeZone.current.identifier,
            recurrenceRule: .none,
            defaultMinParticipants: 3,
            defaultMaxParticipants: 20,
            defaultCoinPrice: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

struct LiveClassEvent: Codable, Identifiable {
    let id: String
    var templateId: String?
    let trainerId: String
    var title: String
    var description: String
    var level: LiveClassLevel
    var styleTags: [String]
    var startTime: Date
    var endTime: Date
    var minParticipants: Int
    var maxParticipants: Int
    var confirmedParticipants: Int
    var coinPrice: Int
    var joinCutoffMinutesAfterStart: Int
    var autoCancelHoursBeforeStart: Int
    var status: LiveClassStatus
    var visibility: LiveClassVisibility
    var streamProvider: LiveClassStreamProvider
    var streamJoinInfo: String?
    let createdAt: Date
    var updatedAt: Date

    var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    static func create(trainerId: String) -> LiveClassEvent {
        LiveClassEvent(
            id: UUID().uuidString,
            templateId: nil,
            trainerId: trainerId,
            title: "",
            description: "",
            level: .beginner,
            styleTags: [],
            startTime: Date().addingTimeInterval(3600),
            endTime: Date().addingTimeInterval(7200),
            minParticipants: 3,
            maxParticipants: 20,
            confirmedParticipants: 0,
            coinPrice: 120,
            joinCutoffMinutesAfterStart: 45,
            autoCancelHoursBeforeStart: 5,
            status: .scheduled,
            visibility: .public,
            streamProvider: .agora,
            streamJoinInfo: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

enum LiveClassBookingStatus: String, Codable, CaseIterable {
    case reserved
    case paid
    case refunded
    case cancelled
}

struct LiveClassBooking: Codable, Identifiable {
    let id: String
    let eventId: String
    let userId: String
    var status: LiveClassBookingStatus
    var coinAmountCharged: Int
    var paidAt: Date?
    var refundedAt: Date?
    var joinedAt: Date?
    let createdAt: Date

    static func create(eventId: String, userId: String, coinAmount: Int) -> LiveClassBooking {
        LiveClassBooking(
            id: UUID().uuidString,
            eventId: eventId,
            userId: userId,
            status: .reserved,
            coinAmountCharged: coinAmount,
            paidAt: nil,
            refundedAt: nil,
            joinedAt: nil,
            createdAt: Date()
        )
    }
}

struct LiveClassTrainerSettings: Codable, Identifiable {
    let id: String // trainerId
    var canHostLiveClasses: Bool
    var priceMode: LiveClassPriceMode
    var minCoinPrice: Int
    var maxCoinPrice: Int
    var defaultCoinPrice: Int
    var minParticipantsLimit: Int
    var maxParticipantsLimit: Int
    var maxDurationMinutes: Int
    var updatedAt: Date

    static func defaults(trainerId: String) -> LiveClassTrainerSettings {
        LiveClassTrainerSettings(
            id: trainerId,
            canHostLiveClasses: false,
            priceMode: .adminSetsPerEvent,
            minCoinPrice: 60,
            maxCoinPrice: 300,
            defaultCoinPrice: 120,
            minParticipantsLimit: 3,
            maxParticipantsLimit: 20,
            maxDurationMinutes: 120,
            updatedAt: Date()
        )
    }
}

enum LiveClassPriceMode: String, Codable, CaseIterable {
    case adminSetsPerEvent
    case trainerChoosesWithinRange
    case fixedPerTrainer
}

struct LiveClassGlobalSettings: Codable {
    var autoCancelHoursBeforeStart: Int
    var joinCutoffMinutesAfterStart: Int
    var maxParticipantsDefault: Int
    var maxDurationMinutesDefault: Int
    var updatedAt: Date

    static func defaults() -> LiveClassGlobalSettings {
        LiveClassGlobalSettings(
            autoCancelHoursBeforeStart: 5,
            joinCutoffMinutesAfterStart: 45,
            maxParticipantsDefault: 20,
            maxDurationMinutesDefault: 120,
            updatedAt: Date()
        )
    }
}

struct LiveClassChatMessage: Codable, Identifiable {
    let id: String
    let eventId: String
    let userId: String
    let userName: String
    let userGroup: UserGroup
    let content: String
    let createdAt: Date
    var isDeleted: Bool
    var deletedBy: String?

    static func create(eventId: String, user: AppUser, content: String) -> LiveClassChatMessage {
        LiveClassChatMessage(
            id: UUID().uuidString,
            eventId: eventId,
            userId: user.id,
            userName: user.name,
            userGroup: user.group,
            content: content,
            createdAt: Date(),
            isDeleted: false,
            deletedBy: nil
        )
    }
}

struct LiveClassChatModerationLog: Codable, Identifiable {
    let id: String
    let eventId: String
    let moderatorId: String
    let moderatorGroup: UserGroup
    let action: String
    let targetMessageId: String
    let createdAt: Date
}
