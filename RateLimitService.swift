//
//  RateLimitService.swift
//  Tanzen mit Tatiana Drexler
//
//  Einfacher Rate-Limiter für Login-Versuche
//

import Foundation
import SwiftUI
import Combine

@MainActor
class RateLimitService: ObservableObject {
    static let shared = RateLimitService()
    
    @Published var failedAttempts: Int = 0
    @Published var isLocked: Bool = false
    @Published var lockoutEndTime: Date? = nil
    
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 60
    
    private let failedAttemptsKey = "ratelimit_failed_attempts"
    private let lockoutEndTimeKey = "ratelimit_lockout_end"
    
    private init() {
        loadState()
    }
    
    private func loadState() {
        failedAttempts = UserDefaults.standard.integer(forKey: failedAttemptsKey)
        
        if let endTime = UserDefaults.standard.object(forKey: lockoutEndTimeKey) as? Date {
            if Date() < endTime {
                lockoutEndTime = endTime
                isLocked = true
            } else {
                resetAttempts()
            }
        }
    }
    
    private func saveState() {
        UserDefaults.standard.set(failedAttempts, forKey: failedAttemptsKey)
        if let endTime = lockoutEndTime {
            UserDefaults.standard.set(endTime, forKey: lockoutEndTimeKey)
        }
    }
    
    var canAttemptLogin: Bool {
        if isLocked, let endTime = lockoutEndTime {
            if Date() >= endTime {
                resetAttempts()
                return true
            }
            return false
        }
        return true
    }
    
    var remainingLockoutSeconds: Int {
        guard let endTime = lockoutEndTime else { return 0 }
        return max(0, Int(endTime.timeIntervalSinceNow))
    }
    
    func recordFailedAttempt() {
        failedAttempts += 1
        
        if failedAttempts >= maxAttempts {
            lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
            isLocked = true
        }
        
        saveState()
    }
    
    func recordSuccessfulLogin() {
        resetAttempts()
    }
    
    func resetAttempts() {
        failedAttempts = 0
        isLocked = false
        lockoutEndTime = nil
        UserDefaults.standard.removeObject(forKey: failedAttemptsKey)
        UserDefaults.standard.removeObject(forKey: lockoutEndTimeKey)
    }
    
    var lockoutMessage: String {
        let seconds = remainingLockoutSeconds
        if seconds > 0 {
            return "Zu viele Fehlversuche. Bitte warte \(seconds) Sekunden."
        }
        return ""
    }
}
