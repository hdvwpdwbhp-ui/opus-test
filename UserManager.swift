//
//  UserManager.swift
//  Tanzen mit Tatiana Drexler
//
//  User-Management mit Firebase Firestore als primäre Datenbank
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: AppUser?
    @Published var allUsers: [AppUser] = []
    @Published var isLoading = false
    @Published var isLoggedIn = false
    @Published var isEmailVerified = false
    @Published var lastError: String?
    @Published var needsUsernameSetup = false
    
    /// Prüft ob der aktuelle User noch einen Username einrichten muss
    var shouldShowUsernameSetup: Bool {
        guard let user = currentUser else { return false }
        let emailPrefix = user.email.components(separatedBy: "@").first ?? ""
        return isLoggedIn && isEmailVerified && (user.username.isEmpty || user.username == emailPrefix)
    }
    
    private let db = Firestore.firestore()
    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    private var usersListener: ListenerRegistration?
    
    private let localCacheKey = "users_cache"
    private let currentUserKey = "current_user_id"
    private let usersCollection = "users"
    
    private init() {
        loadLocalCache()
        setupFirebaseListener()
        setupAuthObserver()
        Task { await syncLocalUsersToFirebase() }
    }
    
    deinit { usersListener?.remove() }
    
    // MARK: - Sync Local to Firebase
    
    private func syncLocalUsersToFirebase() async {
        guard !allUsers.isEmpty else { return }
        do {
            let snapshot = try await db.collection(usersCollection).getDocuments()
            let firebaseUserIds = Set(snapshot.documents.map { $0.documentID })
            let localUsersToSync = allUsers.filter { !firebaseUserIds.contains($0.id) }
            if !localUsersToSync.isEmpty {
                print("📤 Synchronisiere \(localUsersToSync.count) lokale User zu Firebase...")
                for user in localUsersToSync { _ = await saveUserToFirebase(user) }
                print("✅ Lokale User zu Firebase synchronisiert")
            }
        } catch { print("❌ Sync-Fehler: \(error)") }
    }
    
    // MARK: - Firebase Listener
    
    private func setupFirebaseListener() {
        usersListener = db.collection(usersCollection).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { print("❌ Firebase Listener Fehler: \(error)"); return }
            guard let docs = snapshot?.documents else { return }
            let users = docs.compactMap { try? $0.data(as: AppUser.self) }
            Task { @MainActor in
                if !users.isEmpty { self.allUsers = users; self.saveLocalCache() }
                if let id = self.currentUser?.id, let u = users.first(where: { $0.id == id }) { self.currentUser = u }
                print("🔥 Firebase Update: \(users.count) Users")
            }
        }
    }
    
    private func setupAuthObserver() {
        authService.$isAuthenticated.combineLatest(authService.$isEmailVerified)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth, verified in
                guard let self = self else { return }
                self.isEmailVerified = verified
                if isAuth, let uid = self.authService.userId,
                   let user = self.allUsers.first(where: { $0.firebaseUid == uid }) {
                    var updatedUser = user
                    let now = Date()
                    let didChange = self.applyLoginStreak(to: &updatedUser, now: now)
                    if didChange {
                        updatedUser.lastLoginAt = now
                        Task {
                            _ = await self.saveUserToFirebase(updatedUser)
                            if let idx = self.allUsers.firstIndex(where: { $0.id == updatedUser.id }) {
                                self.allUsers[idx] = updatedUser
                            }
                            self.currentUser = updatedUser
                            self.saveLocalCache()
                        }
                    } else {
                        self.currentUser = updatedUser
                    }
                    self.isLoggedIn = true
                    self.saveSession()
                    Task {
                        await CoinManager.shared.initialize(for: user.id)
                        await CoinManager.shared.checkDailyBonusOnLogin()
                        await UserSettingsManager.shared.initialize(for: user.id)
                    }
                }
            }.store(in: &cancellables)
    }

    private func applyLoginStreak(to user: inout AppUser, now: Date = Date()) -> Bool {
        let result = LoginStreakCalculator.calculate(
            now: now,
            lastLoginDay: user.lastLoginStreakDate,
            current: user.loginStreakCurrent,
            longest: user.loginStreakLongest
        )
        if result.didChange {
            user.loginStreakCurrent = result.current
            user.loginStreakLongest = result.longest
            user.lastLoginStreakDate = result.lastLoginDay
        }
        return result.didChange
    }
    
    private func saveSession() { UserDefaults.standard.set(currentUser?.id, forKey: currentUserKey) }
    
    private func restoreSession() {
        if let id = UserDefaults.standard.string(forKey: currentUserKey),
           let user = allUsers.first(where: { $0.id == id }) {
            currentUser = user; isLoggedIn = true
        }
    }
    
    // MARK: - Firebase CRUD
    
    func saveUserToFirebase(_ user: AppUser) async -> Bool {
        do {
            try db.collection(usersCollection).document(user.id).setData(from: user)
            print("🔥 User gespeichert: \(user.name)")
            return true
        } catch { print("❌ Speichern fehlgeschlagen: \(error)"); return false }
    }
    
    func deleteUserFromFirebase(_ userId: String) async -> Bool {
        do { try await db.collection(usersCollection).document(userId).delete(); return true }
        catch { return false }
    }
    
    // MARK: - Auth
    
    func registerWithFirebase(name: String, email: String, password: String, marketingConsent: Bool = false) async -> (success: Bool, message: String) {
        isLoading = true
        defer { isLoading = false }
        guard !name.isEmpty else { return (false, "Name fehlt") }
        guard email.contains("@") else { return (false, "Ungültige E-Mail") }
        guard password.count >= 6 else { return (false, "Passwort zu kurz") }
        let e = email.lowercased().trimmingCharacters(in: .whitespaces)
        if allUsers.contains(where: { $0.email == e }) { return (false, "E-Mail existiert") }
        let (ok, msg) = await authService.register(email: e, password: password)
        guard ok, let uid = authService.userId else { return (false, msg) }
        var user = AppUser(id: uid, name: name, username: e.components(separatedBy: "@").first ?? "user",
                          email: e, passwordHash: "", group: .user, createdAt: Date(), lastLoginAt: Date(),
                          isActive: true, firebaseUid: uid, isEmailVerified: false, marketingConsent: marketingConsent)
        _ = applyLoginStreak(to: &user)
        _ = await saveUserToFirebase(user)
        allUsers.append(user)
        currentUser = user
        isLoggedIn = true
        saveSession()
        saveLocalCache()
        await UserSettingsManager.shared.initialize(for: user.id)
        return (true, msg)
    }
    
    func loginWithFirebase(email: String, password: String) async -> (success: Bool, message: String, needsVerification: Bool) {
        isLoading = true
        defer { isLoading = false }
        var e = email.lowercased().trimmingCharacters(in: .whitespaces)
        if !e.contains("@"), let u = allUsers.first(where: { $0.username.lowercased() == e }) { e = u.email }
        else if !e.contains("@") { return (false, "Benutzer nicht gefunden", false) }
        let (ok, msg, verified) = await authService.login(email: e, password: password)
        guard ok, let uid = authService.userId else { return (false, msg, false) }
        let now = Date()
        if var user = allUsers.first(where: { $0.firebaseUid == uid || $0.email == e }) {
            user.lastLoginAt = now; user.firebaseUid = uid; user.isEmailVerified = verified
            _ = applyLoginStreak(to: &user, now: now)
            _ = await saveUserToFirebase(user)
            if let idx = allUsers.firstIndex(where: { $0.id == user.id }) { allUsers[idx] = user }
            currentUser = user
        } else {
            var user = AppUser(id: uid, name: e.components(separatedBy: "@").first ?? "User",
                              username: e.components(separatedBy: "@").first ?? "user", email: e, passwordHash: "",
                              group: .user, createdAt: Date(), lastLoginAt: now, isActive: true,
                              firebaseUid: uid, isEmailVerified: verified)
            _ = applyLoginStreak(to: &user, now: now)
            _ = await saveUserToFirebase(user)
            allUsers.append(user)
            currentUser = user
        }
        isLoggedIn = true; isEmailVerified = verified
        saveSession(); saveLocalCache()
        Task {
            if let userId = currentUser?.id {
                await CoinManager.shared.initialize(for: userId)
                await CoinManager.shared.checkDailyBonusOnLogin()
                await UserSettingsManager.shared.initialize(for: userId)
            }
        }
        return (true, verified ? "Willkommen!" : "E-Mail bestätigen", !verified)
    }
    
    func login(usernameOrEmail: String, password: String) async -> (success: Bool, message: String) {
        let n = usernameOrEmail.lowercased()
        let (ok, msg, _) = await loginWithFirebase(email: n, password: password)
        return (ok, msg)
    }
    
    func logout() {
        authService.logout()
        currentUser = nil; isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: currentUserKey)
        CoinManager.shared.cleanup()
        UserSettingsManager.shared.cleanup()
    }
    
    func loginAsUser(userId: String) async -> Bool {
        guard isAdmin, let user = allUsers.first(where: { $0.id == userId }) else { return false }
        currentUser = user; isLoggedIn = true; saveSession()
        return true
    }
    
    func syncWithFirebaseUser() async {
        guard let uid = authService.userId, var u = allUsers.first(where: { $0.firebaseUid == uid }) else { return }
        let now = Date()
        u.lastLoginAt = now; u.isEmailVerified = true
        _ = applyLoginStreak(to: &u, now: now)
        _ = await saveUserToFirebase(u)
        if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
        currentUser = u; isLoggedIn = true; isEmailVerified = true
        saveSession(); saveLocalCache()
    }
    
    func addSocialLoginUser(_ user: AppUser) async {
        var u = user
        let now = Date()
        if let existing = allUsers.first(where: { $0.firebaseUid == user.firebaseUid }) {
            u = existing; u.lastLoginAt = now
        } else {
            u.lastLoginAt = now
        }
        _ = applyLoginStreak(to: &u, now: now)
        _ = await saveUserToFirebase(u)
        if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
        else { allUsers.append(u) }
        currentUser = u; isLoggedIn = true; isEmailVerified = true
        saveSession(); saveLocalCache()
    }
    
    func resendVerificationEmail() async -> (success: Bool, message: String) { await authService.resendVerificationEmail() }
    
    func checkEmailVerification() async -> Bool {
        let v = await authService.checkEmailVerification()
        isEmailVerified = v
        if v, var u = currentUser {
            u.isEmailVerified = true
            _ = await saveUserToFirebase(u)
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache()
        }
        return v
    }
    
    func sendPasswordReset(email: String) async -> (success: Bool, message: String) { await authService.sendPasswordReset(email: email) }
    
    // MARK: - Admin Functions
    
    var isAdmin: Bool { currentUser?.group.isAdmin == true }
    var trainers: [AppUser] { allUsers.filter { $0.group == .trainer && $0.isActive } }
    var hasPremium: Bool { (currentUser?.premiumExpiresAt ?? .distantPast) > Date() }
    
    func canModerateCourse(_ courseId: String) -> Bool {
        guard let u = currentUser else { return false }
        return u.group.isAdmin || u.trainerProfile?.assignedCourseIds.contains(courseId) == true
    }
    
    func changeUserGroup(userId: String, newGroup: UserGroup) async -> Bool {
        guard isAdmin, var u = allUsers.first(where: { $0.id == userId }) else { return false }
        u.group = newGroup
        if newGroup == .trainer && u.trainerProfile == nil { u.trainerProfile = TrainerProfile.empty() }
        let ok = await saveUserToFirebase(u)
        if ok, let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u; saveLocalCache() }
        return ok
    }
    
    func setUserActive(userId: String, isActive: Bool) async -> Bool {
        guard isAdmin, userId != currentUser?.id, var u = allUsers.first(where: { $0.id == userId }) else { return false }
        u.isActive = isActive
        let ok = await saveUserToFirebase(u)
        if ok, let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u; saveLocalCache() }
        return ok
    }
    
    func updateUserAsAdmin(userId: String, newGroup: UserGroup, isActive: Bool, unlockedCourseIds: [String]) async -> Bool {
        guard isAdmin, var u = allUsers.first(where: { $0.id == userId }) else {
            lastError = "Keine Berechtigung oder User nicht gefunden"
            return false
        }
        u.group = newGroup
        u.isActive = isActive
        u.unlockedCourseIds = unlockedCourseIds
        if newGroup == .trainer && u.trainerProfile == nil { u.trainerProfile = TrainerProfile.empty() }
        let ok = await saveUserToFirebase(u)
        if ok, let idx = allUsers.firstIndex(where: { $0.id == u.id }) {
            allUsers[idx] = u
            saveLocalCache()
        }
        if !ok { lastError = "Speichern fehlgeschlagen" }
        return ok
    }
    
    func deleteUser(userId: String) async -> Bool {
        guard isAdmin, userId != currentUser?.id else { return false }
        let ok = await deleteUserFromFirebase(userId)
        if ok { allUsers.removeAll { $0.id == userId }; saveLocalCache() }
        return ok
    }
    
    func setPremiumExpiration(userId: String, expiresAt: Date?) async -> Bool {
        guard isAdmin, var u = allUsers.first(where: { $0.id == userId }) else { return false }
        u.premiumExpiresAt = expiresAt
        let ok = await saveUserToFirebase(u)
        if ok, let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u; saveLocalCache() }
        return ok
    }
    
    func setUnlockedCourses(userId: String, courseIds: [String]) async -> Bool {
        guard isAdmin, var u = allUsers.first(where: { $0.id == userId }) else { return false }
        u.unlockedCourseIds = courseIds
        let ok = await saveUserToFirebase(u)
        if ok, let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u; saveLocalCache() }
        return ok
    }
    
    func createUserAsAdmin(name: String, username: String, email: String, password: String, group: UserGroup) async -> (success: Bool, message: String) {
        guard isAdmin else { return (false, "Keine Berechtigung") }
        let un = username.lowercased(), em = email.lowercased()
        if allUsers.contains(where: { $0.username == un }) { return (false, "Username vergeben") }
        if allUsers.contains(where: { $0.email == em }) { return (false, "E-Mail existiert") }
        var u = AppUser.create(name: name, username: un, email: em, password: password, group: group)
        u.isEmailVerified = true
        let ok = await saveUserToFirebase(u)
        if ok { allUsers.append(u); saveLocalCache() }
        return (ok, ok ? "User erstellt" : "Fehler")
    }
    
    // MARK: - Purchase & Courses
    
    func savePurchase(productId: String) async {
        guard var u = currentUser else { return }
        var p = u.purchasedProductIds ?? []
        guard !p.contains(productId) else { return }
        p.append(productId); u.purchasedProductIds = p
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache()
        }
    }
    
    func unlockCourse(courseId: String) async {
        guard var u = currentUser else { return }
        var c = u.unlockedCourseIds ?? []
        guard !c.contains(courseId) else { return }
        c.append(courseId); u.unlockedCourseIds = c
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache()
        }
    }
    
    func addUnlockedCourse(userId: String, courseId: String) async -> Bool {
        guard var u = allUsers.first(where: { $0.id == userId }) else { return false }
        var c = u.unlockedCourseIds ?? []
        guard !c.contains(courseId) else { return true }
        c.append(courseId)
        u.unlockedCourseIds = c
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            if currentUser?.id == userId { currentUser = u }
            saveLocalCache()
            return true
        }
        return false
    }
    
    func hasCourseUnlocked(_ courseId: String) -> Bool { currentUser?.unlockedCourseIds?.contains(courseId) == true }
    
    // MARK: - Trainer Functions
    
    func setTrainerIntroVideo(url: String) async -> Bool {
        guard var u = currentUser, u.group == .trainer || u.group.isAdmin else { return false }
        var p = u.trainerProfile ?? TrainerProfile.empty()
        p.introVideoURL = url; u.trainerProfile = p
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache(); return true
        }
        return false
    }
    
    func updateTrainerLanguages(_ languages: [String]) async -> Bool {
        guard var u = currentUser, u.group == .trainer || u.group.isAdmin else { return false }
        var p = u.trainerProfile ?? TrainerProfile.empty()
        p.teachingLanguages = languages; u.trainerProfile = p
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache(); return true
        }
        return false
    }
    
    func assignCoursesToTrainer(trainerId: String, courseIds: [String]) async -> Bool {
        guard isAdmin, var t = allUsers.first(where: { $0.id == trainerId && $0.group == .trainer }) else { return false }
        var p = t.trainerProfile ?? TrainerProfile.empty()
        p.assignedCourseIds = courseIds; t.trainerProfile = p
        let ok = await saveUserToFirebase(t)
        if ok, let idx = allUsers.firstIndex(where: { $0.id == t.id }) { allUsers[idx] = t; saveLocalCache() }
        return ok
    }
    
    func updateTrainerProfile(_ profile: TrainerProfile) async -> (success: Bool, message: String) {
        guard var u = currentUser else { return (false, "Nicht eingeloggt") }
        u.trainerProfile = profile
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache()
            return (true, "Profil gespeichert")
        }
        return (false, "Fehler")
    }
    
    func updateMarketingConsent(_ consent: Bool) async -> (success: Bool, message: String) {
        guard var u = currentUser else { return (false, "Nicht eingeloggt") }
        u.marketingConsent = consent
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache()
            return (true, "Gespeichert")
        }
        return (false, "Fehler")
    }
    
    // MARK: - Profile
    
    func updateProfileImage(userId: String, imageURL: String) async -> Bool {
        guard var u = allUsers.first(where: { $0.id == userId }) else { return false }
        u.profileImageURL = imageURL.isEmpty ? nil : imageURL
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            if u.id == currentUser?.id { currentUser = u }
            saveLocalCache(); return true
        }
        return false
    }
    
    func updateProfile(name: String? = nil, username: String? = nil, profileImageURL: String? = nil) async -> (success: Bool, message: String) {
        guard var u = currentUser else { return (false, "Nicht eingeloggt") }
        if let n = name, !n.isEmpty { u.name = n }
        if let un = username, !un.isEmpty {
            let normalized = un.lowercased().trimmingCharacters(in: .whitespaces)
            if allUsers.contains(where: { $0.username.lowercased() == normalized && $0.id != u.id }) {
                return (false, "Username vergeben")
            }
            u.username = normalized
        }
        if let url = profileImageURL { u.profileImageURL = url }
        if await saveUserToFirebase(u) {
            if let idx = allUsers.firstIndex(where: { $0.id == u.id }) { allUsers[idx] = u }
            currentUser = u; saveLocalCache()
            return (true, "Profil aktualisiert")
        }
        return (false, "Fehler")
    }
    
    // MARK: - Queries
    
    func getUsersWithMarketingConsent() -> [AppUser] { allUsers.filter { $0.marketingConsent == true && $0.isActive } }
    
    func searchUsers(query: String) -> [AppUser] {
        let q = query.lowercased()
        return allUsers.filter {
            $0.name.lowercased().contains(q) || $0.username.lowercased().contains(q) || $0.email.lowercased().contains(q)
        }
    }
    
    // MARK: - Sync
    
    func loadFromCloud() async { await forceSync() }
    
    func forceSync() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = try await db.collection(usersCollection).getDocuments()
            let users = snap.documents.compactMap { try? $0.data(as: AppUser.self) }
            if !users.isEmpty { allUsers = users; saveLocalCache() }
            if let id = currentUser?.id, let u = allUsers.first(where: { $0.id == id }) { currentUser = u }
            print("✅ Sync: \(allUsers.count) Users")
        } catch { print("❌ Sync Fehler: \(error)"); lastError = error.localizedDescription }
    }
    
    // MARK: - Local Cache
    
    private func saveLocalCache() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(allUsers) { UserDefaults.standard.set(d, forKey: localCacheKey) }
    }
    
    private func loadLocalCache() {
        guard let d = UserDefaults.standard.data(forKey: localCacheKey) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        if let u = try? dec.decode([AppUser].self, from: d) { allUsers = u; restoreSession() }
    }
}
