# InjectionNext 热重载配置指南

> 适用于 Xcode 16.3+ / Xcode 26 Beta + Cursor 编辑器

## 概述

[InjectionNext](https://github.com/johnno1962/InjectionNext) 是 InjectionIII 的第四代实现，支持在不重启 App 的情况下实时更新 Swift/SwiftUI 代码。

## 前置条件

- macOS
- Xcode 16.3+ 或 Xcode 26
- iOS 模拟器
- [InjectionNext.app](https://github.com/johnno1962/InjectionNext/releases) (从 GitHub Release 下载，**不是** App Store 版本)

## 配置步骤

### 1. 安装 InjectionNext

```bash
# 下载后移动到 /Applications
mv ~/Downloads/InjectionNext.app /Applications/
```

### 2. 添加链接器标志

在 Xcode 中：

1. 选择 Project → Target → Build Settings
2. 搜索 `Other Linker Flags`
3. 在 **Debug** 配置中添加：
   ```
   -Xlinker
   -interposable
   ```

或者直接编辑 `project.pbxproj`，在 Debug 配置的 buildSettings 中添加：

```
OTHER_LDFLAGS = (
    "-Xlinker",
    "-interposable",
);
```

### 3. 添加 EMIT_FRONTEND_COMMAND_LINES (Xcode 16.3+ 必需)

在 Xcode 中：

1. Build Settings → 点击 "+" → Add User-Defined Setting
2. 名称：`EMIT_FRONTEND_COMMAND_LINES`
3. 值：`YES`

或者在 `project.pbxproj` 的 Debug 配置中添加：

```
EMIT_FRONTEND_COMMAND_LINES = YES;
```

### 4. 添加热重载支持代码

创建 `Injection.swift`：

```swift
//
//  Injection.swift
//  热重载支持
//

import SwiftUI

#if DEBUG
import Combine

@propertyWrapper
public struct ObserveInjection: DynamicProperty {
    @ObservedObject private var observer = Injection.observer
    public init() {}
    public var wrappedValue: Int { observer.counter }
}

public enum Injection {
    public static let observer = Observer()

    public final class Observer: ObservableObject {
        @Published public private(set) var counter = 0
        private var cancellable: AnyCancellable?

        fileprivate init() {
            cancellable = NotificationCenter.default
                .publisher(for: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.counter += 1
                }
        }
    }
}

extension View {
    public func enableInjection() -> some View { self }
    public func eraseToAnyView() -> AnyView { AnyView(self) }
}
#else
@propertyWrapper
public struct ObserveInjection: DynamicProperty {
    public init() {}
    public var wrappedValue: Int { 0 }
}

extension View {
    @inlinable public func enableInjection() -> some View { self }
    @inlinable public func eraseToAnyView() -> AnyView { AnyView(self) }
}
#endif
```

### 5. 修改 App 入口加载 Injection Bundle

在 `YourApp.swift` 中：

```swift
import SwiftUI

@main
struct YourApp: App {
    init() {
        #if DEBUG
        // InjectionNext: 从 app bundle 或 InjectionNext.app 加载
        if let path = Bundle.main.path(forResource: "iOSInjection", ofType: "bundle") ??
            Bundle.main.path(forResource: "macOSInjection", ofType: "bundle") {
            Bundle(path: path)!.load()
        } else if let path = [
            "/Applications/InjectionNext.app/Contents/Resources/iOSInjection.bundle",
            "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle"
        ].first(where: { FileManager.default.fileExists(atPath: $0) }) {
            Bundle(path: path)!.load()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 6. 在 SwiftUI View 中启用热重载

```swift
struct ContentView: View {
    @ObserveInjection var forceRedraw  // 添加这行

    var body: some View {
        VStack {
            Text("Hello, World!")
        }
        .id(forceRedraw)       // 添加这行
        .eraseToAnyView()      // 添加这行
    }
}
```

## 使用步骤

### 首次设置

1. **打开 InjectionNext.app**

   ```bash
   open /Applications/InjectionNext.app
   ```

2. **在 Xcode 中构建并运行 App (⌘R)**

   - 这一步会生成 InjectionNext 需要的构建日志
   - 之后可以关闭 Xcode

3. **在 InjectionNext 菜单栏中选择 "...or Watch Project"**

   - 选择你的项目根目录

4. **确认连接状态**
   - 🟠 橙色 = App 已连接，可以开始热重载

### 日常使用

1. 启动 InjectionNext.app
2. 在模拟器中运行 App（可以用 `xcrun simctl launch`）
3. 在 Cursor 中编辑代码
4. 保存文件 (⌘S)
5. 模拟器自动更新 ✨

### InjectionNext 图标颜色含义

| 颜色    | 含义           |
| ------- | -------------- |
| 🔵 蓝色 | 刚启动         |
| 🟣 紫色 | 已启动 Xcode   |
| 🟠 橙色 | **App 已连接** |
| 🟢 绿色 | 正在重新编译   |
| 🟡 黄色 | 编译失败       |

## 常见问题

### Q: 图标一直是黄色（编译失败）

A: 可能是构建日志缺失或过期。在 Xcode 中重新构建一次项目。

### Q: 修改后没有更新

A: 确保：

1. View 中有 `@ObserveInjection var forceRedraw`
2. body 末尾有 `.id(forceRedraw).eraseToAnyView()`
3. InjectionNext 图标是橙色

### Q: 添加新文件后热重载失效

A: 需要在 Xcode 中重新构建一次，更新构建日志。

### Q: 关闭 Xcode 后还能用吗？

A: 可以！InjectionNext 使用的是 DerivedData 中保存的构建日志。

## 快捷命令

```bash
# 启动模拟器
xcrun simctl boot "iPhone 16e"

# 安装并运行 App
xcrun simctl install booted /path/to/YourApp.app
xcrun simctl launch booted com.yourcompany.yourapp

# 查看 App 日志
xcrun simctl spawn booted log stream --predicate 'process == "YourApp"'
```

## 参考链接

- [InjectionNext GitHub](https://github.com/johnno1962/InjectionNext)
- [InjectionIII GitHub](https://github.com/johnno1962/InjectionIII)
- [HotSwiftUI](https://github.com/nicholascm/HotSwiftUI) - SwiftUI 热重载辅助库

---

_最后更新：2025-12-03_
