import SwiftUI

/// Cross-platform navigation chrome. The app shell targets iOS, iPadOS, and
/// macOS from one SwiftUI codebase; `navigationBarTitleDisplayMode` and the
/// `topBar*` toolbar placements are UIKit-only, so these shims resolve to the
/// native equivalent per platform and keep the call sites free of `#if` noise.
public extension View {
    /// Inline navigation title on iOS/iPadOS; a no-op on macOS, where the title
    /// is rendered by the window chrome and the modifier does not exist.
    @ViewBuilder
    func inwardInlineTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }

    /// Full-screen cover on iOS/iPadOS; a sheet on macOS, where modal content is
    /// presented as a window sheet and `fullScreenCover` does not exist.
    @ViewBuilder
    func inwardFullCover(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        #if os(iOS)
            fullScreenCover(isPresented: isPresented, content: content)
        #else
            sheet(isPresented: isPresented, content: content)
        #endif
    }
}

public extension ToolbarItemPlacement {
    /// Leading toolbar slot: the navigation bar's leading edge on iOS/iPadOS,
    /// the window's navigation area on macOS.
    static var inwardLeading: ToolbarItemPlacement {
        #if os(iOS)
            .topBarLeading
        #else
            .navigation
        #endif
    }

    /// Trailing toolbar slot: the navigation bar's trailing edge on iOS/iPadOS,
    /// the primary-action area on macOS.
    static var inwardTrailing: ToolbarItemPlacement {
        #if os(iOS)
            .topBarTrailing
        #else
            .primaryAction
        #endif
    }
}
