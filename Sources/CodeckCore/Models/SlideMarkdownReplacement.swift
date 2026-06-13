import Foundation

public struct SlideMarkdownReplacement: Hashable, Sendable {
    public let selectedSlideID: Slide.ID
    public let didSplit: Bool
}
