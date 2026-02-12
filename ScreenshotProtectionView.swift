//
//  ScreenshotProtectionView.swift
//  Tanzen mit Tatiana Drexler
//
//  Schützt Inhalte vor Screenshots und Bildschirmaufnahmen
//

import SwiftUI
import UIKit

// MARK: - Screenshot Protection Modifier
struct ScreenshotProtection: ViewModifier {
    @State private var isRecording = false
    @State private var screenshotTaken = false
    
    func body(content: Content) -> some View {
        ZStack {
            // Der geschützte Inhalt
            content
                .opacity(isRecording ? 0 : 1)
            
            // Overlay wenn Aufnahme aktiv
            if isRecording {
                recordingBlocker
            }
            
            // Screenshot-Warnung
            if screenshotTaken {
                screenshotWarning
            }
        }
        .onAppear {
            setupNotifications()
            checkScreenRecording()
        }
        .onDisappear {
            removeNotifications()
        }
    }
    
    // MARK: - Recording Blocker
    private var recordingBlocker: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: TDSpacing.lg) {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text(T("Bildschirmaufnahme erkannt"))
                    .font(TDTypography.title2)
                    .foregroundColor(.white)
                
                Text(T("Aus urheberrechtlichen Gründen ist das Aufnehmen von Videos nicht erlaubt."))
                    .font(TDTypography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TDSpacing.xl)
                
                Text(T("Bitte beende die Aufnahme, um fortzufahren."))
                    .font(TDTypography.caption1)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Screenshot Warning
    private var screenshotWarning: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.white)
                Text(T("Screenshots sind nicht erlaubt"))
                    .font(TDTypography.subheadline)
                    .foregroundColor(.white)
            }
            .padding(TDSpacing.md)
            .background(Color.red.opacity(0.9))
            .cornerRadius(TDRadius.md)
            .padding(.bottom, TDSpacing.xxl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: screenshotTaken)
    }
    
    // MARK: - Setup Notifications
    private func setupNotifications() {
        // Screenshot Detection
        NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                screenshotTaken = true
            }
            
            // Warnung nach 3 Sekunden ausblenden
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    screenshotTaken = false
                }
            }
        }
        
        // Screen Recording Detection
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            checkScreenRecording()
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIScreen.capturedDidChangeNotification, object: nil)
    }
    
    private func checkScreenRecording() {
        isRecording = UIScreen.main.isCaptured
    }
}

// MARK: - Secure Video Container (für AVPlayer)
struct SecureVideoContainer: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = SecurePlayerView()
        view.backgroundColor = .black
        
        if let player = player {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = view.bounds
            playerLayer.videoGravity = .resizeAspect
            view.layer.addSublayer(playerLayer)
            view.playerLayer = playerLayer
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let secureView = uiView as? SecurePlayerView,
           let playerLayer = secureView.playerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Secure Player View
class SecurePlayerView: UIView {
    var playerLayer: AVPlayerLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSecureTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSecureTextField()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
        
        // Update secure text field
        if let textField = subviews.first(where: { $0 is UITextField }) as? UITextField {
            textField.frame = bounds
        }
    }
    
    private func setupSecureTextField() {
        // Nutze einen sicheren Text Field Layer um Screenshots zu blockieren
        // Dies ist ein bekannter iOS Trick
        let textField = UITextField()
        textField.isSecureTextEntry = true
        textField.isUserInteractionEnabled = false
        textField.frame = bounds
        textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Füge den secure layer hinzu
        if let secureLayer = textField.layer.sublayers?.first {
            secureLayer.frame = bounds
            layer.addSublayer(secureLayer)
        }
        
        addSubview(textField)
        textField.layer.sublayers?.first?.addSublayer(layer)
    }
}

// MARK: - View Extension
extension View {
    func screenshotProtected() -> some View {
        modifier(ScreenshotProtection())
    }
}

// MARK: - Import for AVPlayer
import AVKit
