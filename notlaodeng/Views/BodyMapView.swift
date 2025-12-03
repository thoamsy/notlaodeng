//
//  BodyMapView.swift
//  notlaodeng
//
//  人体地图视图（占位）
//

import SwiftUI

struct BodyMapView: View {
    @ObserveInjection var forceRedraw

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Body Map", systemImage: "figure.stand")
            } description: {
                Text("Interactive body map coming soon.")
            }
            .navigationTitle("Body Map")
        }
        .id(forceRedraw)
        .eraseToAnyView()
    }
}

#Preview {
    BodyMapView()
}

