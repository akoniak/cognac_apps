//
//  Road.swift
//  Community Status App
//
//  Road model for displaying road status
//

import Foundation
import CoreLocation
import SwiftUI

enum RoadStatus: String, Codable {
    case clear      // Road is clear - green
    case blocked    // Road is blocked - red
    case mixed      // Blocked but disputed - orange
    case unknown    // Status unknown - gray
    
    var color: Color {
        switch self {
        case .clear: return .green
        case .blocked: return .red
        case .mixed: return .orange
        case .unknown: return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .clear: return "checkmark.circle.fill"
        case .blocked: return "xmark.circle.fill"
        case .mixed: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct Road: Identifiable, Codable {
    let id: String
    let name: String
    var centerLatitude: Double
    var centerLongitude: Double
    var status: RoadStatus
    
    init(id: String, name: String, centerLatitude: Double, centerLongitude: Double, status: RoadStatus = .unknown) {
        self.id = id
        self.name = name
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.status = status
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    /// Update road status based on reports
    mutating func updateStatus(from reports: [Report]) {
        // Filter for road reports for this specific road
        let plowedReports = reports.filter { report in
            report.category == .roadPlowed &&
            report.isVisible &&
            report.roadID == self.id
        }
        
        let blockedReports = reports.filter { report in
            report.category == .roadBlocked &&
            report.isVisible &&
            report.roadID == self.id
        }
        
        // Determine status based on most recent report
        let allRoadReports = (plowedReports + blockedReports).sorted { $0.createdAt > $1.createdAt }
        
        if let mostRecentReport = allRoadReports.first {
            if mostRecentReport.category == .roadPlowed {
                status = .clear
            } else {
                // Show mixed (orange) when the blocked report has both verifications and disputes,
                // matching the same visual behavior as disputed power out markers.
                status = mostRecentReport.confidenceTier == .mixed ? .mixed : .blocked
            }
        } else {
            status = .unknown
        }
    }
}

// MARK: - Blue Lake Springs Roads Data

extension Road {
    /// Roads for Blue Lake Springs community
    /// Each road has a single representative point for icon display.
    /// Coordinates sourced from OpenStreetMap/Nominatim; roads not found default to community center.
    static var bluelakeSpringsRoads: [Road] {
        [
            Road(id: "airocobra-ave",        name: "Airocobra Ave",        centerLatitude: 38.2382777, centerLongitude: -120.3461932),
            Road(id: "almeden-dr",           name: "Almeden Dr",           centerLatitude: 38.2539007, centerLongitude: -120.3179108),
            Road(id: "aspen-way",            name: "Aspen Way",            centerLatitude: 38.2273945, centerLongitude: -120.3419986),
            Road(id: "audrey-ct",            name: "Audrey Ct",            centerLatitude: 38.2441755, centerLongitude: -120.3529632),
            Road(id: "augusta-dr",           name: "Augusta Dr",           centerLatitude: 38.2624406, centerLongitude: -120.3286667),
            Road(id: "avery-dr",             name: "Avery Dr",             centerLatitude: 38.2335398, centerLongitude: -120.3404101),
            Road(id: "barbara-way",          name: "Barbara Way",          centerLatitude: 38.2450761, centerLongitude: -120.3496312),
            Road(id: "baywood-vw",           name: "Baywood Vw",           centerLatitude: 38.2520879, centerLongitude: -120.3181212),
            Road(id: "bear-clover-ct",       name: "Bear Clover Ct",       centerLatitude: 38.2411024, centerLongitude: -120.3386677),
            Road(id: "bear-clover-dr",       name: "Bear Clover Dr",       centerLatitude: 38.2415160, centerLongitude: -120.3390304),
            Road(id: "bear-run-way",         name: "Bear Run Way",         centerLatitude: 38.2556133, centerLongitude: -120.3374242),
            Road(id: "belmont-way",          name: "Belmont Way",          centerLatitude: 38.2416726, centerLongitude: -120.3290834),
            Road(id: "beth-ct",              name: "Beth Ct",              centerLatitude: 38.2427375, centerLongitude: -120.3511547),
            Road(id: "blue-lake-springs-dr", name: "Blue Lake Springs Dr", centerLatitude: 38.25899, centerLongitude: -120.33099),
            Road(id: "bonfilio-dr",          name: "Bonfilio Dr",          centerLatitude: 38.2436298, centerLongitude: -120.3329801),
            Road(id: "boro-ct",              name: "Boro Ct",              centerLatitude: 38.2593675, centerLongitude: -120.3202375),
            Road(id: "brea-burn-dr",         name: "Brea Burn Dr",         centerLatitude: 38.2535058, centerLongitude: -120.3281690),
            Road(id: "calaveritas-dr",       name: "Calaveritas Dr",       centerLatitude: 38.2377089, centerLongitude: -120.3442382),
            Road(id: "canyon-view-ct",       name: "Canyon View Ct",       centerLatitude: 38.2397867, centerLongitude: -120.3324097),
            Road(id: "castlewood-ln",        name: "Castlewood Ln",        centerLatitude: 38.2511263, centerLongitude: -120.3239599),
            Road(id: "chamonix-ct",          name: "Chamonix Ct",          centerLatitude: 38.2296986, centerLongitude: -120.3461971),
            Road(id: "chamonix-dr",          name: "Chamonix Dr",          centerLatitude: 38.2310407, centerLongitude: -120.3415472),
            Road(id: "colleen-ct",           name: "Colleen Ct",           centerLatitude: 38.2441205, centerLongitude: -120.3456338),
            Road(id: "conifer-ct",           name: "Conifer Ct",           centerLatitude: 38.2401876, centerLongitude: -120.3321812),
            Road(id: "coniferous-dr",        name: "Coniferous Dr",        centerLatitude: 38.2422153, centerLongitude: -120.3385471),
            Road(id: "cub-ct",               name: "Cub Ct",               centerLatitude: 38.2575591, centerLongitude: -120.3365481),
            Road(id: "cypress-point-dr",     name: "Cypress Point Dr",     centerLatitude: 38.2492132, centerLongitude: -120.3272163),
            Road(id: "david-lee-rd",         name: "David Lee Rd",         centerLatitude: 38.2624201, centerLongitude: -120.3347730),
            Road(id: "dawyn-dr",             name: "Dawyn Dr",             centerLatitude: 38.2552200, centerLongitude: -120.3323692),
            Road(id: "dean-ct",              name: "Dean Ct",              centerLatitude: 38.2570803, centerLongitude: -120.3342372),
            Road(id: "dean-way",             name: "Dean Way",             centerLatitude: 38.2570803, centerLongitude: -120.3342372),
            Road(id: "deerwood-ct",          name: "Deerwood Ct",          centerLatitude: 38.2285329, centerLongitude: -120.3444163),
            Road(id: "del-paso-ln",          name: "Del Paso Ln",          centerLatitude: 38.2402798, centerLongitude: -120.3285563),
            Road(id: "del-rio-dr",           name: "Del Rio Dr",           centerLatitude: 38.2632091, centerLongitude: -120.3277842),
            Road(id: "dianna-dr",            name: "Dianna Dr",            centerLatitude: 38.2474983, centerLongitude: -120.3370571),
            Road(id: "dorothy-dr",           name: "Dorothy Dr",           centerLatitude: 38.2496833, centerLongitude: -120.3446913),
            Road(id: "douglas-dr",           name: "Douglas Dr",           centerLatitude: 38.2355820, centerLongitude: -120.3374516),
            Road(id: "el-dorado-dr",         name: "El Dorado Dr",         centerLatitude: 38.2412585, centerLongitude: -120.3500408),
            Road(id: "el-ranchero-dr",       name: "El Ranchero Dr",       centerLatitude: 38.2590101, centerLongitude: -120.3180920),
            Road(id: "eliese-dr",            name: "Eliese Dr",            centerLatitude: 38.2452642, centerLongitude: -120.3518820),
            Road(id: "elizabeth-dr",         name: "Elizabeth Dr",         centerLatitude: 38.2442233, centerLongitude: -120.3513503),
            Road(id: "evergreen-dr",         name: "Evergreen Dr",         centerLatitude: 38.2413476, centerLongitude: -120.3348608),
            Road(id: "felix-dr",             name: "Felix Dr",             centerLatitude: 38.2382288, centerLongitude: -120.3398903),
            Road(id: "flamingo-way",         name: "Flamingo Way",         centerLatitude: 38.2415286, centerLongitude: -120.3294082),
            Road(id: "flanders-dr",          name: "Flanders Dr",          centerLatitude: 38.2355400, centerLongitude: -120.3413923),
            Road(id: "george-ann-ct",        name: "George Ann Ct",        centerLatitude: 38.2431961, centerLongitude: -120.3465541),
            Road(id: "george-ann-dr",        name: "George Ann Dr",        centerLatitude: 38.2431961, centerLongitude: -120.3465541),
            Road(id: "gertrude-way",         name: "Gertrude Way",         centerLatitude: 38.2459001, centerLongitude: -120.3412349),
            Road(id: "gloria-dr",            name: "Gloria Dr",            centerLatitude: 38.2513076, centerLongitude: -120.3378363),
            Road(id: "grace-ct",             name: "Grace Ct",             centerLatitude: 38.2471170, centerLongitude: -120.3476215),
            Road(id: "grand-braken-way",     name: "Grand Braken Way",     centerLatitude: 38.2280043, centerLongitude: -120.3412179),
            Road(id: "grand-tetons-dr",      name: "Grand Tetons Dr",      centerLatitude: 38.2291206, centerLongitude: -120.3401109),
            Road(id: "greensboro-way",       name: "Greensboro Way",       centerLatitude: 38.2628291, centerLongitude: -120.3200636),
            Road(id: "grenoble-ct",          name: "Grenoble Ct",          centerLatitude: 38.2298781, centerLongitude: -120.3439083),
            Road(id: "grenoble-dr",          name: "Grenoble Dr",          centerLatitude: 38.2295640, centerLongitude: -120.3432229),
            Road(id: "grizzly-way",          name: "Grizzly Way",          centerLatitude: 38.2562384, centerLongitude: -120.3391420),
            Road(id: "helen-dr",             name: "Helen Dr",             centerLatitude: 38.2542492, centerLongitude: -120.3323383),
            Road(id: "hibernation-pt",       name: "Hibernation Pt",       centerLatitude: 38.2546694, centerLongitude: -120.3392965),
            Road(id: "hillcrest-dr",         name: "Hillcrest Dr",         centerLatitude: 38.2448356, centerLongitude: -120.3294710),
            Road(id: "highway-4",            name: "Highway 4",            centerLatitude: 38.24350, centerLongitude: -120.34600),
            Road(id: "hilo-dr",              name: "Hilo Dr",              centerLatitude: 38.24400, centerLongitude: -120.34600),
            Road(id: "incline-way",          name: "Incline Way",          centerLatitude: 38.2632972, centerLongitude: -120.3225741),
            Road(id: "innsbruk-dr",          name: "Innsbruk Dr",          centerLatitude: 38.2322656, centerLongitude: -120.3401222),
            Road(id: "jeannie-dr",           name: "Jeannie Dr",           centerLatitude: 38.2464277, centerLongitude: -120.3442168),
            Road(id: "jerri-ct",             name: "Jerri Ct",             centerLatitude: 38.2471919, centerLongitude: -120.3431425),
            Road(id: "jerrilynne-dr",        name: "Jerrilynne Dr",        centerLatitude: 38.2465710, centerLongitude: -120.3443380),
            Road(id: "julia-ln",             name: "Julia Ln",             centerLatitude: 38.2501982, centerLongitude: -120.3361587),
            Road(id: "kay-ct",               name: "Kay Ct",               centerLatitude: 38.2436604, centerLongitude: -120.3533394),
            Road(id: "kilauea-ct",           name: "Kilauea Ct",           centerLatitude: 38.24560, centerLongitude: -120.34785),
            Road(id: "kiote-hills-dr",       name: "Kiote Hills Dr",       centerLatitude: 38.2540997, centerLongitude: -120.3197695),
            Road(id: "kuehn-ave",            name: "Kuehn Ave",            centerLatitude: 38.2581542, centerLongitude: -120.3325204),
            Road(id: "lightning-ln",         name: "Lightning Ln",         centerLatitude: 38.2350228, centerLongitude: -120.3496966),
            Road(id: "linda-dr",             name: "Linda Dr",             centerLatitude: 38.2641268, centerLongitude: -120.3322132),
            Road(id: "loganberry-ln",        name: "Loganberry Ln",        centerLatitude: 38.2543497, centerLongitude: -120.3371999),
            Road(id: "lynn-ct",              name: "Lynn Ct",              centerLatitude: 38.2480594, centerLongitude: -120.3424705),
            Road(id: "manzanita-dr",         name: "Manzanita Dr",         centerLatitude: 38.2440109, centerLongitude: -120.3312464),
            Road(id: "marilyn-way",          name: "Marilyn Way",          centerLatitude: 38.2553433, centerLongitude: -120.3338707),
            Road(id: "marti-dr",             name: "Marti Dr",             centerLatitude: 38.2466651, centerLongitude: -120.3480672),
            Road(id: "mauna-kea-ct",         name: "Mauna Kea Ct",         centerLatitude: 38.26054, centerLongitude: -120.32700),
            Road(id: "mauna-kea-dr",         name: "Mauna Kea Dr",         centerLatitude: 38.26019, centerLongitude: -120.32501),
            Road(id: "mauna-loa-dr",         name: "Mauna Loa Dr",         centerLatitude: 38.24400, centerLongitude: -120.34800),
            Road(id: "meadow-dr",            name: "Meadow Dr",            centerLatitude: 38.2539457, centerLongitude: -120.3242031),
            Road(id: "meadow-ln",            name: "Meadow Ln",            centerLatitude: 38.2442093, centerLongitude: -120.3354183),
            Road(id: "medina-dr",            name: "Medina Dr",            centerLatitude: 38.2458771, centerLongitude: -120.3254386),
            Road(id: "michelle-way",         name: "Michelle Way",         centerLatitude: 38.2484382, centerLongitude: -120.3440543),
            Road(id: "middle-dr",            name: "Middle Dr",            centerLatitude: 38.2451894, centerLongitude: -120.3324754),
            Road(id: "milbar-ct",            name: "Milbar Ct",            centerLatitude: 38.2447229, centerLongitude: -120.3226446),
            Road(id: "mira-vis",             name: "Mira Vis",             centerLatitude: 38.2515397, centerLongitude: -120.3176864),
            Road(id: "mitchell-dr",          name: "Mitchell Dr",          centerLatitude: 38.2369907, centerLongitude: -120.3486576),
            Road(id: "mokelumne-dr-e",       name: "Mokelumne Dr E",       centerLatitude: 38.2287393, centerLongitude: -120.3369577),
            Road(id: "mokelumne-dr-w",       name: "Mokelumne Dr W",       centerLatitude: 38.2322469, centerLongitude: -120.3456869),
            Road(id: "monetier-dr",          name: "Monetier Dr",          centerLatitude: 38.2270706, centerLongitude: -120.3407418),
            Road(id: "moran-ct",             name: "Moran Ct",             centerLatitude: 38.2493280, centerLongitude: -120.3354962),
            Road(id: "moran-pl",             name: "Moran Pl",             centerLatitude: 38.2493280, centerLongitude: -120.3354962),
            Road(id: "moran-rd",             name: "Moran Rd",             centerLatitude: 38.2329015, centerLongitude: -120.3487015),
            Road(id: "murphys-dr",           name: "Murphys Dr",           centerLatitude: 38.2346205, centerLongitude: -120.3446071),
            Road(id: "mustang-rd",           name: "Mustang Rd",           centerLatitude: 38.2364154, centerLongitude: -120.3575281),
            Road(id: "mustang-st",           name: "Mustang St",           centerLatitude: 38.2393916, centerLongitude: -120.3457355),
            Road(id: "nola-dr",              name: "Nola Dr",              centerLatitude: 38.2533340, centerLongitude: -120.3359718),
            Road(id: "oaken-dr",             name: "Oaken Dr",             centerLatitude: 38.2404385, centerLongitude: -120.3336983),
            Road(id: "oakmont-ct",           name: "Oakmont Ct",           centerLatitude: 38.2398540, centerLongitude: -120.3282647),
            Road(id: "alpine-way",           name: "Alpine Way",           centerLatitude: 38.24675, centerLongitude: -120.34825),
            Road(id: "pamela-ct",            name: "Pamela Ct",            centerLatitude: 38.2392180, centerLongitude: -120.3525419),
            Road(id: "patricia-ct",          name: "Patricia Ct",          centerLatitude: 38.2452182, centerLongitude: -120.3394319),
            Road(id: "patricia-ln",          name: "Patricia Ln",          centerLatitude: 38.2448225, centerLongitude: -120.3440978),
            Road(id: "pebble-beach-way",     name: "Pebble Beach Way",     centerLatitude: 38.2638269, centerLongitude: -120.3211417),
            Road(id: "pine-cone-dr",         name: "Pine Cone Dr",         centerLatitude: 38.2397696, centerLongitude: -120.3363560),
            Road(id: "polly-ct",             name: "Polly Ct",             centerLatitude: 38.2458118, centerLongitude: -120.3521784),
            Road(id: "rainy-dr",             name: "Rainy Dr",             centerLatitude: 38.2489869, centerLongitude: -120.3375199),
            Road(id: "russell-dr",           name: "Russell Dr",           centerLatitude: 38.2601641, centerLongitude: -120.3346204),
            Road(id: "ruth-ln",              name: "Ruth Ln",              centerLatitude: 38.2431342, centerLongitude: -120.3521528),
            Road(id: "san-ramon-dr",         name: "San Ramon Dr",         centerLatitude: 38.2529262, centerLongitude: -120.3232759),
            Road(id: "sandi-way",            name: "Sandi Way",            centerLatitude: 38.2584589, centerLongitude: -120.3303508),
            Road(id: "seminole-way",         name: "Seminole Way",         centerLatitude: 38.2557125, centerLongitude: -120.3182627),
            Road(id: "shannon-ct",           name: "Shannon Ct",           centerLatitude: 38.2520790, centerLongitude: -120.3361176),
            Road(id: "shannon-way",          name: "Shannon Way",          centerLatitude: 38.2516759, centerLongitude: -120.3365870),
            Road(id: "shirley-way",          name: "Shirley Way",          centerLatitude: 38.2453083, centerLongitude: -120.3429498),
            Road(id: "sierra-vw",            name: "Sierra Vw",            centerLatitude: 38.2453301, centerLongitude: -120.3235688),
            Road(id: "silverado-way",        name: "Silverado Way",        centerLatitude: 38.2505124, centerLongitude: -120.3201144),
            Road(id: "snowflake-dr",         name: "Snowflake Dr",         centerLatitude: 38.2637755, centerLongitude: -120.3302596),
            Road(id: "spring-valley-way",    name: "Spring Valley Way",    centerLatitude: 38.2614179, centerLongitude: -120.3216065),
            Road(id: "st-andrews-ct",        name: "St Andrews Ct",        centerLatitude: 38.2582441, centerLongitude: -120.3261160),
            Road(id: "st-andrews-dr",        name: "St Andrews Dr",        centerLatitude: 38.2593837, centerLongitude: -120.3259178),
            Road(id: "st-moritz-dr",         name: "St Moritz Dr",         centerLatitude: 38.2253708, centerLongitude: -120.3432678),
            Road(id: "stanislaus-dr",        name: "Stanislaus Dr",        centerLatitude: 38.2437400, centerLongitude: -120.3276019),
            Road(id: "stephanie-dr",         name: "Stephanie Dr",         centerLatitude: 38.2436092, centerLongitude: -120.3530702),
            Road(id: "tamarack-dr",          name: "Tamarack Dr",          centerLatitude: 38.2374788, centerLongitude: -120.3373821),
            Road(id: "taos-ct",              name: "Taos Ct",              centerLatitude: 38.2323126, centerLongitude: -120.3372624),
            Road(id: "vallecito-dr",         name: "Vallecito Dr",         centerLatitude: 38.2335912, centerLongitude: -120.3444527),
            Road(id: "war-hawk-way",         name: "War Hawk Way",         centerLatitude: 38.2344916, centerLongitude: -120.3510168),
            Road(id: "wawona-ct",            name: "Wawona Ct",            centerLatitude: 38.2522720, centerLongitude: -120.3254777),
            Road(id: "wawona-way",           name: "Wawona Way",           centerLatitude: 38.2517263, centerLongitude: -120.3254011),
        ]
    }
}
