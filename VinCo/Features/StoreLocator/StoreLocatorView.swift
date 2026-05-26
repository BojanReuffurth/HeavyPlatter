import SwiftUI
import MapKit
import CoreLocation
import ComposableArchitecture

// MARK: – Vinyl store model (local only, not persisted)
struct VinylStore: Identifiable {
    let id        = UUID()
    let name:      String
    let address:   String
    let coordinate: CLLocationCoordinate2D
    let distance:  CLLocationDistance   // metres
    let mapItem:   MKMapItem

    var distanceText: String {
        if Locale.current.measurementSystem == .metric {
            return distance < 1000
                ? String(format: "%.0f m",  distance)
                : String(format: "%.1f km", distance / 1000)
        } else {
            let miles = distance / 1609.344
            return miles < 0.1
                ? String(format: "%.0f ft", distance * 3.28084)
                : String(format: "%.1f mi", miles)
        }
    }
}

// MARK: – CLLocationManager wrapper
@Observable
final class VinCoLocationManager: NSObject, CLLocationManagerDelegate {
    private let clm = CLLocationManager()

    var authStatus: CLAuthorizationStatus = .notDetermined
    var location:   CLLocation?
    private(set) var locationTick = 0       // increments each time location arrives

    override init() {
        super.init()
        clm.delegate = self
        clm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = clm.authorizationStatus
    }

    func requestWhenInUse() { clm.requestWhenInUseAuthorization() }
    func requestLocation()  { clm.requestLocation() }

    // MARK: – Delegate (nonisolated – dispatch back to MainActor)
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                self.clm.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.location  = locations.last
            self.locationTick += 1
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) { /* silent */ }
}

