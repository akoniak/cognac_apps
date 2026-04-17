//
//  ServicesGeoJSONService.swift
//  BLS Event Tracker
//
//  Loads and parses ROADS.geojson into road segments for map overlay display.
//

import Foundation
import MapKit
import CoreLocation

struct GeoJSONRoadSegment: Identifiable {
    let id: Int // OBJECTID from GeoJSON
    let roadName: String
    let lineType: String
    let coordinates: [CLLocationCoordinate2D]
    let shapeLength: Double

    /// Address range (left side)
    let leftFromAddress: Int
    let leftToAddress: Int
    /// Address range (right side)
    let rightFromAddress: Int
    let rightToAddress: Int
}

class GeoJSONService {
    static let shared = GeoJSONService()

    /// All parsed road segments from the GeoJSON file
    private(set) var allSegments: [GeoJSONRoadSegment] = []

    /// Segments filtered to the BLS community bounding box
    private(set) var blsSegments: [GeoJSONRoadSegment] = []

    /// Segments grouped by GeoJSON road name for fast lookup
    private(set) var segmentsByGeoName: [String: [GeoJSONRoadSegment]] = [:]

    /// BLS community bounding box
    private static let blsMinLat = 38.22
    private static let blsMaxLat = 38.27
    private static let blsMinLon = -120.36
    private static let blsMaxLon = -120.31

    // MARK: - Road ID to GeoJSON ROADNAME mapping

