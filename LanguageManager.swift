//
//  LanguageManager.swift
//  Tanzen mit Tatiana Drexler
//
//  Verwaltet die Spracheinstellungen der App
//

import Foundation
import SwiftUI
import Combine

// MARK: - Unterstützte Sprachen
enum AppLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    case english = "en"
    case russian = "ru"
    case slovak = "sk"
    case czech = "cs"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .german: return "Deutsch"
        case .english: return "English"
        case .russian: return "Русский"
        case .slovak: return "Slovenčina"
        case .czech: return "Čeština"
        }
    }
    
    var flag: String {
        switch self {
        case .german: return "🇩🇪"
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        case .slovak: return "🇸🇰"
        case .czech: return "🇨🇿"
        }
    }
    
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

// MARK: - Language Manager
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    private let languageKey = "app_language"
    private let hasSelectedLanguageKey = "has_selected_language"
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            UserDefaults.standard.set(true, forKey: hasSelectedLanguageKey)
            updateFormatters()
            objectWillChange.send()
        }
    }
    
    @Published var hasSelectedLanguage: Bool
    
    // MARK: - Formatters (für Datum/Zahlen passend zur Sprache)
    private(set) var dateFormatter: DateFormatter = DateFormatter()
    private(set) var shortDateFormatter: DateFormatter = DateFormatter()
    private(set) var timeFormatter: DateFormatter = DateFormatter()
    private(set) var numberFormatter: NumberFormatter = NumberFormatter()
    private(set) var currencyFormatter: NumberFormatter = NumberFormatter()
    
    private init() {
        // Prüfe ob schon eine Sprache gewählt wurde
        self.hasSelectedLanguage = UserDefaults.standard.bool(forKey: hasSelectedLanguageKey)
        
        // Lade gespeicherte Sprache oder ermittle aus System
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Versuche Systemsprache zu erkennen
            let preferredLanguage = Locale.preferredLanguages.first ?? "de"
            let languageCode = String(preferredLanguage.prefix(2))
            
            self.currentLanguage = AppLanguage(rawValue: languageCode) ?? .german
        }
        
        updateFormatters()
    }
    
    // MARK: - Formatter Updates
    private func updateFormatters() {
        let locale = currentLanguage.locale
        
        // Datum formatieren
        dateFormatter.locale = locale
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        shortDateFormatter.locale = locale
        shortDateFormatter.dateStyle = .short
        shortDateFormatter.timeStyle = .none
        
        timeFormatter.locale = locale
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        // Zahlen formatieren
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .decimal
        
        // Währung formatieren
        currencyFormatter.locale = locale
        currencyFormatter.numberStyle = .currency
    }
    
    // MARK: - Localized Strings
    
    func string(_ key: LocalizedStringKey) -> String {
        return LocalizedStrings.shared.get(key, for: currentLanguage)
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
    
    // MARK: - Formatting Helpers
    
    func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    func formatShortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
    
    func formatNumber(_ number: Double) -> String {
        numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Localized String Keys
enum LocalizedStringKey: String {
    // MARK: - Allgemein
    case appName = "app_name"
    case ok = "ok"
    case cancel = "cancel"
    case save = "save"
    case delete = "delete"
    case edit = "edit"
    case done = "done"
    case back = "back"
    case next = "next"
    case loading = "loading"
    case error = "error"
    case success = "success"
    case warning = "warning"
    case yes = "yes"
    case no = "no"
    case close = "close"
    case search = "search"
    case filter = "filter"
    case all = "all"
    case none = "none"
    case more = "more"
    case less = "less"
    case share = "share"
    case copy = "copy"
    case refresh = "refresh"
    
    // MARK: - Navigation / Tabs
    case tabHome = "tab_home"
    case tabCourses = "tab_courses"
    case tabDiscover = "tab_discover"
    case tabFavorites = "tab_favorites"
    case tabProfile = "tab_profile"
    
    // MARK: - Onboarding
    case onboardingWelcome = "onboarding_welcome"
    case onboardingWelcomeText = "onboarding_welcome_text"
    case onboardingCourses = "onboarding_courses"
    case onboardingCoursesText = "onboarding_courses_text"
    case onboardingLearn = "onboarding_learn"
    case onboardingLearnText = "onboarding_learn_text"
    case onboardingStart = "onboarding_start"
    case onboardingSkip = "onboarding_skip"
    case selectLanguage = "select_language"
    case selectLanguageText = "select_language_text"
    case continueButton = "continue_button"
    
    // MARK: - Auth
    case login = "login"
    case logout = "logout"
    case register = "register"
    case email = "email"
    case password = "password"
    case confirmPassword = "confirm_password"
    case forgotPassword = "forgot_password"
    case resetPassword = "reset_password"
    case name = "name"
    case username = "username"
    case welcomeBack = "welcome_back"
    case createAccount = "create_account"
    case alreadyHaveAccount = "already_have_account"
    case dontHaveAccount = "dont_have_account"
    case loginSuccess = "login_success"
    case registerSuccess = "register_success"
    case passwordsNotMatch = "passwords_not_match"
    case emailVerification = "email_verification"
    case emailVerificationText = "email_verification_text"
    case resendEmail = "resend_email"
    case checkVerification = "check_verification"
    case verificationSent = "verification_sent"
    case agreeToTerms = "agree_to_terms"
    case termsOfService = "terms_of_service"
    case privacyPolicy = "privacy_policy"
    
    // MARK: - Kurse
    case courses = "courses"
    case myCourses = "my_courses"
    case allCourses = "all_courses"
    case freeCourses = "free_courses"
    case premiumCourses = "premium_courses"
    case courseDetails = "course_details"
    case lessons = "lessons"
    case lesson = "lesson"
    case duration = "duration"
    case level = "level"
    case levelBeginner = "level_beginner"
    case levelIntermediate = "level_intermediate"
    case levelAdvanced = "level_advanced"
    case buyCourse = "buy_course"
    case startCourse = "start_course"
    case continueCourse = "continue_course"
    case courseCompleted = "course_completed"
    case noCoursesFound = "no_courses_found"
    case downloadCourse = "download_course"
    case downloadedCourses = "downloaded_courses"
    
    // MARK: - Tanzstile
    case danceStyle = "dance_style"
    case salsa = "salsa"
    case bachata = "bachata"
    case kizomba = "kizomba"
    case zouk = "zouk"
    case tango = "tango"
    case waltz = "waltz"
    case discofox = "discofox"
    
    // MARK: - Privatstunden
    case privateLessons = "private_lessons"
    case bookPrivateLesson = "book_private_lesson"
    case myBookings = "my_bookings"
    case bookingNumber = "booking_number"
    case requestedDate = "requested_date"
    case confirmedDate = "confirmed_date"
    case bookingCreated = "booking_created"
    case trainer = "trainer"
    case customer = "customer"
    case price = "price"
    case minutes = "minutes"
    case bookNow = "book_now"
    case cancelBooking = "cancel_booking"
    case bookingConfirmed = "booking_confirmed"
    case bookingCancelled = "booking_cancelled"
    case awaitingPayment = "awaiting_payment"
    case payNow = "pay_now"
    case paid = "paid"
    case revenueOverview = "revenue_overview"
    case totalRevenue = "total_revenue"
    case noBookings = "no_bookings"
    case videoCall = "video_call"
    case startCall = "start_call"
    
    // MARK: - Profil
    case profile = "profile"
    case settings = "settings"
    case editProfile = "edit_profile"
    case changePassword = "change_password"
    case notifications = "notifications"
    case language = "language"
    case changeLanguage = "change_language"
    case about = "about"
    case help = "help"
    case support = "support"
    case contactSupport = "contact_support"
    case rateApp = "rate_app"
    case version = "version"
    case deleteAccount = "delete_account"
    case deleteAccountWarning = "delete_account_warning"
    
    // MARK: - Favoriten
    case favorites = "favorites"
    case addToFavorites = "add_to_favorites"
    case removeFromFavorites = "remove_from_favorites"
    case noFavorites = "no_favorites"
    case noFavoritesText = "no_favorites_text"
    
    // MARK: - Kommentare
    case comments = "comments"
    case writeComment = "write_comment"
    case noComments = "no_comments"
    case reply = "reply"
    case like = "like"
    case report = "report"
    
    // MARK: - Zahlung
    case payment = "payment"
    case paymentMethod = "payment_method"
    case paymentSuccessful = "payment_successful"
    case paymentFailed = "payment_failed"
    case payWithPayPal = "pay_with_paypal"
    
    // MARK: - Fehler
    case errorOccurred = "error_occurred"
    case networkError = "network_error"
    case tryAgain = "try_again"
    case noInternet = "no_internet"
    case sessionExpired = "session_expired"
    
    // MARK: - Zeit
    case today = "today"
    case yesterday = "yesterday"
    case tomorrow = "tomorrow"
    case minutes_short = "minutes_short"
    case hours = "hours"
    case days = "days"
    case weeks = "weeks"
    case months = "months"
    
    // MARK: - Admin
    case admin = "admin"
    case adminDashboard = "admin_dashboard"
    case createUser = "create_user"
    case premium = "premium"
    case newsletter = "newsletter"
    case sendPush = "send_push"
    case storage = "storage"
    case sync = "sync"
    case apiKeys = "api_keys"
    case achievements = "achievements"
    case userManagement = "user_management"
    case courseEditor = "course_editor"
    case statistics = "statistics"
    case broadcast = "broadcast"
}

// MARK: - Localized Strings Storage
class LocalizedStrings {
    static let shared = LocalizedStrings()
    
    private var strings: [AppLanguage: [LocalizedStringKey: String]] = [:]
    
    private init() {
        loadStrings()
    }
    
    func get(_ key: LocalizedStringKey, for language: AppLanguage) -> String {
        // Fallback: Zuerst gewählte Sprache, dann English, dann German
        if let value = strings[language]?[key] {
            return value
        }
        if let value = strings[.english]?[key] {
            return value
        }
        if let value = strings[.german]?[key] {
            return value
        }
        return key.rawValue
    }
    
    private func loadStrings() {
        // MARK: - Deutsch
        strings[.german] = [
            // Allgemein
            .appName: "Tanzen mit Tatiana Drexler",
            .ok: "OK",
            .cancel: "Abbrechen",
            .save: "Speichern",
            .delete: "Löschen",
            .edit: "Bearbeiten",
            .done: "Fertig",
            .back: "Zurück",
            .next: "Weiter",
            .loading: "Laden...",
            .error: "Fehler",
            .success: "Erfolg",
            .warning: "Warnung",
            .yes: "Ja",
            .no: "Nein",
            .close: "Schließen",
            .search: "Suchen",
            .filter: "Filter",
            .all: "Alle",
            .none: "Keine",
            .more: "Mehr",
            .less: "Weniger",
            .share: "Teilen",
            .copy: "Kopieren",
            .refresh: "Aktualisieren",
            
            // Navigation
            .tabHome: "Start",
            .tabCourses: "Kurse",
            .tabDiscover: "Entdecken",
            .tabFavorites: "Favoriten",
            .tabProfile: "Profil",
            
            // Onboarding
            .onboardingWelcome: "Willkommen!",
            .onboardingWelcomeText: "Lerne Tanzen mit professionellen Video-Kursen",
            .onboardingCourses: "Vielfältige Kurse",
            .onboardingCoursesText: "Von Salsa bis Walzer - für jeden Geschmack",
            .onboardingLearn: "Lerne in deinem Tempo",
            .onboardingLearnText: "Jederzeit und überall verfügbar",
            .onboardingStart: "Los geht's",
            .onboardingSkip: "Überspringen",
            .selectLanguage: "Sprache wählen",
            .selectLanguageText: "Wähle deine bevorzugte Sprache",
            .continueButton: "Weiter",
            
            // Auth
            .login: "Anmelden",
            .logout: "Abmelden",
            .register: "Registrieren",
            .email: "E-Mail",
            .password: "Passwort",
            .confirmPassword: "Passwort bestätigen",
            .forgotPassword: "Passwort vergessen?",
            .resetPassword: "Passwort zurücksetzen",
            .name: "Name",
            .username: "Benutzername",
            .welcomeBack: "Willkommen zurück!",
            .createAccount: "Konto erstellen",
            .alreadyHaveAccount: "Bereits ein Konto?",
            .dontHaveAccount: "Noch kein Konto?",
            .loginSuccess: "Erfolgreich angemeldet!",
            .registerSuccess: "Registrierung erfolgreich!",
            .passwordsNotMatch: "Passwörter stimmen nicht überein",
            .emailVerification: "E-Mail bestätigen",
            .emailVerificationText: "Bitte bestätige deine E-Mail-Adresse über den Link in deiner Inbox.",
            .resendEmail: "E-Mail erneut senden",
            .checkVerification: "Verifizierung prüfen",
            .verificationSent: "Verifizierungs-E-Mail gesendet!",
            .agreeToTerms: "Ich stimme den Nutzungsbedingungen zu",
            .termsOfService: "Nutzungsbedingungen",
            .privacyPolicy: "Datenschutzerklärung",
            
            // Kurse
            .courses: "Kurse",
            .myCourses: "Meine Kurse",
            .allCourses: "Alle Kurse",
            .freeCourses: "Kostenlose Kurse",
            .premiumCourses: "Premium Kurse",
            .courseDetails: "Kursdetails",
            .lessons: "Lektionen",
            .lesson: "Lektion",
            .duration: "Dauer",
            .level: "Level",
            .levelBeginner: "Anfänger",
            .levelIntermediate: "Mittelstufe",
            .levelAdvanced: "Fortgeschritten",
            .buyCourse: "Kurs kaufen",
            .startCourse: "Kurs starten",
            .continueCourse: "Fortsetzen",
            .courseCompleted: "Kurs abgeschlossen",
            .noCoursesFound: "Keine Kurse gefunden",
            .downloadCourse: "Kurs herunterladen",
            .downloadedCourses: "Heruntergeladene Kurse",
            
            // Tanzstile
            .danceStyle: "Tanzstil",
            .salsa: "Salsa",
            .bachata: "Bachata",
            .kizomba: "Kizomba",
            .zouk: "Zouk",
            .tango: "Tango",
            .waltz: "Walzer",
            .discofox: "Discofox",
            
            // Privatstunden
            .privateLessons: "Privatstunden",
            .bookPrivateLesson: "Privatstunde buchen",
            .myBookings: "Meine Buchungen",
            .bookingNumber: "Buchungsnummer",
            .requestedDate: "Angefragter Termin",
            .confirmedDate: "Bestätigter Termin",
            .bookingCreated: "Buchung erstellt",
            .trainer: "Trainer",
            .customer: "Kunde",
            .price: "Preis",
            .minutes: "Minuten",
            .bookNow: "Jetzt buchen",
            .cancelBooking: "Buchung stornieren",
            .bookingConfirmed: "Buchung bestätigt",
            .bookingCancelled: "Buchung storniert",
            .awaitingPayment: "Warte auf Zahlung",
            .payNow: "Jetzt bezahlen",
            .paid: "Bezahlt",
            .revenueOverview: "Umsatzübersicht",
            .totalRevenue: "Gesamtumsatz",
            .noBookings: "Keine Buchungen",
            .videoCall: "Video-Call",
            .startCall: "Anruf starten",
            
            // Profil
            .profile: "Profil",
            .settings: "Einstellungen",
            .editProfile: "Profil bearbeiten",
            .changePassword: "Passwort ändern",
            .notifications: "Benachrichtigungen",
            .language: "Sprache",
            .changeLanguage: "Sprache ändern",
            .about: "Über uns",
            .help: "Hilfe",
            .support: "Support",
            .contactSupport: "Support kontaktieren",
            .rateApp: "App bewerten",
            .version: "Version",
            .deleteAccount: "Konto löschen",
            .deleteAccountWarning: "Diese Aktion kann nicht rückgängig gemacht werden.",
            
            // Favoriten
            .favorites: "Favoriten",
            .addToFavorites: "Zu Favoriten hinzufügen",
            .removeFromFavorites: "Aus Favoriten entfernen",
            .noFavorites: "Keine Favoriten",
            .noFavoritesText: "Füge Kurse zu deinen Favoriten hinzu",
            
            // Kommentare
            .comments: "Kommentare",
            .writeComment: "Kommentar schreiben",
            .noComments: "Keine Kommentare",
            .reply: "Antworten",
            .like: "Gefällt mir",
            .report: "Melden",
            
            // Zahlung
            .payment: "Zahlung",
            .paymentMethod: "Zahlungsmethode",
            .paymentSuccessful: "Zahlung erfolgreich!",
            .paymentFailed: "Zahlung fehlgeschlagen",
            .payWithPayPal: "Mit PayPal bezahlen",
            
            // Fehler
            .errorOccurred: "Ein Fehler ist aufgetreten",
            .networkError: "Netzwerkfehler",
            .tryAgain: "Erneut versuchen",
            .noInternet: "Keine Internetverbindung",
            .sessionExpired: "Sitzung abgelaufen",
            
            // Zeit
            .today: "Heute",
            .yesterday: "Gestern",
            .tomorrow: "Morgen",
            .minutes_short: "Min.",
            .hours: "Stunden",
            .days: "Tage",
            .weeks: "Wochen",
            .months: "Monate",
            
            // Admin
            .admin: "Admin",
            .adminDashboard: "Admin-Dashboard",
            .createUser: "User erstellen",
            .premium: "Premium",
            .newsletter: "Newsletter",
            .sendPush: "Push senden",
            .storage: "Speicher",
            .sync: "Synchronisieren",
            .apiKeys: "API-Schlüssel",
            .achievements: "Erfolge",
            .userManagement: "User-Verwaltung",
            .courseEditor: "Kurs-Editor",
            .statistics: "Statistiken",
            .broadcast: "Broadcast"
        ]
        
        // MARK: - English
        strings[.english] = [
            // General
            .appName: "Dance with Tatiana Drexler",
            .ok: "OK",
            .cancel: "Cancel",
            .save: "Save",
            .delete: "Delete",
            .edit: "Edit",
            .done: "Done",
            .back: "Back",
            .next: "Next",
            .loading: "Loading...",
            .error: "Error",
            .success: "Success",
            .warning: "Warning",
            .yes: "Yes",
            .no: "No",
            .close: "Close",
            .search: "Search",
            .filter: "Filter",
            .all: "All",
            .none: "None",
            .more: "More",
            .less: "Less",
            .share: "Share",
            .copy: "Copy",
            .refresh: "Refresh",
            
            // Navigation
            .tabHome: "Home",
            .tabCourses: "Courses",
            .tabDiscover: "Discover",
            .tabFavorites: "Favorites",
            .tabProfile: "Profile",
            
            // Onboarding
            .onboardingWelcome: "Welcome!",
            .onboardingWelcomeText: "Learn to dance with professional video courses",
            .onboardingCourses: "Diverse Courses",
            .onboardingCoursesText: "From Salsa to Waltz - for every taste",
            .onboardingLearn: "Learn at Your Pace",
            .onboardingLearnText: "Available anytime, anywhere",
            .onboardingStart: "Let's Go",
            .onboardingSkip: "Skip",
            .selectLanguage: "Select Language",
            .selectLanguageText: "Choose your preferred language",
            .continueButton: "Continue",
            
            // Auth
            .login: "Login",
            .logout: "Logout",
            .register: "Register",
            .email: "Email",
            .password: "Password",
            .confirmPassword: "Confirm Password",
            .forgotPassword: "Forgot Password?",
            .resetPassword: "Reset Password",
            .name: "Name",
            .username: "Username",
            .welcomeBack: "Welcome back!",
            .createAccount: "Create Account",
            .alreadyHaveAccount: "Already have an account?",
            .dontHaveAccount: "Don't have an account?",
            .loginSuccess: "Successfully logged in!",
            .registerSuccess: "Registration successful!",
            .passwordsNotMatch: "Passwords do not match",
            .emailVerification: "Verify Email",
            .emailVerificationText: "Please verify your email address via the link in your inbox.",
            .resendEmail: "Resend Email",
            .checkVerification: "Check Verification",
            .verificationSent: "Verification email sent!",
            .agreeToTerms: "I agree to the Terms of Service",
            .termsOfService: "Terms of Service",
            .privacyPolicy: "Privacy Policy",
            
            // Courses
            .courses: "Courses",
            .myCourses: "My Courses",
            .allCourses: "All Courses",
            .freeCourses: "Free Courses",
            .premiumCourses: "Premium Courses",
            .courseDetails: "Course Details",
            .lessons: "Lessons",
            .lesson: "Lesson",
            .duration: "Duration",
            .level: "Level",
            .levelBeginner: "Beginner",
            .levelIntermediate: "Intermediate",
            .levelAdvanced: "Advanced",
            .buyCourse: "Buy Course",
            .startCourse: "Start Course",
            .continueCourse: "Continue",
            .courseCompleted: "Course Completed",
            .noCoursesFound: "No courses found",
            .downloadCourse: "Download Course",
            .downloadedCourses: "Downloaded Courses",
            
            // Dance Styles
            .danceStyle: "Dance Style",
            .salsa: "Salsa",
            .bachata: "Bachata",
            .kizomba: "Kizomba",
            .zouk: "Zouk",
            .tango: "Tango",
            .waltz: "Waltz",
            .discofox: "Disco Fox",
            
            // Private Lessons
            .privateLessons: "Private Lessons",
            .bookPrivateLesson: "Book Private Lesson",
            .myBookings: "My Bookings",
            .bookingNumber: "Booking Number",
            .requestedDate: "Requested Date",
            .confirmedDate: "Confirmed Date",
            .bookingCreated: "Booking Created",
            .trainer: "Trainer",
            .customer: "Customer",
            .price: "Price",
            .minutes: "Minutes",
            .bookNow: "Book Now",
            .cancelBooking: "Cancel Booking",
            .bookingConfirmed: "Booking Confirmed",
            .bookingCancelled: "Booking Cancelled",
            .awaitingPayment: "Awaiting Payment",
            .payNow: "Pay Now",
            .paid: "Paid",
            .revenueOverview: "Revenue Overview",
            .totalRevenue: "Total Revenue",
            .noBookings: "No Bookings",
            .videoCall: "Video Call",
            .startCall: "Start Call",
            
            // Profile
            .profile: "Profile",
            .settings: "Settings",
            .editProfile: "Edit Profile",
            .changePassword: "Change Password",
            .notifications: "Notifications",
            .language: "Language",
            .changeLanguage: "Change Language",
            .about: "About",
            .help: "Help",
            .support: "Support",
            .contactSupport: "Contact Support",
            .rateApp: "Rate App",
            .version: "Version",
            .deleteAccount: "Delete Account",
            .deleteAccountWarning: "This action cannot be undone.",
            
            // Favorites
            .favorites: "Favorites",
            .addToFavorites: "Add to Favorites",
            .removeFromFavorites: "Remove from Favorites",
            .noFavorites: "No Favorites",
            .noFavoritesText: "Add courses to your favorites",
            
            // Comments
            .comments: "Comments",
            .writeComment: "Write Comment",
            .noComments: "No Comments",
            .reply: "Reply",
            .like: "Like",
            .report: "Report",
            
            // Payment
            .payment: "Payment",
            .paymentMethod: "Payment Method",
            .paymentSuccessful: "Payment Successful!",
            .paymentFailed: "Payment Failed",
            .payWithPayPal: "Pay with PayPal",
            
            // Errors
            .errorOccurred: "An error occurred",
            .networkError: "Network Error",
            .tryAgain: "Try Again",
            .noInternet: "No Internet Connection",
            .sessionExpired: "Session Expired",
            
            // Time
            .today: "Today",
            .yesterday: "Yesterday",
            .tomorrow: "Tomorrow",
            .minutes_short: "min",
            .hours: "hours",
            .days: "days",
            .weeks: "weeks",
            .months: "months",
            
            // Admin
            .admin: "Admin",
            .adminDashboard: "Admin Dashboard",
            .createUser: "Create User",
            .premium: "Premium",
            .newsletter: "Newsletter",
            .sendPush: "Send Push",
            .storage: "Storage",
            .sync: "Sync",
            .apiKeys: "API Keys",
            .achievements: "Achievements",
            .userManagement: "User Management",
            .courseEditor: "Course Editor",
            .statistics: "Statistics",
            .broadcast: "Broadcast"
        ]
        
        // MARK: - Russian
        strings[.russian] = [
            // Общие
            .appName: "Танцы с Татьяной Дрекслер",
            .ok: "ОК",
            .cancel: "Отмена",
            .save: "Сохранить",
            .delete: "Удалить",
            .edit: "Редактировать",
            .done: "Готово",
            .back: "Назад",
            .next: "Далее",
            .loading: "Загрузка...",
            .error: "Ошибка",
            .success: "Успешно",
            .warning: "Предупреждение",
            .yes: "Да",
            .no: "Нет",
            .close: "Закрыть",
            .search: "Поиск",
            .filter: "Фильтр",
            .all: "Все",
            .none: "Нет",
            .more: "Больше",
            .less: "Меньше",
            .share: "Поделиться",
            .copy: "Копировать",
            .refresh: "Обновить",
            
            // Навигация
            .tabHome: "Главная",
            .tabCourses: "Курсы",
            .tabDiscover: "Обзор",
            .tabFavorites: "Избранное",
            .tabProfile: "Профиль",
            
            // Онбординг
            .onboardingWelcome: "Добро пожаловать!",
            .onboardingWelcomeText: "Учитесь танцевать с профессиональными видеокурсами",
            .onboardingCourses: "Разнообразные курсы",
            .onboardingCoursesText: "От сальсы до вальса - на любой вкус",
            .onboardingLearn: "Учитесь в своем темпе",
            .onboardingLearnText: "Доступно в любое время и в любом месте",
            .onboardingStart: "Начать",
            .onboardingSkip: "Пропустить",
            .selectLanguage: "Выбор языка",
            .selectLanguageText: "Выберите предпочитаемый язык",
            .continueButton: "Продолжить",
            
            // Авторизация
            .login: "Войти",
            .logout: "Выйти",
            .register: "Регистрация",
            .email: "Эл. почта",
            .password: "Пароль",
            .confirmPassword: "Подтвердите пароль",
            .forgotPassword: "Забыли пароль?",
            .resetPassword: "Сбросить пароль",
            .name: "Имя",
            .username: "Имя пользователя",
            .welcomeBack: "С возвращением!",
            .createAccount: "Создать аккаунт",
            .alreadyHaveAccount: "Уже есть аккаунт?",
            .dontHaveAccount: "Нет аккаунта?",
            .loginSuccess: "Успешный вход!",
            .registerSuccess: "Регистрация успешна!",
            .passwordsNotMatch: "Пароли не совпадают",
            .emailVerification: "Подтверждение почты",
            .emailVerificationText: "Пожалуйста, подтвердите email по ссылке в письме.",
            .resendEmail: "Отправить повторно",
            .checkVerification: "Проверить",
            .verificationSent: "Письмо отправлено!",
            .agreeToTerms: "Я согласен с условиями использования",
            .termsOfService: "Условия использования",
            .privacyPolicy: "Политика конфиденциальности",
            
            // Курсы
            .courses: "Курсы",
            .myCourses: "Мои курсы",
            .allCourses: "Все курсы",
            .freeCourses: "Бесплатные курсы",
            .premiumCourses: "Премиум курсы",
            .courseDetails: "Детали курса",
            .lessons: "Уроки",
            .lesson: "Урок",
            .duration: "Длительность",
            .level: "Уровень",
            .levelBeginner: "Начинающий",
            .levelIntermediate: "Средний",
            .levelAdvanced: "Продвинутый",
            .buyCourse: "Купить курс",
            .startCourse: "Начать курс",
            .continueCourse: "Продолжить",
            .courseCompleted: "Курс завершен",
            .noCoursesFound: "Курсы не найдены",
            .downloadCourse: "Скачать курс",
            .downloadedCourses: "Загруженные курсы",
            
            // Стили танцев
            .danceStyle: "Стиль танца",
            .salsa: "Сальса",
            .bachata: "Бачата",
            .kizomba: "Кизомба",
            .zouk: "Зук",
            .tango: "Танго",
            .waltz: "Вальс",
            .discofox: "Дискофокс",
            
            // Частные уроки
            .privateLessons: "Частные уроки",
            .bookPrivateLesson: "Забронировать урок",
            .myBookings: "Мои бронирования",
            .bookingNumber: "Номер брони",
            .requestedDate: "Запрошенная дата",
            .confirmedDate: "Подтвержденная дата",
            .bookingCreated: "Бронирование создано",
            .trainer: "Тренер",
            .customer: "Клиент",
            .price: "Цена",
            .minutes: "Минуты",
            .bookNow: "Забронировать",
            .cancelBooking: "Отменить бронь",
            .bookingConfirmed: "Бронь подтверждена",
            .bookingCancelled: "Бронь отменена",
            .awaitingPayment: "Ожидание оплаты",
            .payNow: "Оплатить",
            .paid: "Оплачено",
            .revenueOverview: "Обзор доходов",
            .totalRevenue: "Общий доход",
            .noBookings: "Нет бронирований",
            .videoCall: "Видеозвонок",
            .startCall: "Начать звонок",
            
            // Профиль
            .profile: "Профиль",
            .settings: "Настройки",
            .editProfile: "Редактировать профиль",
            .changePassword: "Изменить пароль",
            .notifications: "Уведомления",
            .language: "Язык",
            .changeLanguage: "Изменить язык",
            .about: "О нас",
            .help: "Помощь",
            .support: "Поддержка",
            .contactSupport: "Связаться с поддержкой",
            .rateApp: "Оценить приложение",
            .version: "Версия",
            .deleteAccount: "Удалить аккаунт",
            .deleteAccountWarning: "Это действие нельзя отменить.",
            
            // Избранное
            .favorites: "Избранное",
            .addToFavorites: "Добавить в избранное",
            .removeFromFavorites: "Удалить из избранного",
            .noFavorites: "Нет избранного",
            .noFavoritesText: "Добавьте курсы в избранное",
            
            // Комментарии
            .comments: "Комментарии",
            .writeComment: "Написать комментарий",
            .noComments: "Нет комментариев",
            .reply: "Ответить",
            .like: "Нравится",
            .report: "Пожаловаться",
            
            // Оплата
            .payment: "Оплата",
            .paymentMethod: "Способ оплаты",
            .paymentSuccessful: "Оплата успешна!",
            .paymentFailed: "Оплата не удалась",
            .payWithPayPal: "Оплатить через PayPal",
            
            // Ошибки
            .errorOccurred: "Произошла ошибка",
            .networkError: "Ошибка сети",
            .tryAgain: "Попробовать снова",
            .noInternet: "Нет подключения к интернету",
            .sessionExpired: "Сессия истекла",
            
            // Время
            .today: "Сегодня",
            .yesterday: "Вчера",
            .tomorrow: "Завтра",
            .minutes_short: "мин.",
            .hours: "часов",
            .days: "дней",
            .weeks: "недель",
            .months: "месяцев",
            
            // Админ
            .admin: "Админ",
            .adminDashboard: "Панель админа",
            .createUser: "Создать пользователя",
            .premium: "Премиум",
            .newsletter: "Рассылка",
            .sendPush: "Отправить уведомление",
            .storage: "Хранилище",
            .sync: "Синхронизация",
            .apiKeys: "API-ключи",
            .achievements: "Достижения",
            .userManagement: "Управление пользователями",
            .courseEditor: "Редактор курсов",
            .statistics: "Статистика",
            .broadcast: "Рассылка"
        ]
        
        // MARK: - Slovak
        strings[.slovak] = [
            // Všeobecné
            .appName: "Tanec s Tatianou Drexler",
            .ok: "OK",
            .cancel: "Zrušiť",
            .save: "Uložiť",
            .delete: "Vymazať",
            .edit: "Upraviť",
            .done: "Hotovo",
            .back: "Späť",
            .next: "Ďalej",
            .loading: "Načítava sa...",
            .error: "Chyba",
            .success: "Úspech",
            .warning: "Upozornenie",
            .yes: "Áno",
            .no: "Nie",
            .close: "Zavrieť",
            .search: "Hľadať",
            .filter: "Filter",
            .all: "Všetko",
            .none: "Žiadne",
            .more: "Viac",
            .less: "Menej",
            .share: "Zdieľať",
            .copy: "Kopírovať",
            .refresh: "Obnoviť",
            
            // Navigácia
            .tabHome: "Domov",
            .tabCourses: "Kurzy",
            .tabDiscover: "Objavovať",
            .tabFavorites: "Obľúbené",
            .tabProfile: "Profil",
            
            // Onboarding
            .onboardingWelcome: "Vitajte!",
            .onboardingWelcomeText: "Naučte sa tancovať s profesionálnymi video kurzami",
            .onboardingCourses: "Rôznorodé kurzy",
            .onboardingCoursesText: "Od salsy po valčík - pre každý vkus",
            .onboardingLearn: "Učte sa vlastným tempom",
            .onboardingLearnText: "Dostupné kedykoľvek a kdekoľvek",
            .onboardingStart: "Poďme na to",
            .onboardingSkip: "Preskočiť",
            .selectLanguage: "Výber jazyka",
            .selectLanguageText: "Vyberte si preferovaný jazyk",
            .continueButton: "Pokračovať",
            
            // Autentifikácia
            .login: "Prihlásiť sa",
            .logout: "Odhlásiť sa",
            .register: "Registrovať sa",
            .email: "E-mail",
            .password: "Heslo",
            .confirmPassword: "Potvrdiť heslo",
            .forgotPassword: "Zabudli ste heslo?",
            .resetPassword: "Obnoviť heslo",
            .name: "Meno",
            .username: "Používateľské meno",
            .welcomeBack: "Vitajte späť!",
            .createAccount: "Vytvoriť účet",
            .alreadyHaveAccount: "Už máte účet?",
            .dontHaveAccount: "Nemáte účet?",
            .loginSuccess: "Úspešne prihlásený!",
            .registerSuccess: "Registrácia úspešná!",
            .passwordsNotMatch: "Heslá sa nezhodujú",
            .emailVerification: "Overenie e-mailu",
            .emailVerificationText: "Prosím overte svoj e-mail cez odkaz v doručenej pošte.",
            .resendEmail: "Poslať znova",
            .checkVerification: "Skontrolovať overenie",
            .verificationSent: "Overovací e-mail odoslaný!",
            .agreeToTerms: "Súhlasím s podmienkami používania",
            .termsOfService: "Podmienky používania",
            .privacyPolicy: "Zásady ochrany osobných údajov",
            
            // Kurzy
            .courses: "Kurzy",
            .myCourses: "Moje kurzy",
            .allCourses: "Všetky kurzy",
            .freeCourses: "Bezplatné kurzy",
            .premiumCourses: "Prémiové kurzy",
            .courseDetails: "Detaily kurzu",
            .lessons: "Lekcie",
            .lesson: "Lekcia",
            .duration: "Trvanie",
            .level: "Úroveň",
            .levelBeginner: "Začiatočník",
            .levelIntermediate: "Mierne pokročilý",
            .levelAdvanced: "Pokročilý",
            .buyCourse: "Kúpiť kurz",
            .startCourse: "Začať kurz",
            .continueCourse: "Pokračovať",
            .courseCompleted: "Kurz dokončený",
            .noCoursesFound: "Žiadne kurzy nenájdené",
            .downloadCourse: "Stiahnuť kurz",
            .downloadedCourses: "Stiahnuté kurzy",
            
            // Tanečné štýly
            .danceStyle: "Tanečný štýl",
            .salsa: "Salsa",
            .bachata: "Bachata",
            .kizomba: "Kizomba",
            .zouk: "Zouk",
            .tango: "Tango",
            .waltz: "Valčík",
            .discofox: "Discofox",
            
            // Súkromné hodiny
            .privateLessons: "Súkromné hodiny",
            .bookPrivateLesson: "Rezervovať súkromnú hodinu",
            .myBookings: "Moje rezervácie",
            .bookingNumber: "Číslo rezervácie",
            .requestedDate: "Požadovaný termín",
            .confirmedDate: "Potvrdený termín",
            .bookingCreated: "Rezervácia vytvorená",
            .trainer: "Tréner",
            .customer: "Zákazník",
            .price: "Cena",
            .minutes: "Minúty",
            .bookNow: "Rezervovať teraz",
            .cancelBooking: "Zrušiť rezerváciu",
            .bookingConfirmed: "Rezervácia potvrdená",
            .bookingCancelled: "Rezervácia zrušená",
            .awaitingPayment: "Čaká sa na platbu",
            .payNow: "Zaplatiť teraz",
            .paid: "Zaplatené",
            .revenueOverview: "Prehľad príjmov",
            .totalRevenue: "Celkový príjem",
            .noBookings: "Žiadne rezervácie",
            .videoCall: "Videohovor",
            .startCall: "Začať hovor",
            
            // Profil
            .profile: "Profil",
            .settings: "Nastavenia",
            .editProfile: "Upraviť profil",
            .changePassword: "Zmeniť heslo",
            .notifications: "Notifikácie",
            .language: "Jazyk",
            .changeLanguage: "Zmeniť jazyk",
            .about: "O nás",
            .help: "Pomoc",
            .support: "Podpora",
            .contactSupport: "Kontaktovať podporu",
            .rateApp: "Ohodnotiť aplikáciu",
            .version: "Verzia",
            .deleteAccount: "Vymazať účet",
            .deleteAccountWarning: "Túto akciu nie je možné vrátiť späť.",
            
            // Obľúbené
            .favorites: "Obľúbené",
            .addToFavorites: "Pridať do obľúbených",
            .removeFromFavorites: "Odstrániť z obľúbených",
            .noFavorites: "Žiadne obľúbené",
            .noFavoritesText: "Pridajte kurzy do obľúbených",
            
            // Komentáre
            .comments: "Komentáre",
            .writeComment: "Napísať komentár",
            .noComments: "Žiadne komentáre",
            .reply: "Odpovedať",
            .like: "Páči sa mi",
            .report: "Nahlásiť",
            
            // Platba
            .payment: "Platba",
            .paymentMethod: "Spôsob platby",
            .paymentSuccessful: "Platba úspešná!",
            .paymentFailed: "Platba zlyhala",
            .payWithPayPal: "Zaplatiť cez PayPal",
            
            // Chyby
            .errorOccurred: "Vyskytla sa chyba",
            .networkError: "Chyba siete",
            .tryAgain: "Skúsiť znova",
            .noInternet: "Žiadne internetové pripojenie",
            .sessionExpired: "Relácia vypršala",
            
            // Čas
            .today: "Dnes",
            .yesterday: "Včera",
            .tomorrow: "Zajtra",
            .minutes_short: "min.",
            .hours: "hodín",
            .days: "dní",
            .weeks: "týždňov",
            .months: "mesiacov",
            
            // Admin
            .admin: "Admin",
            .adminDashboard: "Admin panel",
            .createUser: "Vytvoriť používateľa",
            .premium: "Premium",
            .newsletter: "Newsletter",
            .sendPush: "Odoslať notifikáciu",
            .storage: "Úložisko",
            .sync: "Synchronizácia",
            .apiKeys: "API kľúče",
            .achievements: "Úspechy",
            .userManagement: "Správa používateľov",
            .courseEditor: "Editor kurzov",
            .statistics: "Štatistiky",
            .broadcast: "Broadcast"
        ]
        
        // MARK: - Czech
        strings[.czech] = [
            // Obecné
            .appName: "Tanec s Tatianou Drexler",
            .ok: "OK",
            .cancel: "Zrušit",
            .save: "Uložit",
            .delete: "Smazat",
            .edit: "Upravit",
            .done: "Hotovo",
            .back: "Zpět",
            .next: "Další",
            .loading: "Načítání...",
            .error: "Chyba",
            .success: "Úspěch",
            .warning: "Upozornění",
            .yes: "Ano",
            .no: "Ne",
            .close: "Zavřít",
            .search: "Hledat",
            .filter: "Filtr",
            .all: "Vše",
            .none: "Žádné",
            .more: "Více",
            .less: "Méně",
            .share: "Sdílet",
            .copy: "Kopírovat",
            .refresh: "Obnovit",
            
            // Navigace
            .tabHome: "Domů",
            .tabCourses: "Kurzy",
            .tabDiscover: "Objevovat",
            .tabFavorites: "Oblíbené",
            .tabProfile: "Profil",
            
            // Onboarding
            .onboardingWelcome: "Vítejte!",
            .onboardingWelcomeText: "Naučte se tancovat s profesionálními video kurzy",
            .onboardingCourses: "Rozmanité kurzy",
            .onboardingCoursesText: "Od salsy po valčík - pro každý vkus",
            .onboardingLearn: "Učte se vlastním tempem",
            .onboardingLearnText: "Dostupné kdykoli a kdekoli",
            .onboardingStart: "Pojďme na to",
            .onboardingSkip: "Přeskočit",
            .selectLanguage: "Výběr jazyka",
            .selectLanguageText: "Vyberte si preferovaný jazyk",
            .continueButton: "Pokračovat",
            
            // Autentizace
            .login: "Přihlásit se",
            .logout: "Odhlásit se",
            .register: "Registrovat se",
            .email: "E-mail",
            .password: "Heslo",
            .confirmPassword: "Potvrdit heslo",
            .forgotPassword: "Zapomněli jste heslo?",
            .resetPassword: "Obnovit heslo",
            .name: "Jméno",
            .username: "Uživatelské jméno",
            .welcomeBack: "Vítejte zpět!",
            .createAccount: "Vytvořit účet",
            .alreadyHaveAccount: "Již máte účet?",
            .dontHaveAccount: "Nemáte účet?",
            .loginSuccess: "Úspěšně přihlášen!",
            .registerSuccess: "Registrace úspěšná!",
            .passwordsNotMatch: "Hesla se neshodují",
            .emailVerification: "Ověření e-mailu",
            .emailVerificationText: "Prosím ověřte svůj e-mail přes odkaz v doručené poště.",
            .resendEmail: "Poslat znovu",
            .checkVerification: "Zkontrolovat ověření",
            .verificationSent: "Ověřovací e-mail odeslán!",
            .agreeToTerms: "Souhlasím s podmínkami používání",
            .termsOfService: "Podmínky používání",
            .privacyPolicy: "Zásady ochrany osobních údajů",
            
            // Kurzy
            .courses: "Kurzy",
            .myCourses: "Moje kurzy",
            .allCourses: "Všechny kurzy",
            .freeCourses: "Bezplatné kurzy",
            .premiumCourses: "Prémiové kurzy",
            .courseDetails: "Detaily kurzu",
            .lessons: "Lekce",
            .lesson: "Lekce",
            .duration: "Délka",
            .level: "Úroveň",
            .levelBeginner: "Začátečník",
            .levelIntermediate: "Mírně pokročilý",
            .levelAdvanced: "Pokročilý",
            .buyCourse: "Koupit kurz",
            .startCourse: "Začít kurz",
            .continueCourse: "Pokračovat",
            .courseCompleted: "Kurz dokončen",
            .noCoursesFound: "Žádné kurzy nenalezeny",
            .downloadCourse: "Stáhnout kurz",
            .downloadedCourses: "Stažené kurzy",
            
            // Taneční styly
            .danceStyle: "Taneční styl",
            .salsa: "Salsa",
            .bachata: "Bachata",
            .kizomba: "Kizomba",
            .zouk: "Zouk",
            .tango: "Tango",
            .waltz: "Valčík",
            .discofox: "Discofox",
            
            // Soukromé hodiny
            .privateLessons: "Soukromé hodiny",
            .bookPrivateLesson: "Rezervovat soukromou hodinu",
            .myBookings: "Moje rezervace",
            .bookingNumber: "Číslo rezervace",
            .requestedDate: "Požadovaný termín",
            .confirmedDate: "Potvrzený termín",
            .bookingCreated: "Rezervace vytvořena",
            .trainer: "Trenér",
            .customer: "Zákazník",
            .price: "Cena",
            .minutes: "Minuty",
            .bookNow: "Rezervovat nyní",
            .cancelBooking: "Zrušit rezervaci",
            .bookingConfirmed: "Rezervace potvrzena",
            .bookingCancelled: "Rezervace zrušena",
            .awaitingPayment: "Čeká se na platbu",
            .payNow: "Zaplatit nyní",
            .paid: "Zaplaceno",
            .revenueOverview: "Přehled příjmů",
            .totalRevenue: "Celkový příjem",
            .noBookings: "Žádné rezervace",
            .videoCall: "Videohovor",
            .startCall: "Zahájit hovor",
            
            // Profil
            .profile: "Profil",
            .settings: "Nastavení",
            .editProfile: "Upravit profil",
            .changePassword: "Změnit heslo",
            .notifications: "Oznámení",
            .language: "Jazyk",
            .changeLanguage: "Změnit jazyk",
            .about: "O nás",
            .help: "Nápověda",
            .support: "Podpora",
            .contactSupport: "Kontaktovat podporu",
            .rateApp: "Ohodnotit aplikaci",
            .version: "Verze",
            .deleteAccount: "Smazat účet",
            .deleteAccountWarning: "Tuto akci nelze vrátit zpět.",
            
            // Oblíbené
            .favorites: "Oblíbené",
            .addToFavorites: "Přidat do oblíbených",
            .removeFromFavorites: "Odebrat z oblíbených",
            .noFavorites: "Žádné oblíbené",
            .noFavoritesText: "Přidejte kurzy do oblíbených",
            
            // Komentáře
            .comments: "Komentáře",
            .writeComment: "Napsat komentář",
            .noComments: "Žádné komentáře",
            .reply: "Odpovědět",
            .like: "Líbí se mi",
            .report: "Nahlásit",
            
            // Platba
            .payment: "Platba",
            .paymentMethod: "Způsob platby",
            .paymentSuccessful: "Platba úspěšná!",
            .paymentFailed: "Platba selhala",
            .payWithPayPal: "Zaplatit přes PayPal",
            
            // Chyby
            .errorOccurred: "Vyskytla se chyba",
            .networkError: "Chyba sítě",
            .tryAgain: "Zkusit znovu",
            .noInternet: "Žádné internetové připojení",
            .sessionExpired: "Relace vypršela",
            
            // Čas
            .today: "Dnes",
            .yesterday: "Včera",
            .tomorrow: "Zítra",
            .minutes_short: "min.",
            .hours: "hodin",
            .days: "dní",
            .weeks: "týdnů",
            .months: "měsíců",
            
            // Admin
            .admin: "Admin",
            .adminDashboard: "Admin panel",
            .createUser: "Vytvořit uživatele",
            .premium: "Premium",
            .newsletter: "Newsletter",
            .sendPush: "Odeslat notifikaci",
            .storage: "Úložiště",
            .sync: "Synchronizace",
            .apiKeys: "API klíče",
            .achievements: "Úspěchy",
            .userManagement: "Správa uživatelů",
            .courseEditor: "Editor kurzů",
            .statistics: "Statistiky",
            .broadcast: "Broadcast"
        ]
    }
}

// MARK: - String Extension for Easy Access
extension String {
    static func localized(_ key: LocalizedStringKey) -> String {
        return LanguageManager.shared.string(key)
    }
}

// MARK: - View Extension for Localized Text
extension View {
    func localized(_ key: LocalizedStringKey) -> Text {
        Text(LanguageManager.shared.string(key))
    }
}

// MARK: - Quick Localization Function
/// Schnelle Lokalisierungsfunktion - L(.key) oder L("custom_string")
@MainActor
func L(_ key: LocalizedStringKey) -> String {
    return LanguageManager.shared.string(key)
}

// MARK: - Localized Text View (einfacher zu nutzen)
struct LText: View {
    let key: LocalizedStringKey
    
    init(_ key: LocalizedStringKey) {
        self.key = key
    }
    
    var body: some View {
        Text(LanguageManager.shared.string(key))
    }
}

// MARK: - Dynamic String Translations (für Strings die nicht als enum Keys existieren)
extension LanguageManager {
    /// Dynamische Übersetzung - verwendet die zentrale Translations-Klasse
    func translate(_ germanText: String) -> String {
        let translation = Translations.shared.get(germanText, for: currentLanguage)
        
        // Debug: Logge fehlende Übersetzungen
        #if DEBUG
        if translation == germanText && currentLanguage != .german {
            // Nur loggen wenn es wirklich ein deutscher String ist (nicht nur Satzzeichen etc.)
            let isGermanWord = germanText.range(of: "[a-zäöüß]{3,}", options: [.regularExpression, .caseInsensitive]) != nil
            if isGermanWord {
                print("⚠️ Missing translation for '\(germanText)' in \(currentLanguage.displayName)")
            }
        }
        #endif
        
        return translation
    }
    
    /// Übersetzt einen String mit einem Argument
    func translate(_ germanText: String, arg: Any) -> String {
        let template = translate(germanText)
        return String(format: template, String(describing: arg))
    }
    
    /// Übersetzt einen String mit mehreren Argumenten
    func translate(_ germanText: String, args: Any...) -> String {
        let template = translate(germanText)
        let stringArgs = args.map { String(describing: $0) }
        return String(format: template, arguments: stringArgs.map { $0 as CVarArg })
    }
    
    /// Dynamische Strings für häufige UI-Texte
    private var dynamicStrings: [AppLanguage: [String: String]] {
        [
            .german: [:], // Deutsch ist Default, keine Übersetzung nötig
            .english: [
                // Navigation & Tabs
                "Start": "Home",
                "Kurse": "Courses",
                "Entdecken": "Discover",
                "Favoriten": "Favorites",
                "Profil": "Profile",
                "Tanzpartner": "Dance Partner",
                
                // Common Actions
                "Speichern": "Save",
                "Abbrechen": "Cancel",
                "Löschen": "Delete",
                "Bearbeiten": "Edit",
                "Fertig": "Done",
                "Weiter": "Next",
                "Zurück": "Back",
                "Schließen": "Close",
                "Suchen": "Search",
                "Filter": "Filter",
                "Alle": "All",
                "Keine": "None",
                "Mehr": "More",
                "Weniger": "Less",
                "Laden...": "Loading...",
                
                // Auth
                "Anmelden": "Login",
                "Abmelden": "Logout",
                "Registrieren": "Register",
                "E-Mail": "Email",
                "Passwort": "Password",
                
                // Courses
                "Meine Kurse": "My Courses",
                "Alle Kurse": "All Courses",
                "Kursdetails": "Course Details",
                "Lektionen": "Lessons",
                "Lektion": "Lesson",
                "Dauer": "Duration",
                "Level": "Level",
                "Anfänger": "Beginner",
                "Mittelstufe": "Intermediate",
                "Fortgeschritten": "Advanced",
                "Kurs kaufen": "Buy Course",
                "Kurs starten": "Start Course",
                "Fortsetzen": "Continue",
                "Keine Kurse gefunden": "No courses found",
                
                // Discover
                "Lerne Tanzen": "Learn to Dance",
                "mit unseren Trainern": "with our trainers",
                "Unsere Trainer": "Our Trainers",
                "Trainer": "Trainer",
                "Über den Trainer": "About the Trainer",
                "Spezialisierungen": "Specializations",
                "Angebote": "Offerings",
                "Nachricht schreiben": "Send Message",
                "Privatstunden": "Private Lessons",
                "Privatstunde buchen": "Book Private Lesson",
                "Trainingsplan bestellen": "Order Training Plan",
                "Vorstellungsvideo ansehen": "Watch Introduction Video",
                "Noch keine Kurse": "No courses yet",
                "KOSTENLOS": "FREE",
                "5% Cashback": "5% Cashback",
                
                // Profile
                "Einstellungen": "Settings",
                "Profil bearbeiten": "Edit Profile",
                "Sprache": "Language",
                "Sprache ändern": "Change Language",
                "Hilfe": "Help",
                "Support": "Support",
                "Über": "About",
                "Version": "Version",
                "Konto löschen": "Delete Account",
                
                // Errors
                "Fehler": "Error",
                "Netzwerkfehler": "Network Error",
                "Erneut versuchen": "Try Again",
                "Keine Internetverbindung": "No Internet Connection",
                
                // Time
                "Heute": "Today",
                "Gestern": "Yesterday",
                "Morgen": "Tomorrow",
                "Min.": "min",
                "Stunden": "hours",
                "Tage": "days",
                
                // Misc
                "Achievements freigeschaltet": "Achievements Unlocked",
                "Tage Streak": "Day Streak",
                "Punkte": "Points",
                "Nächste freie Termine:": "Next available slots:",
                "Video-Privatstunde buchen": "Book Video Private Lesson",
                "Persönlichen Trainingsplan bestellen": "Order Personal Training Plan",
                "Livestream-Gruppenstunden": "Livestream Group Classes",
                "Mit Coins buchen und live mitmachen": "Book with coins and join live",
                "Versuche andere Filter": "Try different filters",
                "Bitte melde dich an, um dem Trainer zu schreiben.": "Please log in to message the trainer.",
                "Der Chat konnte nicht gestartet werden. Bitte versuche es später erneut.": "Could not start chat. Please try again later.",
                "Trainer nicht verfügbar": "Trainer not available",
                "Bitte versuche es später erneut": "Please try again later",
                "Alle bisherigen Käufe wurden wiederhergestellt.": "All previous purchases have been restored.",
                "Alle heruntergeladenen Videos werden gelöscht.": "All downloaded videos will be deleted.",
                "Du wirst aus deinem Account abgemeldet.": "You will be logged out of your account."
            ],
            .russian: [
                // Navigation & Tabs
                "Start": "Главная",
                "Kurse": "Курсы",
                "Entdecken": "Открыть",
                "Favoriten": "Избранное",
                "Profil": "Профиль",
                "Tanzpartner": "Партнёр по танцам",
                
                // Common Actions
                "Speichern": "Сохранить",
                "Abbrechen": "Отмена",
                "Löschen": "Удалить",
                "Bearbeiten": "Редактировать",
                "Fertig": "Готово",
                "Weiter": "Далее",
                "Zurück": "Назад",
                "Schließen": "Закрыть",
                "Suchen": "Поиск",
                "Filter": "Фильтр",
                "Alle": "Все",
                "Keine": "Нет",
                "Mehr": "Больше",
                "Weniger": "Меньше",
                "Laden...": "Загрузка...",
                
                // Auth
                "Anmelden": "Войти",
                "Abmelden": "Выйти",
                "Registrieren": "Регистрация",
                "E-Mail": "Эл. почта",
                "Passwort": "Пароль",
                
                // Courses
                "Meine Kurse": "Мои курсы",
                "Alle Kurse": "Все курсы",
                "Kursdetails": "Детали курса",
                "Lektionen": "Уроки",
                "Lektion": "Урок",
                "Dauer": "Длительность",
                "Level": "Уровень",
                "Anfänger": "Начинающий",
                "Mittelstufe": "Средний",
                "Fortgeschritten": "Продвинутый",
                "Kurs kaufen": "Купить курс",
                "Kurs starten": "Начать курс",
                "Fortsetzen": "Продолжить",
                "Keine Kurse gefunden": "Курсы не найдены",
                
                // Discover
                "Lerne Tanzen": "Учись танцевать",
                "mit unseren Trainern": "с нашими тренерами",
                "Unsere Trainer": "Наши тренеры",
                "Trainer": "Тренер",
                "Über den Trainer": "О тренере",
                "Spezialisierungen": "Специализации",
                "Angebote": "Услуги",
                "Nachricht schreiben": "Написать сообщение",
                "Privatstunden": "Частные уроки",
                "Privatstunde buchen": "Записаться на частный урок",
                "Trainingsplan bestellen": "Заказать план тренировок",
                "Vorstellungsvideo ansehen": "Смотреть видео-презентацию",
                "Noch keine Kurse": "Пока нет курсов",
                "KOSTENLOS": "БЕСПЛАТНО",
                "5% Cashback": "5% кэшбэк",
                
                // Profile
                "Einstellungen": "Настройки",
                "Profil bearbeiten": "Редактировать профиль",
                "Sprache": "Язык",
                "Sprache ändern": "Изменить язык",
                "Hilfe": "Помощь",
                "Support": "Поддержка",
                "Über": "О приложении",
                "Version": "Версия",
                "Konto löschen": "Удалить аккаунт",
                
                // Errors
                "Fehler": "Ошибка",
                "Netzwerkfehler": "Ошибка сети",
                "Erneut versuchen": "Повторить",
                "Keine Internetverbindung": "Нет интернета",
                
                // Time
                "Heute": "Сегодня",
                "Gestern": "Вчера",
                "Morgen": "Завтра",
                "Min.": "мин.",
                "Stunden": "часов",
                "Tage": "дней",
                
                // Misc
                "Achievements freigeschaltet": "Достижения разблокированы",
                "Tage Streak": "Дней подряд",
                "Punkte": "Очки",
                "Nächste freie Termine:": "Ближайшие свободные даты:",
                "Video-Privatstunde buchen": "Записаться на видео-урок",
                "Persönlichen Trainingsplan bestellen": "Заказать персональный план",
                "Livestream-Gruppenstunden": "Групповые онлайн-уроки",
                "Mit Coins buchen und live mitmachen": "Оплатите монетами и участвуйте вживую"
            ],
            .slovak: [
                "Start": "Domov",
                "Kurse": "Kurzy",
                "Entdecken": "Objaviť",
                "Favoriten": "Obľúbené",
                "Profil": "Profil",
                "Tanzpartner": "Tanečný partner",
                "Speichern": "Uložiť",
                "Abbrechen": "Zrušiť",
                "Anmelden": "Prihlásiť sa",
                "Abmelden": "Odhlásiť sa",
                "Einstellungen": "Nastavenia",
                "Sprache": "Jazyk",
                "Trainer": "Tréner",
                "Lerne Tanzen": "Nauč sa tancovať",
                "mit unseren Trainern": "s našimi trénermi",
                "Unsere Trainer": "Naši tréneri",
                "KOSTENLOS": "ZADARMO",
                "Über den Trainer": "O trénerovi",
                "Spezialisierungen": "Špecializácie",
                "Angebote": "Ponuky",
                "Nachricht schreiben": "Napísať správu",
                "Privatstunden": "Súkromné hodiny",
                "Privatstunde buchen": "Rezervovať súkromnú hodinu"
            ],
            .czech: [
                "Start": "Domů",
                "Kurse": "Kurzy",
                "Entdecken": "Objevit",
                "Favoriten": "Oblíbené",
                "Profil": "Profil",
                "Tanzpartner": "Taneční partner",
                "Speichern": "Uložit",
                "Abbrechen": "Zrušit",
                "Anmelden": "Přihlásit se",
                "Abmelden": "Odhlásit se",
                "Einstellungen": "Nastavení",
                "Sprache": "Jazyk",
                "Trainer": "Trenér",
                "Lerne Tanzen": "Nauč se tančit",
                "mit unseren Trainern": "s našimi trenéry",
                "Unsere Trainer": "Naši trenéři",
                "KOSTENLOS": "ZDARMA",
                "Über den Trainer": "O trenérovi",
                "Spezialisierungen": "Specializace",
                "Angebote": "Nabídky",
                "Nachricht schreiben": "Napsat zprávu",
                "Privatstunden": "Soukromé hodiny",
                "Privatstunde buchen": "Rezervovat soukromou hodinu"
            ]
        ]
    }
}

// MARK: - Quick Translation Function for German Strings
/// Übersetzt einen deutschen String in die aktuelle Sprache
@MainActor
func T(_ germanText: String) -> String {
    return LanguageManager.shared.translate(germanText)
}

/// Übersetzt einen String mit einem Argument (z.B. T("Hallo, %@", name))
@MainActor
func T(_ germanText: String, _ arg: CVarArg) -> String {
    let template = Translations.shared.getInterpolated(germanText, for: LanguageManager.shared.currentLanguage)
    return String(format: template, arg)
}

/// Übersetzt einen String mit mehreren Argumenten
@MainActor
func T(_ germanText: String, _ args: CVarArg...) -> String {
    let template = Translations.shared.getInterpolated(germanText, for: LanguageManager.shared.currentLanguage)
    return String(format: template, arguments: args)
}
