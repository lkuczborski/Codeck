import Foundation

struct SlideTemplateSection: Identifiable, Hashable {
  let id: String
  let title: String
  let templates: [SlideTemplate]
}
