//
//  NewsView.swift
//  Tanzen mit Tatiana Drexler
//
//  News-Feed und Benachrichtigungs-Einstellungen
//

import SwiftUI
import UserNotifications

// MARK: - News Feed View
struct NewsFeedView: View {
    @StateObject private var newsletterManager = NewsletterManager.shared
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: TDSpacing.md) {
                // Unread Banner
                if newsletterManager.unreadCount > 0 {
                    unreadBanner
                }
                
                // News Items
                ForEach(newsletterManager.newsItems) { item in
                    NewsCard(item: item)
                }
            }
            .padding()
        }
        .background(TDGradients.mainBackground.ignoresSafeArea())
        .navigationTitle(T("Neuigkeiten"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "bell.badge")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NotificationSettingsView()
        }
    }
    
    private var unreadBanner: some View {
        HStack {
            Image(systemName: "bell.badge.fill")
                .foregroundColor(Color.accentGold)
            
            Text("\(newsletterManager.unreadCount) neue Nachrichten")
                .font(TDTypography.subheadline)
            
            Spacer()
            
            Button(T("Alle gelesen")) {
                newsletterManager.markAllAsRead()
            }
            .font(TDTypography.caption1)
            .foregroundColor(Color.accentGold)
        }
        .padding()
        .background(Color.accentGold.opacity(0.1))
        .cornerRadius(TDRadius.md)
    }
}

// MARK: - News Card
struct NewsCard: View {
    let item: NewsItem
    @StateObject private var newsletterManager = NewsletterManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: TDSpacing.sm) {
            // Header
            HStack {
                // Type Badge
                Text(item.type.rawValue)
                    .font(TDTypography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor)
                    .cornerRadius(4)
                
                Spacer()
                
                // Unread Indicator
                if !item.isRead {
                    Circle()
                        .fill(Color.accentGold)
                        .frame(width: 8, height: 8)
                }
                
                // Time
                Text(item.createdAt, style: .relative)
                    .font(TDTypography.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(item.title)
                .font(TDTypography.headline)
                .foregroundColor(item.isRead ? .secondary : .primary)
            
            // Body
            Text(item.body)
                .font(TDTypography.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Action Button (if has link)
            if item.linkType != nil {
                Button {
                    newsletterManager.markAsRead(item.id)
                    // Navigate based on link type
                } label: {
                    HStack {
                        Text(T("Mehr erfahren"))
                        Image(systemName: "arrow.right")
                    }
                    .font(TDTypography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(Color.accentGold)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(TDRadius.md)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onTapGesture {
            newsletterManager.markAsRead(item.id)
        }
    }
    
    var badgeColor: Color {
        switch item.type {
        case .newCourse: return .blue
        case .tip: return .green
        case .sale: return .red
        case .update: return .purple
        case .event: return .orange
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @StateObject private var newsletterManager = NewsletterManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var prefs = NotificationPreferences()
    @State private var hasPermission = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Permission Status
                Section {
                    HStack {
                        Image(systemName: hasPermission ? "bell.badge.fill" : "bell.slash.fill")
                            .foregroundColor(hasPermission ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text(hasPermission ? "Benachrichtigungen aktiviert" : "Benachrichtigungen deaktiviert")
                                .font(TDTypography.subheadline)
                            
                            if !hasPermission {
                                Text(T("Aktiviere Benachrichtigungen in den Einstellungen"))
                                    .font(TDTypography.caption1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !hasPermission {
                            Button(T("Aktivieren")) {
                                openSettings()
                            }
                            .font(TDTypography.caption1)
                        }
                    }
                }
                
                // Content Notifications
                Section(T("Inhalte")) {
                    Toggle("Neue Kurse", isOn: $prefs.newCourses)
                    Toggle("Wöchentliche Tipps", isOn: $prefs.weeklyTips)
                    Toggle("Angebote & Rabatte", isOn: $prefs.salesAndOffers)
                }
                
                // Learning Notifications
                Section(T("Lernen")) {
                    Toggle("Lern-Erinnerungen", isOn: $prefs.learningReminders)
                    
                    if prefs.learningReminders {
                        DatePicker("Uhrzeit", selection: $prefs.reminderTime, displayedComponents: .hourAndMinute)
                        
                        // Day Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(T("Tage"))
                                .font(TDTypography.caption1)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach([(1, "So"), (2, "Mo"), (3, "Di"), (4, "Mi"), (5, "Do"), (6, "Fr"), (7, "Sa")], id: \.0) { day, label in
                                    Button {
                                        if prefs.reminderDays.contains(day) {
                                            prefs.reminderDays.remove(day)
                                        } else {
                                            prefs.reminderDays.insert(day)
                                        }
                                    } label: {
                                        Text(label)
                                            .font(TDTypography.caption1)
                                            .fontWeight(prefs.reminderDays.contains(day) ? .semibold : .regular)
                                            .foregroundColor(prefs.reminderDays.contains(day) ? .white : .primary)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(prefs.reminderDays.contains(day) ? Color.accentGold : Color.gray.opacity(0.1))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    Toggle("Streak-Erinnerungen", isOn: $prefs.streakReminders)
                    Toggle("Achievement-Benachrichtigungen", isOn: $prefs.achievementUnlocked)
                }
                
                // Social Notifications
                Section(T("Social")) {
                    Toggle("Partner-Anfragen", isOn: $prefs.partnerRequests)
                    Toggle("Privatstunden-Erinnerungen", isOn: $prefs.lessonReminders)
                }
            }
            .navigationTitle(T("Benachrichtigungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(T("Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Speichern")) {
                        newsletterManager.updatePreferences(prefs)
                        dismiss()
                    }
                }
            }
            .onAppear {
                prefs = newsletterManager.preferences
                checkPermission()
            }
        }
    }
    
    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - News Badge (for Tab Bar)
struct NewsBadge: View {
    @StateObject private var newsletterManager = NewsletterManager.shared
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
            
            if newsletterManager.unreadCount > 0 {
                Text("\(min(newsletterManager.unreadCount, 9))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewsFeedView()
    }
}
