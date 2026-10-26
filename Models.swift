import SwiftUI
import CoreLocation
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

//color extension: makes sure that the app colors stay consistent (blue, dark blue, etc...)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 100, 100, 100)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

//set the colors for the app
extension Color {
    static let regular = Color(hex: "#1A6BF5") //regular blue
    static let light = Color(hex: "#EBF1FF") //very very very light blue
    static let surface = Color(hex: "#FFFFFF") //white
    static let bg = Color(hex: "#F4F6FB") //white, tinted blue a tiny bit
    static let textPrimary = Color(hex: "#0F1728") //black
    static let textSecondary = Color(hex: "#6B7A99") //greyish blue
    static let divider = Color(hex: "#E8ECF4") //silverish blue
    static let pastelBlue = Color(hex: "#bbd1fc") //pastel blue
    static let darkBlue = Color(hex: "003294") //dark blue
}

//bortle information for learners!
struct BortleInfo {
    let level: Int
    let name: String
    let quality: String
    let sqm: String
    let limitingMagnitude: String
    let milkyWay: String
    let description: String
    let color: Color
    
    static let all: [BortleInfo] = [
        BortleInfo(level: 1, name: "Excellent Dark Sky Site", quality: "Pristine", sqm: "22.0+", limitingMagnitude: "7.6-8.0", milkyWay: "Casts shadows", description: "Zodiacal light, gegenschein, and zodiacal band all visible. M33 is naked-eye. Sky has a three-dimensional appearance.", color: Color(hex: "#2563EB")),
        BortleInfo(level: 2, name: "Typical Dark Sky Site", quality: "Excellent", sqm: "21.9-22.0", limitingMagnitude: "7.1-7.5", milkyWay: "Highly structured", description: "Airglow weakly visible near horizon. M33 easily naked-eye. Milky Way has complex, distinct regions.", color: Color(hex: "#0891B2")),
        BortleInfo(level: 3, name: "Rural Sky Site", quality: "Good", sqm: "21.5-21.9", limitingMagnitude: "6.6-7.0", milkyWay: "Complex bright regions", description: "Some light pollution traces on horizon. Milky Way appears mottled. M15, M4, M5, M22 resolved without optical aid.", color: Color(hex: "#16A34A")),
        BortleInfo(level: 4, name: "Brighter Rural Site", quality: "Moderate", sqm: "20.5-21.5", limitingMagnitude: "6.1-6.5", milkyWay: "Distinct but muted", description: "Light pollution domes obvious in 1-2 directions. Milky Way still impressive but lacks the darkest detail.", color: Color(hex: "#65A30D")),
        BortleInfo(level: 5, name: "Semi Suburban Sky Site", quality: "Fair", sqm: "19.5-20.5", limitingMagnitude: "5.6-6.0", milkyWay: "Faint near zenith", description: "Only hints of Milky Way at zenith. Clouds are noticeably brighter than sky. Many nebulae too faint.", color: Color(hex: "#CA8A04")),
        BortleInfo(level: 6, name: "Bright Suburban Sky Site", quality: "Poor", sqm: "18.5-19.5", limitingMagnitude: "5.1-5.5", milkyWay: "Only near zenith", description: "No trace of Milky Way. Sky bright enough to read coarse newsprint. M33 impossible", color: Color(hex: "#EA580C")),
        BortleInfo(level: 7, name: "Suburban/Urban Transition Site", quality: "Very Poor", sqm: "18.0-18.5", limitingMagnitude: "4.6-5.0", milkyWay: "Invisible", description: "Entire sky has a grayish-white hue. Strong light domes in all directions. Milky Way invisible even overhead.", color: Color(hex: "#DC2626")),
        BortleInfo(level: 8, name: "City Sky Site", quality: "Severe", sqm: "17.5-18.0", limitingMagnitude: "4.1-4.5", milkyWay: "Invisible", description: "Sky glows white or orange. The Milky Way is totally invisible. Only 20-40 stars visible to the naked eye.", color: Color(hex: "#B91C1C")),
        BortleInfo(level: 9, name: "Inner City Sky Site", quality: "Extreme", sqm: "<17.5", limitingMagnitude: "<4.0", milkyWay: "Invisible", description: "Entire sky is light gray even at zenith. Only a handful of the very brightest stars are visible. Practically no astronomy possible.", color: Color(hex: "#7F1D1D")),
    ]
    
    static func forLevel(_ level: Int) -> BortleInfo {
        all.first { $0.level == level } ?? all[4]
    }
}

//observation storing in firebase, allows user to see their previous observations once signed in

struct Observation: Identifiable, Codable {
    @DocumentID var id: String?
    var bortleLevel: Int
    var sqm: Double
    var locationName: String
    var latitude: Double
    var longitude: Double
    var date: Date = Date()
    var notes: String = ""
    var contributorID: String? = nil   //anonymous uid of the submitter
}