    /// Maps Road.id to the GeoJSON ROADNAME string(s).
    /// Roads not present in the GeoJSON (e.g. Hilo, Kilauea, Mauna Loa) are omitted.
    static let roadIDToGeoJSONNames: [String: [String]] = [
        "airocobra-ave": ["AIRACOBRA AV"],
        "almeden-dr": ["ALMADEN DR"],
        "alpine-way": ["ALPINE WY"],
        "aspen-way": ["ASPEN WY"],
        "audrey-ct": ["AUDREY CT"],
        "augusta-dr": ["AUGUSTA DR"],
        "avery-dr": ["AVERY DR"],
        "barbara-way": ["BARBARA WY"],
        "baywood-vw": ["BAYWOOD VIEW"],
        "bear-clover-ct": ["BEAR CLOVER CT"],
        "bear-clover-dr": ["BEAR CLOVER DR"],
        "bear-run-way": ["BEAR RUN"],
        "belmont-way": ["BELMONT WY"],
        "beth-ct": ["BETH CT"],
        "blue-lake-springs-dr": ["BLUE LAKE SPRINGS DR"],
        "bonfilio-dr": ["BONFILIO DR"],
        "boro-ct": ["BORO CT"],
        "brea-burn-dr": ["BRAE BURN DR"],
        "calaveritas-dr": ["CALAVERITAS DR"],
        "canyon-view-ct": ["CANYON VIEW CT"],
        "castlewood-ln": ["CASTLEWOOD LN"],
        "chamonix-ct": ["CHAMONIX CT"],
        "chamonix-dr": ["CHAMONIX DR"],
        "colleen-ct": ["COLLEEN CT"],
        "conifer-ct": ["CONIFER CT"],
        "coniferous-dr": ["CONIFEROUS DR"],
        "cub-ct": ["CUB CT"],
        "cypress-point-dr": ["CYPRESS POINT DR"],
        "david-lee-rd": ["DAVID LEE RD"],
        "dawyn-dr": ["DAWYN DR"],
        "dean-ct": ["DEAN CT"],
        "dean-way": ["DEAN WY"],
        "deerwood-ct": ["DEERWOOD CT"],
        "del-paso-ln": ["DEL PASO LN"],
        "del-rio-dr": ["DEL RIO DR"],
        "dianna-dr": ["DIANNA DR"],
        "dorothy-dr": ["DOROTHY DR"],
        "douglas-dr": ["DOUGLAS DR"],
        "el-dorado-dr": ["EL DORADO DR"],
        "el-ranchero-dr": ["EL RANCHERO DR"],
        "eliese-dr": ["ELIESE DR"],
        "elizabeth-dr": ["ELIZABETH DR"],
        "evergreen-dr": ["EVERGREEN LN"],
        "felix-dr": ["FELIX DR"],
        "flamingo-way": ["FLAMINGO WY"],
        "flanders-dr": ["FLANDERS DR"],
        "george-ann-ct": ["GEORGEANN CT"],
        "george-ann-dr": ["GEORGEANN DR"],
        "gertrude-way": ["GERTRUDE WY"],
        "gloria-dr": ["GLORIA DR"],
        "grace-ct": ["GRACE CT"],
        "grand-braken-way": ["GRANDBRACKEN WY"],
        "grand-tetons-dr": ["GRAND TETONS DR"],
        "greensboro-way": ["GREENSBORO WY"],
        "grenoble-ct": ["GRENOBLE CT"],
        "grenoble-dr": ["GRENOBLE DR"],
        "grizzly-way": ["GRIZZLY WY"],
        "helen-dr": ["HELEN DR"],
        "hibernation-pt": ["HIBERNATION PT"],
        "highway-4": ["HWY 4"],
        "hillcrest-dr": ["HILLCREST DR"],
        "incline-way": ["INCLINE WY"],
        "innsbruk-dr": ["INNSBRUK DR"],
        "jeannie-dr": ["JEANNIE DR"],
        "jerri-ct": ["JERRI CT"],
        "jerrilynne-dr": ["JERRILYNN DR"],
        "julia-ln": ["JULIA LN"],
        "kay-ct": ["KAY CT"],
        "kiote-hills-dr": ["KIOTE HILLS DR"],
        "kuehn-ave": ["KUEHN AV"],
        "lightning-ln": ["LIGHTNING LN"],
        "linda-dr": ["LINDA DR"],
        "loganberry-ln": ["LOGANBERRY LN"],
        "lynn-ct": ["LYNNE CT"],
        "manzanita-dr": ["MANZANITA DR"],
        "marilyn-way": ["MARILYN WY"],
        "marti-dr": ["MARTI DR"],
        "mauna-kea-ct": ["MAUNA KEA CT"],
        "mauna-kea-dr": ["MAUNA KEA DR"],
        "meadow-dr": ["MEADOW DR"],
        "meadow-ln": ["MEADOW LN"],
        "medina-dr": ["MEDINA DR"],
        "michelle-way": ["MICHELE WY"],
        "middle-dr": ["MIDDLE DR"],
        "milbar-ct": ["MILBAR CT"],
        "mira-vis": ["MIRA VISTA"],
        "mitchell-dr": ["MITCHELL DR"],
        "mokelumne-dr-e": ["E MOKELUMNE DR"],
        "mokelumne-dr-w": ["W MOKELUMNE DR"],
        "monetier-dr": ["MONETIER DR"],
        "moran-ct": ["MORAN CT"],
        "moran-pl": ["MORAN PL"],
        "moran-rd": ["MORAN RD"],
        "murphys-dr": ["MURPHYS DR"],
        "mustang-rd": ["MUSTANG RD"],
        "nola-dr": ["NOLA DR"],
        "oaken-dr": ["OAKEN DR"],
        "oakmont-ct": ["OAKMONT CT"],
        "pamela-ct": ["PAMELA CT"],
        "patricia-ct": ["PATRICIA CT"],
        "patricia-ln": ["PATRICIA LN"],
        "pebble-beach-way": ["PEBBLE BEACH WY"],
        "pine-cone-dr": ["PINE CONE DR"],
        "polly-ct": ["POLLY CT"],
        "rainy-dr": ["RAINY DR"],
        "russell-dr": ["RUSSELL DR"],
        "ruth-ln": ["RUTH LN"],
        "san-ramon-dr": ["SAN RAMON DR"],
        "sandi-way": ["SANDI WY"],
        "seminole-way": ["SEMINOLE WY"],
        "shannon-ct": ["SHANNON CT"],
        "shannon-way": ["SHANNON WY"],
        "shirley-way": ["SHIRLEY WY"],
        "sierra-vw": ["NORTH SIERRA VIEW", "SOUTH SIERRA VIEW"],
        "silverado-way": ["SILVERADO WY"],
        "snowflake-dr": ["SNOW FLAKE DR"],
        "spring-valley-way": ["SPRING VALLEY WY"],
        "st-andrews-ct": ["SAINT ANDREWS DR"],
        "st-andrews-dr": ["SAINT ANDREWS DR"],
        "st-moritz-dr": ["SAINT MORITZ DR"],
        "stanislaus-dr": ["STANISLAUS DR"],
        "stephanie-dr": ["STEPHANIE DR"],
        "tamarack-dr": ["TAMARACK DR"],
        "taos-ct": ["TAOS CT"],
        "vallecito-dr": ["VALLECITO DR"],
        "war-hawk-way": ["WAR HAWK WY"],
        "wawona-ct": ["WAWONA WY"],
        "wawona-way": ["WAWONA WY"],
    ]

