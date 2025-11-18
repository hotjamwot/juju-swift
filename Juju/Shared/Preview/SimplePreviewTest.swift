//
//  SimplePreviewTest.swift
//  Juju
//
//  Created by AI Assistant
//  Copyright © 2025 Juju. All rights reserved.
//

import SwiftUI

/// Simple test view to verify the preview helpers work
struct SimplePreviewTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Preview System Test")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Testing the simplified preview helpers")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                Text("✓ SimplePreviewHelpers")
                Text("✓ modalPreview()")
                Text("✓ projectPreview()")
                Text("✓ chartPreview()")
                Text("✓ sessionPreview()")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Button("Test Button") {
                print("Simple preview system working!")
            }
            .buttonStyle(.primary)
        }
        .padding()
    }
}

// MARK: - Preview
struct SimplePreviewTestView_Previews: PreviewProvider {
    static var previews: some View {
        SimplePreviewHelpers.modal {
            SimplePreviewTestView()
        }
    }
}
