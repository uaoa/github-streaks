// TestFile.swift
// Simple test to verify all imports and basic functionality work

import SwiftUI
import Foundation
import Combine

struct TestView: View {
    var body: some View {
        VStack {
            Text("Test")
                .enhancedGlassBackground()
            
            Button("Test Button") {
                print("Test button pressed")
            }
            .buttonStyle(.bordered)
        }
    }
}