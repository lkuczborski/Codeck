import XCTest
@testable import CodeckCore
@testable import Codeck

@MainActor
final class PresentationPlaybackStateTests: XCTestCase {
  func testStartsFromSelectedSlideAndMovesWithinBounds() {
    let first = Slide(markdown: "# One")
    let second = Slide(markdown: "# Two")
    let third = Slide(markdown: "# Three")
    let deck = PresentationDeck(theme: .studio, slides: [first, second, third])
    let state = PresentationPlaybackState(deck: deck, initialSlideID: second.id)

    XCTAssertEqual(state.currentSlide?.id, second.id)
    XCTAssertEqual(state.currentSlideNumber, 2)

    state.moveNext()
    XCTAssertEqual(state.currentSlide?.id, third.id)

    state.moveNext()
    XCTAssertEqual(state.currentSlide?.id, third.id)

    state.movePrevious()
    state.movePrevious()
    state.movePrevious()
    XCTAssertEqual(state.currentSlide?.id, first.id)
  }

  func testFallsBackToFirstSlideWhenInitialSelectionIsMissing() {
    let first = Slide(markdown: "# One")
    let second = Slide(markdown: "# Two")
    let deck = PresentationDeck(theme: .studio, slides: [first, second])

    let state = PresentationPlaybackState(deck: deck, initialSlideID: UUID())

    XCTAssertEqual(state.currentSlide?.id, first.id)
    XCTAssertEqual(state.currentSlideNumber, 1)
    XCTAssertEqual(state.slideCount, 2)
  }
}