// MARK: – Main view
struct StoreLocatorView: View {
    @Bindable var store: StoreOf<StoreLocatorFeature>
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss)     private var dismiss

    @State private var locMgr       = VinCoLocationManager()
    @State private var vinylStores: [VinylStore] = []
    @State private var isSearching  = false
    @State private var selectedID:  UUID? = nil
    @State private var cameraPos:   MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            header

            Rectangle().fill(Theme.divide).frame(height: 1)

            // ── Map (top half) ───────────────────────────────────────────────
            mapView
                .frame(maxHeight: .infinity)

            Rectangle().fill(Theme.divide).frame(height: 1)

            // ── Store list (bottom half) ─────────────────────────────────────
            storeList
                .frame(maxHeight: .infinity)
        }
        .background(settings.bg0)
        .preferredColorScheme(settings.preferredScheme)
        // Initial authorization request
        .task {
            switch locMgr.authStatus {
            case .notDetermined:
                locMgr.requestWhenInUse()
            case .authorizedWhenInUse, .authorizedAlways:
                locMgr.requestLocation()
            default:
                break
            }
        }
        // Re-fire whenever location arrives
        .task(id: locMgr.locationTick) {
            guard let loc = locMgr.location else { return }
            withAnimation {
                cameraPos = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    latitudinalMeters: 8_000,
                    longitudinalMeters: 8_000
                ))
            }
            await searchStores(near: loc)
        }
    }

    // MARK: – Header
    private var header: some View {
        ModalNavBar("Store Locator", onClose: { dismiss() })
    }

    // MARK: – Map
    private var mapView: some View {
        Map(position: $cameraPos) {
            UserAnnotation()
            ForEach(vinylStores) { s in
                Annotation(s.name, coordinate: s.coordinate, anchor: .bottom) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: selectedID == s.id ? 26 : 20))
                        .foregroundStyle(selectedID == s.id
                                         ? settings.accentColor : Theme.textS)
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                        .animation(.spring(response: 0.3), value: selectedID)
                        .onTapGesture { selectedID = s.id }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .all))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .overlay { authOverlay }
    }

    // Overlay shown when location is denied
    @ViewBuilder
    private var authOverlay: some View {
        if locMgr.authStatus == .denied || locMgr.authStatus == .restricted {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.textT)

                    Text("Location access is off")
                        .font(Theme.courier(15, .semibold))
                        .foregroundStyle(Theme.textP)

                    Text("Enable location in Settings\nto find vinyl stores near you.")
                        .font(Theme.courier(12))
                        .foregroundStyle(Theme.textS)
                        .multilineTextAlignment(.center)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(Theme.courier(13, .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(settings.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
            }
        }
    }

    // MARK: – Store list
    private var storeList: some View {
        VStack(spacing: 0) {
            listHeader
            Rectangle().fill(Theme.divide).frame(height: 1)

            if vinylStores.isEmpty && !isSearching && locMgr.location != nil {
                emptyStores
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vinylStores) { s in
                            storeRow(s)
                            Rectangle().fill(Theme.divide).frame(height: 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            if isSearching {
                ProgressView()
                    .tint(settings.accentColor)
                    .scaleEffect(0.75)
                Text("Searching…")
                    .font(Theme.courier(12))
                    .foregroundStyle(Theme.textS)
            } else if locMgr.authStatus == .denied || locMgr.authStatus == .restricted {
                Image(systemName: "location.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textT)
                Text("Location disabled")
                    .font(Theme.courier(12))
                    .foregroundStyle(Theme.textT)
            } else if locMgr.location == nil {
                Image(systemName: "location.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textT)
                Text("Waiting for location…")
                    .font(Theme.courier(12))
                    .foregroundStyle(Theme.textT)
            } else if vinylStores.isEmpty {
                Image(systemName: "music.note.house")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textT)
                Text("No stores found nearby")
                    .font(Theme.courier(12))
                    .foregroundStyle(Theme.textT)
            } else {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(settings.accentColor)
                Text("\(vinylStores.count) store\(vinylStores.count == 1 ? "" : "s") nearby")
                    .font(Theme.courier(12, .semibold))
                    .foregroundStyle(Theme.textS)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settings.bg1)
    }

    private var emptyStores: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.house")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textT)
            Text("No vinyl stores found\nwithin 15 km")
                .font(Theme.courier(13))
                .foregroundStyle(Theme.textS)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func storeRow(_ s: VinylStore) -> some View {
        HStack(spacing: 12) {
            // Icon bubble
            ZStack {
                Circle()
                    .fill(selectedID == s.id
                          ? settings.accentColor.opacity(0.18)
                          : settings.bg2)
                    .frame(width: 40, height: 40)
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(selectedID == s.id ? settings.accentColor : Theme.textS)
            }
            .animation(.spring(response: 0.3), value: selectedID)

            // Name + address
            VStack(alignment: .leading, spacing: 3) {
                Text(s.name)
                    .font(Theme.courier(13, .semibold))
                    .foregroundStyle(Theme.textP)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(s.distanceText)
                        .font(Theme.courier(11, .semibold))
                        .foregroundStyle(settings.accentColor)

                    if !s.address.isEmpty {
                        Text("·")
                            .foregroundStyle(Theme.textT)
                            .font(Theme.courier(11))
                        Text(s.address)
                            .font(Theme.courier(11))
                            .foregroundStyle(Theme.textS)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Directions button
            Button {
                s.mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(settings.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(selectedID == s.id
                    ? settings.accentColor.opacity(0.06)
                    : settings.bg0)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedID = s.id
            withAnimation(.spring(response: 0.4)) {
                cameraPos = .region(MKCoordinateRegion(
                    center: s.coordinate,
                    latitudinalMeters: 2_500,
                    longitudinalMeters: 2_500
                ))
            }
        }
    }

    // MARK: – MKLocalSearch
    @MainActor
    private func searchStores(near location: CLLocation) async {
        isSearching = true
        defer { isSearching = false }

        // Try multiple queries to maximise coverage
        let queries = ["vinyl record store", "record shop", "music store vinyl records"]
        var seenKeys = Set<String>()
        var found: [VinylStore] = []

        for query in queries {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = query
            req.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 15_000,
                longitudinalMeters: 15_000
            )
            req.resultTypes = .pointOfInterest

            guard let resp = try? await MKLocalSearch(request: req).start() else { continue }

            for item in resp.mapItems {
                // Extract location fields — use iOS 26 API where available, else fall back to placemark.
                let coordinate: CLLocationCoordinate2D
                let itemLoc:    CLLocation?
                let address:    String
                if #available(iOS 26, *) {
                    coordinate = item.location.coordinate
                    itemLoc    = item.location
                    address    = item.address?.shortAddress ?? item.address?.fullAddress ?? ""
                } else {
                    let pl     = item.placemark
                    coordinate = pl.coordinate
                    itemLoc    = pl.location
                    address    = [pl.thoroughfare, pl.locality].compactMap { $0 }.joined(separator: ", ")
                }

                // De-duplicate by rounded coordinate
                let key = String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
                guard !seenKeys.contains(key) else { continue }
                seenKeys.insert(key)
                guard let itemLoc else { continue }

                found.append(VinylStore(
                    name:       item.name ?? "Record Store",
                    address:    address,
                    coordinate: coordinate,
                    distance:   location.distance(from: itemLoc),
                    mapItem:    item
                ))
            }
        }

        vinylStores = found.sorted { $0.distance < $1.distance }
    }
}
