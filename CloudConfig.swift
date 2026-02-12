//
//  CloudConfig.swift
//  Tanzen mit Tatiana Drexler
//
//  Konfiguration für Cloud-Dienste
//  - Firebase für Daten (siehe FirebaseService.swift)
//  - Cloudflare R2 / Backblaze B2 / GitHub für Videos
//

import Foundation

struct CloudConfig {
    
    // ============================================================
    // VIDEO HOSTING - Wähle eine Option:
    //
    // Option 1: Cloudflare R2 (10 GB kostenlos/Monat)
    // Option 2: Backblaze B2 (10 GB kostenlos)
    // Option 3: GitHub Releases (unbegrenzt für öffentliche Repos)
    // Option 4: Eigener Webserver
    // ============================================================
    
    /// Base-URL für Videos (mit / am Ende)
    /// Beispiele:
    /// - Cloudflare R2: "https://pub-xxxx.r2.dev/videos/"
    /// - Backblaze B2: "https://f005.backblazeb2.com/file/bucket-name/videos/"
    /// - GitHub: "https://github.com/user/repo/releases/download/v1.0/"
    /// - Eigener Server: "https://deine-domain.de/videos/"
    static let videoBaseURL = "https://pub-fd7fee8eb403484a8202aebe4eddd8fe.r2.dev/videos/"
    
    /// Prüft ob die Video-Konfiguration vollständig ist
    static var isConfigured: Bool {
        videoBaseURL != "DEINE-VIDEO-URL/"
    }
    
    /// Gibt die vollständige Video-URL zurück
    static func videoURL(for filename: String) -> URL? {
        if videoBaseURL == "DEINE-VIDEO-URL/" {
            return nil
        }
        return URL(string: videoPath(for: filename))
    }
    
    /// Gibt die vollständige Video-URL als String zurück (ordnerunabhängig)
    static func videoPath(for filename: String) -> String {
        if videoBaseURL == "DEINE-VIDEO-URL/" {
            return ""
        }
        // Wenn bereits eine Endung vorhanden ist, nichts anhängen
        let hasExtension = filename.contains(".")
        let suffix = hasExtension ? "" : ".mp4"
        return "\(videoBaseURL)\(filename)\(suffix)"
    }
}
