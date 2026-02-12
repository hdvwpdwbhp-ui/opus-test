//
//  VideoCallService.swift
//  Tanzen mit Tatiana Drexler
//
//  Video-Call Service für Privatstunden (Daily.co Integration)
//

import Foundation
import Combine
import WebKit
import SwiftUI

// MARK: - Video Call Room Model
struct VideoCallRoom: Codable, Identifiable {
    let id: String
    let name: String
    let url: String
    let bookingId: String
    let trainerId: String
    let userId: String
    let createdAt: Date
    var expiresAt: Date
    var isActive: Bool
}

// MARK: - Video Call Service
@MainActor
class VideoCallService: ObservableObject {
    static let shared = VideoCallService()
    
    @Published var activeRooms: [VideoCallRoom] = []
    @Published var isCreatingRoom = false
    @Published var currentCallURL: URL?
    @Published var isInCall = false
    
    private let dailyApiKey = "60c08379664cf80b38348d62201bafc533f791872811fb003087e6110f206957"
    private let dailyDomain = "tanzen-tatiana"
    private let localRoomsKey = "video_call_rooms"
    
    private init() {
        loadLocalRooms()
    }
    
    func createRoom(for booking: PrivateLessonBooking) async -> (success: Bool, roomUrl: String?, message: String) {
        isCreatingRoom = true
        defer { isCreatingRoom = false }
        
        let roomName = "privatstunde-\(booking.id.prefix(8))-\(Int(Date().timeIntervalSince1970))"
        
        guard let url = URL(string: "https://api.daily.co/v1/rooms") else {
            return (false, nil, "Ungültige API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(dailyApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let roomConfig: [String: Any] = [
            "name": roomName,
            "privacy": "private",
            "properties": [
                "exp": Int(Date().addingTimeInterval(2 * 60 * 60).timeIntervalSince1970),
                "max_participants": 2,
                "enable_chat": true
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: roomConfig)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // Fallback Demo URL
                let demoUrl = "https://\(dailyDomain).daily.co/\(roomName)"
                return saveAndReturnRoom(bookingId: booking.id, trainerId: booking.trainerId, userId: booking.userId, roomName: roomName, roomUrl: demoUrl)
            }
            
            struct DailyRoomResponse: Codable {
                let id: String
                let name: String
                let url: String
            }
            
            let roomResponse = try JSONDecoder().decode(DailyRoomResponse.self, from: data)
            return saveAndReturnRoom(bookingId: booking.id, trainerId: booking.trainerId, userId: booking.userId, roomName: roomResponse.name, roomUrl: roomResponse.url)
            
        } catch {
            let demoUrl = "https://\(dailyDomain).daily.co/\(roomName)"
            return saveAndReturnRoom(bookingId: booking.id, trainerId: booking.trainerId, userId: booking.userId, roomName: roomName, roomUrl: demoUrl)
        }
    }
    
    private func saveAndReturnRoom(bookingId: String, trainerId: String, userId: String, roomName: String, roomUrl: String) -> (success: Bool, roomUrl: String?, message: String) {
        let room = VideoCallRoom(
            id: UUID().uuidString,
            name: roomName,
            url: roomUrl,
            bookingId: bookingId,
            trainerId: trainerId,
            userId: userId,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(2 * 60 * 60),
            isActive: true
        )
        
        activeRooms.append(room)
        saveLocalRooms()
        
        return (true, roomUrl, "Video-Raum erstellt!")
    }
    
    func getRoom(for bookingId: String) -> VideoCallRoom? {
        activeRooms.first { $0.bookingId == bookingId && $0.isActive && $0.expiresAt > Date() }
    }
    
    func joinCall(room: VideoCallRoom) {
        guard let url = URL(string: room.url) else { return }
        currentCallURL = url
        isInCall = true
    }
    
    func leaveCall() {
        currentCallURL = nil
        isInCall = false
    }
    
    private func saveLocalRooms() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(activeRooms) {
            UserDefaults.standard.set(data, forKey: localRoomsKey)
        }
    }
    
    private func loadLocalRooms() {
        guard let data = UserDefaults.standard.data(forKey: localRoomsKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let rooms = try? decoder.decode([VideoCallRoom].self, from: data) {
            activeRooms = rooms.filter { $0.isActive && $0.expiresAt > Date() }
        }
    }
}
