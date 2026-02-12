//
//  ImagePicker.swift
//  Tanzen mit Tatiana Drexler
//
//  Ermöglicht das direkte Auswählen und Hochladen von Profilbildern
//

import SwiftUI
import PhotosUI
import Combine

// MARK: - Image Data Helper
extension UIImage {
    func toBase64(compressionQuality: CGFloat = 0.5) -> String? {
        guard let imageData = self.jpegData(compressionQuality: compressionQuality) else { return nil }
        return imageData.base64EncodedString()
    }
    
    func scaled(toMaxSize maxSize: CGFloat) -> UIImage {
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        if scale >= 1.0 { return self }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Profile Image Upload Manager
@MainActor
class ProfileImageManager: ObservableObject {
    static let shared = ProfileImageManager()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var lastError: String?
    
    func uploadProfileImage(_ image: UIImage, for userId: String) async -> (success: Bool, imageURL: String?) {
        isUploading = true
        uploadProgress = 0
        lastError = nil
        defer { isUploading = false }
        
        // Bild skalieren und komprimieren
        let scaledImage = image.scaled(toMaxSize: 300)
        guard let base64String = scaledImage.toBase64(compressionQuality: 0.6) else {
            lastError = "Bild konnte nicht verarbeitet werden"
            return (false, nil)
        }
        
        uploadProgress = 0.5
        
        // Als Data-URL speichern
        let dataURL = "data:image/jpeg;base64,\(base64String)"
        
        // Im UserManager speichern
        let success = await UserManager.shared.updateProfileImage(userId: userId, imageURL: dataURL)
        
        uploadProgress = 1.0
        
        if success {
            return (true, dataURL)
        } else {
            lastError = "Speichern fehlgeschlagen"
            return (false, nil)
        }
    }
}

// MARK: - Profile Image Picker View
struct ProfileImagePickerView: View {
    let userId: String
    @StateObject private var imageManager = ProfileImageManager.shared
    @StateObject private var userManager = UserManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    
    private var currentUser: AppUser? {
        userManager.allUsers.first { $0.id == userId }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: TDSpacing.lg) {
                Spacer()
                
                // Aktuelles/Neues Bild
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.accentGold, lineWidth: 4))
                    } else if let imageURL = currentUser?.profileImageURL, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentGold, lineWidth: 4))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 150, height: 150)
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Text(currentUser?.name ?? "")
                    .font(TDTypography.title2)
                
                Spacer()
                
                // Buttons
                VStack(spacing: TDSpacing.md) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(T("Bild auswählen"))
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(TDRadius.md)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }
                    
                    if selectedImage != nil {
                        Button { Task { await saveImage() } } label: {
                            HStack {
                                if imageManager.isUploading { ProgressView().tint(.white) }
                                else {
                                    Image(systemName: "checkmark")
                                    Text(T("Speichern"))
                                }
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentGold)
                            .foregroundColor(.white)
                            .cornerRadius(TDRadius.md)
                        }
                        .disabled(imageManager.isUploading)
                        
                        Button { selectedImage = nil } label: {
                            Text(T("Abbrechen")).foregroundColor(.red)
                        }
                    }
                    
                    if currentUser?.profileImageURL != nil && selectedImage == nil {
                        Button { Task { await removeImage() } } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text(T("Profilbild entfernen"))
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(T("Profilbild ändern"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(T("Fertig")) { dismiss() }
                }
            }
            .alert(alertSuccess ? "✅ Erfolg" : "❌ Fehler", isPresented: $showAlert) {
                Button(T("OK")) { if alertSuccess { dismiss() } }
            } message: { Text(alertMessage) }
        }
    }
    
    private func saveImage() async {
        guard let image = selectedImage else { return }
        
        let result = await imageManager.uploadProfileImage(image, for: userId)
        alertSuccess = result.success
        alertMessage = result.success ? "Profilbild gespeichert!" : (imageManager.lastError ?? "Fehler")
        showAlert = true
    }
    
    private func removeImage() async {
        let success = await UserManager.shared.updateProfileImage(userId: userId, imageURL: "")
        alertSuccess = success
        alertMessage = success ? "Profilbild entfernt!" : "Fehler beim Entfernen"
        showAlert = true
    }
}
