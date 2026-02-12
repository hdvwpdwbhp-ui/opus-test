//
//  LiveClassesListView.swift
//  Tanzen mit Tatiana Drexler
//
//  User-facing list of live classes
//

import SwiftUI

struct LiveClassesListView: View {
    @StateObject private var liveManager = LiveClassManager.shared
    @StateObject private var userManager = UserManager.shared

    private var upcomingEvents: [LiveClassEvent] {
        liveManager.events.filter { $0.status == .scheduled || $0.status == .live }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        NavigationStack {
            List {
                if upcomingEvents.isEmpty {
                    ContentUnavailableView("Keine Livestreams", systemImage: "dot.radiowaves.left.and.right")
                } else {
                    ForEach(upcomingEvents) { event in
                        NavigationLink {
                            LiveClassDetailView(event: event)
                        } label: {
                            LiveClassCard(event: event)
                        }
                    }
                }
            }
            .navigationTitle(T("Livestreams"))
            .task {
                liveManager.startListeningToEvents()
                if let userId = userManager.currentUser?.id {
                    liveManager.startListeningToBookings(userId: userId)
                }
            }
        }
    }
}

struct LiveClassCard: View {
    let event: LiveClassEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.headline)
            Text(event.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            HStack {
                Label(event.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                Spacer()
                Text("\(event.coinPrice) Coins")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 6)
    }
}