// storing the observation
@MainActor
class ObservationStore: ObservableObject {
    @Published var observations: [Observation] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
  
    func start() {
        ensureSignedIn()
        guard listener == nil else { return }
        listener = db.collection("observations")
            .order(by: "date", descending: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Firestore listen error: \(error.localizedDescription)")
                    return
                }
                self.observations = snapshot?.documents.compactMap {
                    try? $0.data(as: Observation.self)
                } ?? []
            }
    }

    private func ensureSignedIn() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { _, error in
                if let error { print("Anon sign-in failed: \(error.localizedDescription)") }
            }
        }
    }
    deinit { listener?.remove() }
}

//location manager: access to device location

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        if let loc = locations.last { reverseGeocode(loc) }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async { self?.placemark = placemarks?.first }
        }
    }
    
    var locationName: String? {
        if let city = placemark?.locality, let state = placemark?.administrativeArea {
            return "\(city), \(state)"
        }
        return "Unknown Location"
    }
}





// analyze the sky to determine the bortle result

struct SkyAnalysisResult {
    let bortleLevel: Int
    let sqmValue: Double
    let starCount: Int
    let avgBrightness: Double
    let orangeTint: Double
    let confidence: String
}

class SkyAnalyzer: ObservableObject {
    @Published var result: SkyAnalysisResult?
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    
    func analyze(image: UIImage) {
        isAnalyzing = true
        result = nil
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not read image"
                    self.isAnalyzing = false
                }
                return
            }
            let pixelResult = self.analyzePixels(cgImage: cgImage)
            let starCount = self.detectStars(cgImage: cgImage) //counts number of stars which goes into the formula
            let analysisResult = self.estimateBortle(
                avgBrightness: pixelResult.brightness,
                orangeTint: pixelResult.orangeTint,
                starCount: starCount
            ) 
            //formula uses these three values
            
            DispatchQueue.main.async {
                self.result = analysisResult
                self.isAnalyzing = false
            }
        }
    }
    
    // pixel analysis samples every 8th pixel, where the pixel which is chosen has its average brightness and orange tint computed
    private struct PixelStats {
        let brightness: Double
        let orangeTint: Double
    }
    
    private func analyzePixels(cgImage: CGImage) -> PixelStats {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelBuffer = [UInt8](repeating: 0, count: totalBytes)
        
        guard let context = CGContext(
            data: &pixelBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return PixelStats(brightness: 0.5, orangeTint: 0.3)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y:0, width: width, height: height))
        let pixelData = pixelBuffer
        
        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var sampleCount: Double = 0
        
        let step = bytesPerPixel * 8
        var i = 0
        while i < totalBytes - 3 {
            let r = Double(pixelData[i])
            let g = Double(pixelData[i + 1])
            let b = Double(pixelData[i + 2])
            totalR += r
            totalG += g
            totalB += b
            sampleCount += 1
            i += step
        }
        
        guard sampleCount > 0 else { return PixelStats(brightness: 0.5, orangeTint: 0.3)}
        
        let avgR = totalB / sampleCount / 255.0
        let avgG = totalG / sampleCount / 255.0
        let avgB = totalB / sampleCount / 255.0
        
        // luminance formula
        let brightness = 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB
        
        let orangeTint = max(0, min(1, ((avgR + avgG * 0.5) - avgB * 1.5 + 0.5)))
        
        return PixelStats(brightness: brightness, orangeTint: orangeTint)
    }
    
    // using vision, detect & count # of stars
    private func detectStars(cgImage: CGImage) -> Int {
        //boost contrast
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = 2.5
        filter.brightness = -0.1
        filter.saturation = 0.0
        
        guard let outputCI = filter.outputImage,
              let enhanced = CIContext().createCGImage(outputCI, from: outputCI.extent)
                else { return 0 }
        
        //vision to find rectangles, as bright star clusters appear as tiny rectangles
        var detectedCount = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = VNDetectRectanglesRequest { request, error in
            defer { semaphore.signal() }
            guard error == nil,
                  let results = request.results as? [VNRectangleObservation]
            else { return }
            
            //filter small regions
            detectedCount = results.filter { obs in
                let w = obs.boundingBox.width
                let h = obs.boundingBox.height
                return w < 0.04 && h < 0.04
            }.count
        }
        request.minimumSize = 0.005
        request.maximumObservations = 200
        request.minimumConfidence = 0.3
        
        let handler = VNImageRequestHandler(cgImage: enhanced, options: [:])
        try? handler.perform([request])
        semaphore.wait()
        
        //detect bright points using custom luminance threshold pass
        let brightPoints = countBrightIsolatedPoints(cgImage: enhanced)
        
        return max(detectedCount, brightPoints)
    }
    
    //count isolated bright pixels
    private func countBrightIsolatedPoints(cgImage: CGImage) -> Int {
        let width = min(cgImage.width, 400)
        let height = min(cgImage.height, 400)
        let bytesPerRow = width
        let totalBytes = bytesPerRow * height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: totalBytes)

        let threshold: UInt8 = 200
        var count = 0
        
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let idx = y * width + x
                guard pixels[idx] > threshold else { continue }
                
                //check neighbors
                let neighbors = [
                    pixels[idx-1], pixels[idx+1],
                    pixels[idx-width], pixels[idx+width]
                ]
                let darkNeighbors = neighbors.filter { $0 < 150 }.count
                if darkNeighbors >= 2 {
                    count += 1
                }
            }
        }
        return count
    }
    
    //bortle estimation function: uses all of above + a formula (50% star score, 35% brightness score, 15% tint score), outputs confidence as well
    private func estimateBortle(avgBrightness: Double, orangeTint: Double, starCount: Int) -> SkyAnalysisResult {
      
      //scores for 3 previously calculated values 
        let starScore: Double
        switch starCount {
        case 150...: starScore = 1.0
        case 80..<150: starScore = 2.5
        case 40..<80: starScore = 4.0
        case 15..<40: starScore = 5.5
        case 5..<15: starScore = 7.0
        case 1..<5: starScore = 8.0
        default: starScore = 0.0
        }
        let brightnessScore = min(9.0, max(1.0, avgBrightness * 22.0))
        let tintScore = min(9.0, max(1.0, orangeTint * 12.0))

        //formula
        let rawScore = (starScore * 0.50) + (brightnessScore * 0.35) + (tintScore * 0.15)
        let bortleLevel = min(9, max(1, Int(rawScore.rounded())))
  
        let sqm = BortleInfo.forLevel(bortleLevel).sqmMidpoint
        
        let spread = max(abs(starScore - brightnessScore),
                        abs(starScore - tintScore),
                        abs(brightnessScore - tintScore))
        let confidence: String
        switch spread {
        case 0..<2: confidence = "High"
        case 2..<4: confidence = "Medium"
        default: confidence = "Low"
        }
        
        return SkyAnalysisResult(
            bortleLevel: bortleLevel,
            sqmValue: sqm,
            starCount: starCount,
            avgBrightness: avgBrightness,
            orangeTint: orangeTint,
            confidence: confidence
        )
    }
}