    private init() {}

    /// Load and parse the ROADS.geojson file from the app bundle.
    /// Call this once at startup.
    func loadRoads() {
        guard allSegments.isEmpty else { return } // Already loaded

        guard let url = Bundle.main.url(forResource: "ROADS", withExtension: "geojson") else {
            print("GeoJSONService: ROADS.geojson not found in bundle")
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            print("GeoJSONService: Failed to read ROADS.geojson")
            return
        }

        let decoder = MKGeoJSONDecoder()
        guard let geoObjects = try? decoder.decode(data) else {
            print("GeoJSONService: Failed to decode GeoJSON")
            return
        }

        var segments: [GeoJSONRoadSegment] = []

        for object in geoObjects {
            guard let feature = object as? MKGeoJSONFeature else { continue }

            let properties = parseProperties(from: feature.properties)

            for geometry in feature.geometry {
                guard let polyline = geometry as? MKPolyline else { continue }

                let coords = extractCoordinates(from: polyline)
                guard !coords.isEmpty else { continue }

                let segment = GeoJSONRoadSegment(
                    id: properties.objectID,
                    roadName: properties.roadName,
                    lineType: properties.lineType,
                    coordinates: coords,
                    shapeLength: properties.shapeLength,
                    leftFromAddress: properties.lFromAdd,
                    leftToAddress: properties.lToAdd,
                    rightFromAddress: properties.rFromAdd,
                    rightToAddress: properties.rToAdd
                )
                segments.append(segment)
            }
        }

        allSegments = segments

        // Filter to BLS bounding box
        blsSegments = segments.filter { segment in
            segment.coordinates.contains { coord in
                coord.latitude >= Self.blsMinLat &&
                coord.latitude <= Self.blsMaxLat &&
                coord.longitude >= Self.blsMinLon &&
                coord.longitude <= Self.blsMaxLon
            }
        }

        // Build lookup by GeoJSON road name
        segmentsByGeoName = Dictionary(grouping: blsSegments, by: { $0.roadName })

        print("GeoJSONService: Loaded \(allSegments.count) total segments, \(blsSegments.count) in BLS area")
    }

    /// Returns all GeoJSON segments that belong to a given Road.id
    func segments(forRoadID roadID: String) -> [GeoJSONRoadSegment] {
        guard let geoNames = Self.roadIDToGeoJSONNames[roadID] else { return [] }
        return geoNames.flatMap { segmentsByGeoName[$0] ?? [] }
    }

    // MARK: - Private helpers

    private struct ParsedProperties {
        let objectID: Int
        let roadName: String
        let lineType: String
        let shapeLength: Double
        let lFromAdd: Int
        let lToAdd: Int
        let rFromAdd: Int
        let rToAdd: Int
    }

    private func parseProperties(from data: Data?) -> ParsedProperties {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ParsedProperties(objectID: 0, roadName: "", lineType: "", shapeLength: 0, lFromAdd: 0, lToAdd: 0, rFromAdd: 0, rToAdd: 0)
        }

        return ParsedProperties(
            objectID: json["OBJECTID"] as? Int ?? 0,
            roadName: json["ROADNAME"] as? String ?? "",
            lineType: json["LINE_TYPE"] as? String ?? "",
            shapeLength: json["Shape__Length"] as? Double ?? 0,
            lFromAdd: json["L_F_ADD"] as? Int ?? 0,
            lToAdd: json["L_T_ADD"] as? Int ?? 0,
            rFromAdd: json["R_F_ADD"] as? Int ?? 0,
            rToAdd: json["R_T_ADD"] as? Int ?? 0
        )
    }

    private func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords
    }
}
