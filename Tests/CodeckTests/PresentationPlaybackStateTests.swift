import XCTest
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
}