extension BortleInfo {
    var sqmMidpoint: Double {
        switch level {
        case 1: return 22.1
        case 2: return 21.95
        case 3: return 21.7
        case 4: return 21.0
        case 5: return 20.0
        case 6: return 19.0
        case 7: return 18.25
        case 8: return 17.75
        default: return 17.0
        }
    }
}

//outputs moon phase for more information

struct MoonPhase {
    let name: String
    let icon: String
    let illumination: Int

    #formula used
    static func current() -> MoonPhase {
        let synodicMonth = 29.53058867
        let known = Date(timeIntervalSince1970: 947182440)
        let now = Date()
        let days = now.timeIntervalSince(known) / 86400
        let phase = (days / synodicMonth).truncatingRemainder(dividingBy: 1)
        let pct = phase < 0 ? phase + 1 : phase
        
        switch pct {
        case 0..<0.03, 0.97...: return MoonPhase(name: "New Moon", icon: "moonphase.new.moon", illumination: 0)
        case 0.03..<0.22: return MoonPhase(name: "Waxing Crescent", icon: "moonphase.waxing.crescent", illumination: Int(pct / 0.25 * 50))
        case 0.22..<0.28: return MoonPhase(name: "First Quarter", icon: "moonphase.first.quarter", illumination: 50)
        case 0.28..<0.47: return MoonPhase(name: "Waxing Gibbous", icon: "moonphase.waxing.gibbous", illumination: Int(50 + (pct - 0.25) / 0.25 * 50))
        case 0.47..<0.53: return MoonPhase(name: "Full Moon", icon: "moonphase.full.moon", illumination: 100)
        case 0.53..<0.72: return MoonPhase(name: "Waning Gibbous", icon: "moonphase.waning.gibbous", illumination: Int(100 - (pct - 0.5) / 0.25 * 50))
        case 0.72..<0.78: return MoonPhase(name: "Last Quarter", icon: "moonphase.last.quarter", illumination: 50)
        default: return MoonPhase(name: "Waning Crescent", icon: "moonphase.waning.crescent", illumination: Int((1 - pct) / 0.25 * 50))
        }
    }
    
    var viewingImpact: String {
        switch illumination {
        case 0..<20: return "Excellent for stargazing"
        case 20..<50: return "Good for stargazing"
        case 50..<80: return "Fair for stargzing"
        default: return "Poor for stargazing"
        }
    }
    
    var impactColor: Color {
        switch illumination {
        case 0..<20: return Color(hex: "#16A34A")
        case 20..<50: return Color(hex: "65A30D")
        case 50..<80: return Color(hex: "CA8A04")
        default: return Color(hex: "DC2626")
        }
    }
}

