import Foundation

@MainActor
final class PresentationPlaybackState: ObservableObject {
  let deck: PresentationDeck
  @Published private(set) var currentIndex: Int

  init(deck: PresentationDeck, initialSlideID: Slide.ID?) {
    self.deck = deck
    if let initialSlideID, let index = deck.slides.firstIndex(where: { $0.id == initialSlideID }) {
      currentIndex = index
    } else {
      currentIndex = 0
    }
  }

  var currentSlide: Slide? {
    guard deck.slides.indices.contains(currentIndex) else {
      return nil
    }
    return deck.slides[currentIndex]
  }

  var slideCount: Int {
    deck.slides.count
  }

  var currentSlideNumber: Int {
    min(currentIndex + 1, slideCount)
  }

  func moveNext() {
    guard currentIndex < deck.slides.count - 1 else { return }
    currentIndex += 1
  }

  func movePrevious() {
    guard currentIndex > 0 else { return }
    currentIndex -= 1
  }
}
