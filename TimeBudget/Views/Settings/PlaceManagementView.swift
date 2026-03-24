import SwiftUI
import SwiftData
import MapKit

struct PlaceManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocationPlace.name) private var places: [LocationPlace]
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if places.isEmpty {
                ContentUnavailableView(
                    "No Places Yet",
                    systemImage: "mappin.slash",
                    description: Text("Add your home, work, and gym so TimeBudget can track where you spend time.")
                )
            }

            ForEach(places, id: \.id) { place in
                HStack(spacing: 12) {
                    Image(systemName: place.iconName)
                        .font(.title2)
                        .foregroundStyle(Color(.systemIndigo))
                        .frame(width: 36)

                    VStack(alignment: .leading) {
                        Text(place.name)
                            .font(.headline)
                        Text("\(Int(place.radiusMeters))m radius")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()

                    if place.isAutoDetected {
                        Text("Auto")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemBlue).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .onDelete(perform: deletePlaces)
        }
        .navigationTitle("My Places")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPlaceView()
        }
    }

    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            let place = places[index]
            LocationService.shared.stopMonitoringPlace(place)
            modelContext.delete(place)
        }
    }
}

// MARK: - Add Place View

struct AddPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "mappin.circle.fill"
    @State private var radius: Double = 100
    @State private var position = MapCameraPosition.automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    // Default to London as fallback
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Home, Office, Gym", text: $name)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(LocationPlace.defaultIcons, id: \.0) { label, icon in
                                Button {
                                    selectedIcon = icon
                                    if name.isEmpty { name = label }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == icon ? Color(.systemBlue).opacity(0.2) : Color.clear)
                                            .clipShape(Circle())
                                        Text(label)
                                            .font(.caption2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Location") {
                    Text("Tap the map to set the location")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))

                    Map(position: $position) {
                        if let coord = selectedCoordinate {
                            Marker(name.isEmpty ? "Place" : name, coordinate: coord)
                        }
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { location in
                        // Note: Map tap to coordinate requires MapReader in iOS 17+
                        // For now, use current location as default
                    }
                    .onAppear {
                        if let currentLoc = LocationService.shared.lastKnownLocation {
                            selectedCoordinate = currentLoc.coordinate
                            position = .region(MKCoordinateRegion(
                                center: currentLoc.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            ))
                        }
                    }

                    Button("Use Current Location") {
                        Task {
                            if let loc = await LocationService.shared.requestCurrentLocation() {
                                selectedCoordinate = loc.coordinate
                                position = .region(MKCoordinateRegion(
                                    center: loc.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                ))
                            }
                        }
                    }
                }

                Section("Radius") {
                    VStack {
                        Slider(value: $radius, in: 50...500, step: 25)
                        Text("\(Int(radius)) meters")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlace()
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedCoordinate == nil)
                }
            }
        }
    }

    private func savePlace() {
        guard let coord = selectedCoordinate else { return }

        let place = LocationPlace(
            name: name,
            latitude: coord.latitude,
            longitude: coord.longitude,
            radiusMeters: radius,
            iconName: selectedIcon
        )
        modelContext.insert(place)
        LocationService.shared.startMonitoringPlace(place)
    }
}
