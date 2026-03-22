import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationPlace {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var isAutoDetected: Bool
    var iconName: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 100,
        isAutoDetected: Bool = false,
        iconName: String = "mappin.circle.fill"
    ) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isAutoDetected = isAutoDetected
        self.iconName = iconName
    }

    static let defaultIcons: [(String, String)] = [
        ("Home", "house.fill"),
        ("Work", "briefcase.fill"),
        ("Gym", "dumbbell.fill"),
        ("School", "graduationcap.fill"),
        ("Cafe", "cup.and.saucer.fill"),
        ("Library", "books.vertical.fill"),
        ("Park", "leaf.fill"),
        ("Other", "mappin.circle.fill"),
    ]
}
