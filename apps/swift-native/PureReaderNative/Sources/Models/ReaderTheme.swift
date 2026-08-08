//
//  ReaderTheme.swift
//  PureReader
//
//  Created by OpenSpec on 2026-02-21.
//

import SwiftUI

struct ReaderTheme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let backgroundColor: String  // Hex color
    let textColor: String
    let uiOverlayColor: String
    let accentColor: String
    
    // Convert hex string to Color
    var backgroundColorValue: Color {
        Color(hex: backgroundColor)
    }
    
    var textColorValue: Color {
        Color(hex: textColor)
    }
    
    var uiOverlayColorValue: Color {
        Color(hex: uiOverlayColor)
    }
    
    var accentColorValue: Color {
        Color(hex: accentColor)
    }
    
    // Presets
    static let day = ReaderTheme(
        id: "day",
        name: "Day",
        backgroundColor: "#F9F7F1",
        textColor: "#333333",
        uiOverlayColor: "#EBE8DF",
        accentColor: "#555555"
    )
    
    static let night = ReaderTheme(
        id: "night",
        name: "Night",
        backgroundColor: "#1E1E1E",
        textColor: "#B0B0B0",
        uiOverlayColor: "#2C2C2C",
        accentColor: "#888888"
    )
    
    static let muji = ReaderTheme(
        id: "muji",
        name: "Muji",
        backgroundColor: "#F4ECD8",
        textColor: "#3B312A",
        uiOverlayColor: "#E6DBBF",
        accentColor: "#7D705C"
    )
    
    static let forest = ReaderTheme(
        id: "forest",
        name: "Forest",
        backgroundColor: "#E3EDCD",
        textColor: "#2E4033",
        uiOverlayColor: "#D3E0BA",
        accentColor: "#5A7561"
    )
    
    static let allThemes = [day, night, muji, forest]
    
    static func fromId(_ id: String) -> ReaderTheme {
        allThemes.first { $0.id == id } ?? day
    }
}

// Color extension to support hex strings
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

