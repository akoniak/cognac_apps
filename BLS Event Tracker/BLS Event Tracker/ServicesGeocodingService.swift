//
//  GeocodingService.swift
//  Community Status App
//
//  Handles address geocoding using Apple's MapKit
//

import Foundation
import MapKit
import CoreLocation

class GeocodingService {
    static let shared = GeocodingService()
    
    private init() {}
    
    /// Geocode an address string to coordinates
    /// Returns the first matching result within the community bounds
    func geocodeAddress(_ address: String, nearCommunity community: Community? = nil) async throws -> GeocodedLocation {
        let geocoder = CLGeocoder()
        
        let placemarks = try await geocoder.geocodeAddressString(address)
        
        guard let placemark = placemarks.first,
              let location = placemark.location else {
            throw GeocodingError.noResults
        }
        
        // If community bounds provided, verify location is within reasonable distance
        if let community = community {
            let communityCenter = CLLocation(
                latitude: community.centerLatitude,
                longitude: community.centerLongitude
            )
            let distance = location.distance(from: communityCenter)
            
            // If address is more than 2x the community radius away, it's probably wrong
            if distance > (community.radiusMeters * 2) {
                throw GeocodingError.outsideCommunityBounds
            }
        }
        
        return GeocodedLocation(
            address: formatAddress(from: placemark),
            coordinate: location.coordinate,
            placemark: placemark
        )
    }
    
    /// Reverse geocode coordinates to an address
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedLocation {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }
        
        return GeocodedLocation(
            address: formatAddress(from: placemark),
            coordinate: coordinate,
            placemark: placemark
        )
    }
    
    /// Format a placemark into a readable address
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let street = placemark.thoroughfare {
            var streetAddress = street
            if let number = placemark.subThoroughfare {
                streetAddress = "\(number) \(street)"
            }
            components.append(streetAddress)
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Search for addresses matching a query
    func searchAddresses(_ query: String, region: MKCoordinateRegion? = nil) async throws -> [MKLocalSearchCompletion] {
        // For simple address search, we'll use MKLocalSearchCompleter
        // This returns quickly and provides autocomplete-style results
        throw GeocodingError.notImplemented // Will implement if needed
    }
}

// MARK: - Models

struct GeocodedLocation {
    let address: String
    let coordinate: CLLocationCoordinate2D
    let placemark: CLPlacemark
}

// MARK: - Errors

enum GeocodingError: LocalizedError {
    case noResults
    case outsideCommunityBounds
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No location found for this address"
        case .outsideCommunityBounds:
            return "Address is outside the community area"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}
