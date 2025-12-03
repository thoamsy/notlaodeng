//
//  Injection.swift
//  notlaodeng
//
//  Hot reload support for InjectionNext
//  https://github.com/johnno1962/InjectionNext
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
                    print("💉 Injected! Counter: \(self?.counter ?? 0)")
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
