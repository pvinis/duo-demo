import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case position, sync, hinge, camera, layout, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .position: "Position"
        case .sync: "Sync"
        case .hinge: "Hinge"
        case .camera: "Camera"
        case .layout: "Layout"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .position: "rectangle.lefthalf.inset.filled"
        case .sync: "arrow.left.arrow.right"
        case .hinge: "book.pages"
        case .camera: "camera"
        case .layout: "square.split.2x1"
        case .about: "info.circle"
        }
    }
}
