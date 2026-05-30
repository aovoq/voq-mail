//
//  SidebarColorCalibration.swift
//  VoqMail
//
//  The Core Image filter pipeline that tints the sidebar's NSVisualEffectView
//  material into the exact appearance the app wants. `VisualEffectStyle`
//  (in VisualEffectBackground.swift) plugs `SidebarMaterialCalibration.makeFilters`
//  into the view as its content filters.
//
//  ⚠️ The float constants below are EMPIRICALLY CALIBRATED against reference
//  screenshots. They look arbitrary but every digit matters: rounding, reordering,
//  or "simplifying" any value will change the rendered sidebar color. Treat this
//  whole file as read-only unless you are deliberately re-deriving the look.
//

import AppKit
import CoreImage

// MARK: - Filter pipeline

/// Builds the ordered list of filters that turns the base titlebar material into
/// the calibrated sidebar tint. Order is significant — each stage feeds the next.
enum SidebarMaterialCalibration {
    static func makeFilters() -> [CIFilter] {
        [
            // 1. Desaturate and very slightly darken the base material.
            colorControls(saturation: 0.45, brightness: -0.012),
            // 2. Pull the colors toward the target response curve, then fine-tune.
            ColorResponse.sidebarTarget.filter,
            ColorResponse.sidebarFineTune.filter,
            // 3. Apply the primary color matrix that defines the sidebar hue.
            ColorMatrix.sidebarFourPointTarget.filter,
        ].compactMap { $0 } + sRGBPostCalibrationFilters()
    }

    /// A final pass run in sRGB-gamma space. The two matrix tweaks are wrapped in
    /// a linear→sRGB→linear "sandwich" so they operate on gamma-encoded colors,
    /// which is where the calibration was measured.
    private static func sRGBPostCalibrationFilters() -> [CIFilter] {
        [
            CIFilter(name: "CILinearToSRGBToneCurve"),
            ColorMatrix.sidebarPostCalibrationTarget.filter,
            ColorMatrix.sidebarNeutralLastMile.filter,
            CIFilter(name: "CISRGBToneCurveToLinear"),
        ].compactMap { $0 }
    }

    private static func colorControls(saturation: Double, brightness: Double) -> CIFilter? {
        let filter = CIFilter(name: "CIColorControls")
        filter?.setDefaults()
        filter?.setValue(saturation, forKey: kCIInputSaturationKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        return filter
    }
}

// MARK: - Calibrated constants (do not edit)

/// A 3×3 color transform plus a bias offset, expressed as a `CIColorMatrix`.
/// Each static value is a calibrated stage in the pipeline above.
private struct ColorMatrix {
    let redVector: CIVector
    let greenVector: CIVector
    let blueVector: CIVector
    let biasVector: CIVector

    static let sidebarFourPointTarget = ColorMatrix(
        redVector: CIVector(x: 0.654897740, y: -0.240473628, z: 0.155866523, w: 0),
        greenVector: CIVector(x: -0.455005382, y: 1.108396125, z: -0.181270183, w: 0),
        blueVector: CIVector(x: -0.327341227, y: -0.447685684, z: 1.347470398, w: 0),
        biasVector: CIVector(x: 0.414901117, y: 0.510175394, z: 0.412570970, w: 0)
    )

    static let sidebarPostCalibrationTarget = ColorMatrix(
        redVector: CIVector(x: 1.420678464, y: 0.038173248, z: 0.118847075, w: 0),
        greenVector: CIVector(x: -0.056100765, y: 1.071323700, z: -0.093733096, w: 0),
        blueVector: CIVector(x: -0.281044742, y: -0.131674523, z: 0.942276486, w: 0),
        biasVector: CIVector(x: -0.538687952, y: 0.060583553, z: 0.424503364, w: 0)
    )

    static let sidebarNeutralLastMile = ColorMatrix(
        redVector: CIVector(x: 0.756598925, y: -0.053258584, z: -0.182901191, w: 0),
        greenVector: CIVector(x: 0, y: 1, z: 0, w: 0),
        blueVector: CIVector(x: 0.132757144, y: 0.064237328, z: 1.110955384, w: 0),
        biasVector: CIVector(x: 0.437193069, y: 0, z: -0.280670175, w: 0)
    )

    var filter: CIFilter? {
        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setDefaults()
        filter?.setValue(redVector, forKey: "inputRVector")
        filter?.setValue(greenVector, forKey: "inputGVector")
        filter?.setValue(blueVector, forKey: "inputBVector")
        filter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        filter?.setValue(biasVector, forKey: "inputBiasVector")
        return filter
    }
}

/// A "lift + bias" color response per channel, also realized as a `CIColorMatrix`.
/// `lift` mixes a channel toward/away from red, `bias` adds a constant offset.
private struct ColorResponse {
    let redLift: CGFloat
    let greenLift: CGFloat
    let blueLift: CGFloat
    let redBias: CGFloat
    let greenBias: CGFloat
    let blueBias: CGFloat

    static let sidebarTarget = ColorResponse(
        redLift: 0.941176,
        greenLift: 0.529412,
        blueLift: 0.411765,
        redBias: -0.018685,
        greenBias: -0.012226,
        blueBias: -0.010381
    )

    static let sidebarFineTune = ColorResponse(
        redLift: 0.103077,
        greenLift: 0,
        blueLift: 0.017629,
        redBias: -0.028793,
        greenBias: -0.015686,
        blueBias: -0.015962
    )

    var filter: CIFilter? {
        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setDefaults()
        filter?.setValue(CIVector(x: 1 + redLift, y: -redLift, z: 0, w: 0), forKey: "inputRVector")
        filter?.setValue(CIVector(x: greenLift, y: 1 - greenLift, z: 0, w: 0), forKey: "inputGVector")
        filter?.setValue(CIVector(x: blueLift, y: -blueLift, z: 1, w: 0), forKey: "inputBVector")
        filter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        filter?.setValue(CIVector(x: redBias, y: greenBias, z: blueBias, w: 0), forKey: "inputBiasVector")
        return filter
    }
}
