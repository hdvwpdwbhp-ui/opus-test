//
//  LiveClassLogic.swift
//  Tanzen mit Tatiana Drexler
//
//  Business logic helpers for live classes
//

import Foundation

enum LiveClassJoinState: Equatable {
    case beforeStart
    case duringGrace
    case closed
}

struct LiveClassLogic {
    static func joinState(now: Date, startTime: Date, cutoffMinutesAfterStart: Int) -> LiveClassJoinState {
        if now < startTime { return .beforeStart }
        let cutoff = startTime.addingTimeInterval(TimeInterval(cutoffMinutesAfterStart) * 60)
        if now <= cutoff { return .duringGrace }
        return .closed
    }

    static func autoCancelTime(startTime: Date, hoursBeforeStart: Int) -> Date {
        startTime.addingTimeInterval(TimeInterval(-hoursBeforeStart) * 3600)
    }
}
