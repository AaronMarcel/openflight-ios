//    Copyright (C) 2020 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

// [Banner Alerts] Legacy code is temporarily kept for validation purpose only.
// TODO: Remove file.

import UIKit

// MARK: - Internal Enums
/// List of critical alerts for HUD banner.
public enum HUDBannerCriticalAlertType: String, HUDAlertType {
    case motorCutout
    case motorCutoutTemperature
    case motorCutoutPowerSupply
    case forceLandingLowBattery
    case forceLandingTemperature
    case wontReachHome
    case noGpsTooDark
    case noGpsTooHigh
    case noGps
    case headingLockedKoPerturbationMagnetic
    case headingLockedKoEarthMagnetic
    case tooMuchWind
    case strongImuVibration
    case sdError
    case sdTooSlow
    case geofenceAltitudeAndDistance
    case geofenceAltitude
    case geofenceDistance
    case obstacleAvoidanceTooDark
    case obstacleAvoidanceSensorsFailure
    case obstacleAvoidanceGimbalFailure
    case obstacleAvoidanceSensorsNotCalibrated
    case obstacleAvoidanceDeteriorated
    case obstacleAvoidanceStrongWind
    case obstacleAvoidanceComputationalError
    case cameraError
    case needCalibration
    case stereoCameraDecalibrated

    public var level: HUDAlertLevel {
        return .critical
    }

    public var category: AlertCategoryType {
        switch self {
        case .motorCutout,
             .motorCutoutTemperature,
             .motorCutoutPowerSupply:
            return .componentsMotor
        case .forceLandingLowBattery,
             .forceLandingTemperature,
             .wontReachHome:
            return .autoLanding
        case .needCalibration:
            return .takeoff
        case .noGpsTooDark,
             .noGpsTooHigh,
             .noGps,
             .headingLockedKoPerturbationMagnetic,
             .headingLockedKoEarthMagnetic:
            return .conditions
        case .tooMuchWind:
            return .conditionsWind
        case .strongImuVibration:
            return .componentsImu
        case .sdError,
             .sdTooSlow:
            return .sdCard
        case .geofenceAltitudeAndDistance,
             .geofenceAltitude,
             .geofenceDistance:
            return .geofence
        case .obstacleAvoidanceTooDark,
             .obstacleAvoidanceSensorsFailure,
             .obstacleAvoidanceGimbalFailure,
             .obstacleAvoidanceSensorsNotCalibrated,
             .obstacleAvoidanceStrongWind,
             .obstacleAvoidanceDeteriorated,
             .obstacleAvoidanceComputationalError:
            return .obstacleAvoidance
        case .cameraError,
             .stereoCameraDecalibrated:
            return .componentsCamera
        }
    }

    public var priority: String {
        return rawValue
    }

    public var label: String {
        switch self {
        case .motorCutout:
            return L10n.alertMotorCutout
        case .motorCutoutTemperature:
            return L10n.alertMotorCutoutTemperature
        case .motorCutoutPowerSupply:
            return L10n.alertMotorCutoutPowerSupply
        case .forceLandingLowBattery,
             .forceLandingTemperature:
            return L10n.alertAutoLanding
        case .wontReachHome:
            return L10n.alertReturnHomeWontReachHome
        case .noGpsTooDark:
            return L10n.alertNoGpsTooDark
        case .noGpsTooHigh:
            return L10n.alertNoGpsTooHigh
        case .noGps:
            return L10n.alertNoGps
        case .headingLockedKoPerturbationMagnetic:
            return L10n.alertHeadingLockKoPerturbationMagnetic
        case .headingLockedKoEarthMagnetic:
            return L10n.alertHeadingLockKoEarthMagnetic
        case .tooMuchWind:
            return L10n.alertTooMuchWind
        case .strongImuVibration:
            return L10n.alertStrongImuVibrations
        case .sdError:
            return L10n.alertSdError
        case .sdTooSlow:
            return L10n.alertSdcardTooSlow
        case .geofenceAltitudeAndDistance,
             .geofenceAltitude,
             .geofenceDistance:
            return L10n.alertGeofenceReached
        case .obstacleAvoidanceTooDark:
            return L10n.alertNoAvoidanceTooDark
        case .obstacleAvoidanceSensorsFailure:
            return L10n.alertNoAvoidanceSensorsFailure
        case .obstacleAvoidanceGimbalFailure:
            return L10n.alertNoAvoidanceGimbalFailure
        case .obstacleAvoidanceSensorsNotCalibrated:
            return L10n.alertNoAvoidanceSensorsNotCalibrated
        case .obstacleAvoidanceDeteriorated:
            return L10n.alertAvoidanceDeteriorated
        case .obstacleAvoidanceStrongWind:
            return L10n.alertDeterioratedAvoidanceStrongWinds
        case .obstacleAvoidanceComputationalError:
            return L10n.alertObstacleAvoidanceComputationalError
        case .cameraError:
            return L10n.alertCameraError
        case .needCalibration:
            return L10n.droneDetailsCalibrationRequired
        case .stereoCameraDecalibrated:
            return L10n.alertStereoSensorsNotCalibrated
        }
    }

