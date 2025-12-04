//
//  MainTabView.swift
//  notlaodeng
//
//  主 Tab 视图
//

import SwiftUI

struct MainTabView: View {
    @ObserveInjection var forceRedraw

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            IndicatorListView()
                .tabItem {
                    Label("Indicators", systemImage: "list.bullet.clipboard")
                }
                .tag(0)

            BodyMapView()
                .tabItem {
                    Label("Body Map", systemImage: "figure.stand")
                }
                .tag(1)

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
        }
        .id(forceRedraw)
        .tabBarMinimizeBehavior(.onScrollDown)
        .eraseToAnyView()
    }
}

#Preview {
    MainTabView()
}
