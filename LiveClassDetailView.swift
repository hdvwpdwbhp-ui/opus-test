//
//  LiveClassDetailView.swift
//  Tanzen mit Tatiana Drexler
//

import SwiftUI

struct LiveClassDetailView: View {
    let event: LiveClassEvent
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showJoinWarning = false
    @State private var isBooking = false
    @State private var showJoin = false

    private var booking: LiveClassBooking? {
        liveManager.myBookings.first { $0.eventId == event.id && $0.status == .paid }
    }
    
    /// Admin und Support haben kostenlosen Zugang
    private var hasFreeAccess: Bool {
        guard let user = userManager.currentUser else { return false }
        return user.group == .admin || user.group == .support
    }
    
    /// Trainer hat Zugang zu seinen eigenen Events
    private var isTrainerOfEvent: Bool {
        guard let userId = userManager.currentUser?.id else { return false }
        return event.trainerId == userId
    }
    
    /// Kann beitreten wenn gebucht, Admin/Support oder eigener Event
    private var canJoin: Bool {
        booking != nil || hasFreeAccess || isTrainerOfEvent
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.title2)
                Text(event.description)
                    .foregroundColor(.secondary)
                HStack {
                    Label(event.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    Spacer()
                    if hasFreeAccess {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text(T("Kostenloser Zugang"))
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("\(event.coinPrice) Coins")
                            .font(.headline)
                    }
                }
                Text(T("Teilnehmer: %@/%@ • Mindestteilnehmer: %@", "\(event.confirmedParticipants)", "\(event.maxParticipants)", "\(event.minParticipants)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Info für Admin/Support
            if hasFreeAccess && booking == nil {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text(T("Als %@ hast du kostenlosen Zugang zu allen Livestreams.", userManager.currentUser?.group.displayName ?? "Admin"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            if canJoin {
                Button(T("Beitreten")) {
                    handleJoinTap()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(isBooking ? "Buchung..." : "Mit Coins buchen") {
                    Task { await book() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBooking)
            }
        }
        .padding()
        .navigationTitle(T("Livestream"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(T("Kurs läuft bereits"), isPresented: $showJoinWarning) {
            Button(T("Abbrechen"), role: .cancel) {}
            Button(T("Trotzdem beitreten")) { showJoin = true }
        } message: {
            Text(T("Der Kurs hat schon begonnen. Möchtest du trotzdem beitreten?"))
        }
        .fullScreenCover(isPresented: $showJoin) {
            LiveClassJoinView(eventId: event.id)
        }
    }

    private func handleJoinTap() {
        let state = LiveClassLogic.joinState(now: Date(), startTime: event.startTime, cutoffMinutesAfterStart: event.joinCutoffMinutesAfterStart)
        switch state {
        case .beforeStart:
            showJoin = true
        case .duringGrace:
            showJoinWarning = true
        case .closed:
            break
        }
    }

    private func book() async {
        isBooking = true
        defer { isBooking = false }
        _ = await liveManager.bookEvent(eventId: event.id)
    }
}