    public var icon: UIImage? {
        switch self {
        case .motorCutout,
             .motorCutoutTemperature,
             .motorCutoutPowerSupply,
             .strongImuVibration:
            return Asset.Common.Icons.icDroneSmall.image
        case .forceLandingLowBattery,
             .forceLandingTemperature:
            return Asset.Common.Icons.icWarningWhite.image
        case .tooMuchWind,
             .obstacleAvoidanceStrongWind:
            return Asset.Common.Icons.icWind.image
        case .sdError,
             .sdTooSlow:
            return Asset.Gallery.droneSd.image
        case .geofenceAltitudeAndDistance:
            return Asset.Telemetry.icDistance.image
        case .geofenceAltitude:
            return Asset.Telemetry.icAltitude.image
        case .geofenceDistance:
            return Asset.Telemetry.icDistance.image
        case .cameraError:
            return Asset.Common.Icons.iconCamera.image
        default:
            return nil
        }
    }

    public var actionType: AlertActionType? {
        return nil
    }

    public var vibrationDelay: TimeInterval {
        return 0.0
    }
}

/// List of warning alerts for HUD banner.
public enum HUDBannerWarningAlertType: String, HUDAlertType {
    case lowAndPerturbedWifi
    case obstacleAvoidanceDroneStucked
    case obstacleAvoidanceBlindMotionDirection
    case imuVibration
    case targetLost
    case droneGpsKo
    case userDeviceGpsKo
    case unauthorizedFlightZone
    case unauthorizedFlightZoneWithMission
    case highDeviation

    public var level: HUDAlertLevel {
        return .warning
    }

    public var category: AlertCategoryType {
        switch self {
        case .lowAndPerturbedWifi:
            return .wifi
        case .obstacleAvoidanceDroneStucked,
             .obstacleAvoidanceBlindMotionDirection,
             .highDeviation:
            return .obstacleAvoidance
        case .imuVibration:
            return .componentsImu
        case .targetLost,
             .droneGpsKo,
             .userDeviceGpsKo:
            return .animations
        case .unauthorizedFlightZone,
             .unauthorizedFlightZoneWithMission:
            return .flightZone
        }
    }

    public var priority: String {
        return rawValue
    }

    public var label: String {
        switch self {
        case .lowAndPerturbedWifi:
            return L10n.alertLowAndPerturbedWifi
        case .obstacleAvoidanceDroneStucked:
            return L10n.alertDroneStuck
        case .imuVibration:
            return L10n.alertImuVibrations
        case .targetLost:
            // TODO: To move in FF in a warning enum (string + alert)
            return L10n.alertTargetLost
        case .droneGpsKo,
             .userDeviceGpsKo:
            return L10n.alertGpsKo
        case .unauthorizedFlightZone,
             .unauthorizedFlightZoneWithMission:
            return L10n.alertUnauthorizedFlightZone
        case .highDeviation:
            return L10n.alertHighDeviation
        case .obstacleAvoidanceBlindMotionDirection:
            return L10n.alertObstacleAvoidanceBlindDirection
        }
    }

    public var icon: UIImage? {
        switch self {
        case .lowAndPerturbedWifi:
            return Asset.Common.Icons.icWifi.image
        case .imuVibration:
            return Asset.Common.Icons.icDroneSmall.image
        case .droneGpsKo, .userDeviceGpsKo:
            return Asset.Gps.Controller.icGpsKo.image.withRenderingMode(.alwaysTemplate)
        default:
            return nil
        }
    }

    public var actionType: AlertActionType? {
        return nil
    }

    public var vibrationDelay: TimeInterval {
        return 0.0
    }
}

/// List of advices alerts for HUD banner.
public enum HUDBannerAdviceslertType: String, HUDAlertType {
    case takeOff

    public var level: HUDAlertLevel {
        return .advice
    }

    public var category: AlertCategoryType {
        return .animations
    }

    public var priority: String {
        return rawValue
    }

    public var label: String {
        switch self {
        case .takeOff:
            return L10n.alertTakeOff
        }
    }

    public var icon: UIImage? {
        return nil
    }

    public var actionType: AlertActionType? {
        return nil
    }

    public var vibrationDelay: TimeInterval {
        return 0.0
    }
}
