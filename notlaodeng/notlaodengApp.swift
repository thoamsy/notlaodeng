//
//  notlaodengApp.swift
//  notlaodeng
//
//  Created by yk on 12/1/25.
//

import SwiftUI
import SwiftData

@main
struct notlaodengApp: App {
    let modelContainer: ModelContainer

    init() {
        // SwiftData 配置
        do {
            let schema = Schema([
                UserProfile.self,
                IndicatorTemplate.self,
                HealthRecord.self,
                HealthReport.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }

        #if DEBUG
        // InjectionNext: 从 app bundle 或 InjectionNext.app 加载
        if let path = Bundle.main.path(forResource: "iOSInjection", ofType: "bundle") ??
            Bundle.main.path(forResource: "macOSInjection", ofType: "bundle") {
            Bundle(path: path)!.load()
            print("💉 Loaded injection from app bundle")
        } else if let path = [
            "/Applications/InjectionNext.app/Contents/Resources/iOSInjection.bundle",
            "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle"
        ].first(where: { FileManager.default.fileExists(atPath: $0) }) {
            Bundle(path: path)!.load()
            print("💉 Loaded injection from \(path)")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // 初始化数据
                    let context = modelContainer.mainContext
                    SeedData.seedIndicatorTemplates(modelContext: context)
                }
        }
        .modelContainer(modelContainer)
    }
}
