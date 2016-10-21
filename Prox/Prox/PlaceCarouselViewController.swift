/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore
import EDSunriseSet

private let MAP_SPAN_DELTA = 0.05
private let MAP_LATITUDE_OFFSET = 0.015

private let ONE_DAY: TimeInterval = (60 * 60) * 24

class PlaceCarouselViewController: UIViewController {

    fileprivate let MIN_SECS_BETWEEN_LOCATION_UPDATES: TimeInterval = 1
    fileprivate var timeOfLastLocationUpdate: Date?

    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()

    // the top part of the background. Contains Number of Places, horizontal line & (soon to be) Current Location button
    lazy var headerView: PlaceCarouselHeaderView = {
        let view = PlaceCarouselHeaderView()
        return view
    }()

    // View that will display the sunset and sunrise times
    lazy var sunView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.carouselViewPlaceCardBackground

        view.layer.shadowColor = UIColor.darkGray.cgColor
        view.layer.shadowOpacity = 0.25
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 2
        view.layer.shouldRasterize = true

        return view
    }()

    // the map view
    lazy var mapView: MKMapView = {
        let view = MKMapView()
        view.translatesAutoresizingMaskIntoConstraints = false

        view.showsUserLocation = true
        view.isUserInteractionEnabled = false
        view.delegate = self
        return view
    }()

    // label displaying sunrise and sunset times
    lazy var sunriseSetTimesLabel: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewSunriseSetTimesLabelText
        label.font = Fonts.carouselViewSunriseSetTimes
        return label
    }()

    lazy var placeCarousel = PlaceCarousel()

    var sunriseSet: EDSunriseSet? {
        didSet {
            setSunriseSetTimes()
        }
    }

    private func setSunriseSetTimes() {
        let today = Date()

        guard let sunriseSet = self.sunriseSet else {
            return self.sunriseSetTimesLabel.text = nil
        }

        sunriseSet.calculateSunriseSunset(today)

        guard let sunrise = sunriseSet.localSunrise(),
            let sunset = sunriseSet.localSunset(),
            let calendar = NSCalendar(identifier: NSCalendar.Identifier.gregorian) else {
                return self.sunriseSetTimesLabel.text = nil
        }

        let sunriseToday = updateDateComponents(dateComponents: sunrise, toDate: today, withCalendar: calendar)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"

        if let sunriseTime = calendar.date(from: sunriseToday),
            sunriseTime > today {
            let timeAsString = dateFormatter.string(from: sunriseTime)
            return self.sunriseSetTimesLabel.text = "Sunrise is at \(timeAsString) today"
        }

        let sunsetToday = updateDateComponents(dateComponents: sunset, toDate: today, withCalendar: calendar)

        if let sunsetTime = calendar.date(from: sunsetToday),
            sunsetTime > today {
            let timeAsString = dateFormatter.string(from: sunsetTime)
            return self.sunriseSetTimesLabel.text = "Sunset is at \(timeAsString) today"
        }

        let tomorrow = today.addingTimeInterval(ONE_DAY)
        sunriseSet.calculateSunriseSunset(tomorrow)
        if let tomorrowSunrise = sunriseSet.localSunrise(),
            let tomorrowSunriseTime = calendar.date(from: tomorrowSunrise) {
            let timeAsString = dateFormatter.string(from: tomorrowSunriseTime)
            self.sunriseSetTimesLabel.text = "Sunrise is at \(timeAsString) tomorrow"
        } else {
            self.sunriseSetTimesLabel.text = nil
        }
    }

    private func updateDateComponents(dateComponents: DateComponents, toDate date: Date, withCalendar calendar: NSCalendar) -> DateComponents {
        var newDateComponents = dateComponents
        newDateComponents.day = calendar.component(NSCalendar.Unit.day, from: date)
        newDateComponents.month = calendar.component(NSCalendar.Unit.month, from: date)
        newDateComponents.year = calendar.component(NSCalendar.Unit.year, from: date)

        return newDateComponents
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // add the views to the stack view
        view.addSubview(headerView)

        // setting up the layout constraints
        var constraints = [headerView.topAnchor.constraint(equalTo: view.topAnchor),
                           headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           headerView.heightAnchor.constraint(equalToConstant: 150)]

        view.addSubview(sunView)
        constraints.append(contentsOf: [sunView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
                                        sunView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        sunView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        sunView.heightAnchor.constraint(equalToConstant: 90)])

        view.insertSubview(mapView, belowSubview: sunView)
        constraints.append(contentsOf: [mapView.topAnchor.constraint(equalTo: sunView.bottomAnchor),
                                        mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])


        // set up the subviews for the sunrise/set view
        sunView.addSubview(sunriseSetTimesLabel)
        constraints.append(sunriseSetTimesLabel.leadingAnchor.constraint(equalTo: sunView.leadingAnchor, constant: 20))
        constraints.append(sunriseSetTimesLabel.topAnchor.constraint(equalTo: sunView.topAnchor, constant: 14))

        // placeholder text for the labels
        headerView.numberOfPlacesLabel.text = "4 places"

        view.addSubview(placeCarousel.carousel)
        constraints.append(contentsOf: [placeCarousel.carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        placeCarousel.carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        placeCarousel.carousel.topAnchor.constraint(equalTo: sunView.bottomAnchor, constant: -35),
                                        placeCarousel.carousel.heightAnchor.constraint(equalToConstant: 275)])

        // apply the constraints
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    func refreshLocation() {
        if (CLLocationManager.hasLocationPermissionAndEnabled()) {
            locationManager.requestLocation()
        } else {
            // requestLocation expected to be called on authorization status change.
            locationManager.maybeRequestLocationPermission(viewController: self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension PlaceCarouselViewController: MKMapViewDelegate {
    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        // TODO: handle.
        print("lol-map \(error.localizedDescription)")
    }
}

extension PlaceCarouselViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        refreshLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use last coord: we want to display where the user is now.
        if let location = locations.last {
            // In iOS9, didUpdateLocations can be unexpectedly called multiple
            // times for a single `requestLocation`: we guard against that here.
            let now = Date()
            if timeOfLastLocationUpdate == nil ||
                (now - MIN_SECS_BETWEEN_LOCATION_UPDATES) > timeOfLastLocationUpdate! {
                timeOfLastLocationUpdate = now
                updateLocation(manager, location: location)
            }
        }
    }

    private func updateLocation(_ manager: CLLocationManager, location: CLLocation) {
        let coord = location.coordinate
        // Offset center to display user's location below place cards.
        let center = CLLocationCoordinate2D(latitude: coord.latitude + MAP_LATITUDE_OFFSET, longitude: coord.longitude)
        let span = MKCoordinateSpan(latitudeDelta: MAP_SPAN_DELTA, longitudeDelta: 0.0)
        mapView.region = MKCoordinateRegion(center: center, span: span)

        FirebasePlacesDatabase().getPlaces(forLocation: location).upon(DispatchQueue.main) { places in
            self.placeCarousel.places = places.flatMap { $0.successResult() }
        }

        self.placeCarousel.currentLocation = location

        // if we're running in the simulator, find the timezone of the current coordinates and calculate the sunrise/set times for then
        // this is so that, if we're simulating our location, we still get sunset/sunrise times
        #if (arch(i386) || arch(x86_64))
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async() {
                        self.sunriseSet = EDSunriseSet(timezone: placemark.timeZone, latitude: coord.latitude, longitude: coord.longitude)
                    }
                }
            }
        #else
            sunriseSet = EDSunriseSet(timezone: NSTimeZone.local, latitude: coord.latitude, longitude: coord.longitude)
        #endif
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // TODO: handle
        print("lol-location \(error.localizedDescription)")
    }
}

