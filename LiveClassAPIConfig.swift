//
//  LiveClassAPIConfig.swift
//  Tanzen mit Tatiana Drexler
//
//  Config for Live Class Cloud Functions
//

import Foundation

struct LiveClassAPIConfig {
    static let functionsBaseURL = "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net"

    static func endpoint(_ path: String) -> URL? {
        URL(string: "\(functionsBaseURL)/\(path)")
    }
}
