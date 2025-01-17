//    Copyright (C) 2022 Parrot Drones SAS
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

import Foundation
import GroundSdk
import Combine

private extension ULogTag {
    static let tag = ULogTag(name: "AlertMonitorManager")
}

/// Implementation of `AlertMonitorService`.
class AlertsMonitor {

    // MARK: Private properties

    /// The banner alert manager service.
    private let bamService: BannerAlertManagerService

    /// Combine cancellables.
    private var cancellables = Set<AnyCancellable>()

    /// References to instruments and peripherals.
    private var alarmsRef: Ref<Alarms>?
    private var takeoffChecklistRef: Ref<TakeoffChecklist>?
    private var motorsRef: Ref<CopterMotors>?
    private var flyingIndicatorsRef: Ref<FlyingIndicators>?
    private var gpsRef: Ref<Gps>?
    private var cameraRef: Ref<MainCamera2>?
    private var captureRef: Ref<Camera2PhotoCapture>?
    private var gimbalRef: Ref<Gimbal>?
    private var networkControlRef: Ref<NetworkControl>?
    private var returnHomeRef: Ref<ReturnHomePilotingItf>?
    private var removableUserStorageRef: Ref<RemovableUserStorage>?
    private var internalUserStorageRef: Ref<InternalUserStorage>?
    private var preciseHomeRef: Ref<PreciseHome>?

    /// Whether a motors alarms has raised.
    private var isMotorsAlarmOn = false {
        didSet { updateMotorsAlert() }
    }
    /// The active copter motors peripheral banner alert.
    private var copterMotorsBannerAlerts = [BannerAlert]() {
        didSet { updateMotorsAlert() }
    }
    /// Whether drone is flying.
    private var isDroneFlying = false {
        didSet {
            updateRthAlert()
            updateGpsAlert()
        }
    }
    /// Whether drone is flying or waiting.
    private var isDroneFlyingOrWaiting = false {
        didSet { updateHomePositionSetAlert() }
    }
    /// Whether drone is taking off.
    private var isDroneTakingOff = false {
        didSet { updateImuSaturationAlert() }
    }
    /// Whether drone is landing.
    private var isDroneLanding = false {
        didSet {
            updateImuSaturationAlert()
            updatePreciseHomeAlert()
        }
    }
    /// Whether GPS fix is missing.
    private var isGpsFixMissing = false {
        didSet { updateGpsAlert() }
    }
    /// Whether drone is emergency landing.
    private var isDroneEmergencyLanding = false {
        didSet { updateAutolandingAlerts() }
    }
    /// The IMU saturation level.
    private var imuSaturationAlarmLevel: Alarm.Level = .notAvailable {
        didSet { updateImuSaturationAlert() }
    }
    /// Whether home is not reachable.
    private var isHomeNotReachable = false {
        didSet { updateRthAlert() }
    }
    /// Whether temperature is critical.
    private var isTemperatureCritical = false {
        didSet { updateAutolandingAlerts() }
    }
    /// Whether auto landing alarm is on.
    private var isAutolandingAlarmOn = false {
        didSet { updateAutolandingAlerts() }
    }
    /// Whether home position set alert is required.
    private var isHomePositionSetAlertRequired = false
    /// Whether home position is set.
    private var isHomePositionSet = false {
        didSet { updateHomePositionSetAlert() }
    }
    /// Whether RTH is active.
    private var isRthActive = false {
        didSet { updatePreciseHomeAlert() }
    }
    /// Whether precise home is active.
    private var isPreciseHomeActive = false {
        didSet { updatePreciseHomeAlert() }
    }

    // MARK: init

    /// Constructor.
    ///
    /// - Parameters:
    ///   - connectedDroneHolder: the drone holder
    ///   - bamService: the banner alert manager service
    init(connectedDroneHolder: ConnectedDroneHolder,
         bamService: BannerAlertManagerService) {
        self.bamService = bamService
        listen(connectedDroneHolder: connectedDroneHolder)
    }
}

// MARK: Private functions
private extension AlertsMonitor {

    /// Listens to connected drone.
    ///
    /// - Parameter connectedDroneHolder: drone holder
    func listen(connectedDroneHolder: ConnectedDroneHolder) {
        connectedDroneHolder.dronePublisher
            .sink { [weak self] drone in
                guard let self = self else { return }

                guard let drone = drone else {
                    self.bamService.clearAll()
                    self.resetStates()
                    self.resetRefs()
                    return
                }

                self.listenTakeoffChecklist(drone: drone)
                self.listenAlarms(drone: drone)
                self.listenMotors(drone: drone)
                self.listenFlyingIndicators(drone: drone)
                self.listenGps(drone: drone)
                self.listenNetworkControl(drone: drone)
                self.listenGimbal(drone: drone)
                self.listenReturnHome(drone: drone)
                self.listenRemovableUserStorage(drone: drone)
                self.listenInternalUserStorage(drone: drone)
                self.listenPreciseHome(drone: drone)
            }
            .store(in: &cancellables)
    }

    /// Resets instruments and periperals references.
    func resetRefs() {
        alarmsRef = nil
        takeoffChecklistRef = nil
        motorsRef = nil
        flyingIndicatorsRef = nil
        gpsRef = nil
        cameraRef = nil
        captureRef = nil
        networkControlRef = nil
        gimbalRef = nil
        returnHomeRef = nil
        removableUserStorageRef = nil
        internalUserStorageRef = nil
        preciseHomeRef = nil
    }

    /// Resets states.
    func resetStates() {
        isMotorsAlarmOn = false
        copterMotorsBannerAlerts = []
        isDroneFlying = false
        isDroneTakingOff = false
        isDroneLanding = false
        isDroneEmergencyLanding = false
        isGpsFixMissing = false
        imuSaturationAlarmLevel = .notAvailable
        isHomeNotReachable = false
        isTemperatureCritical = false
        isAutolandingAlarmOn = false
        isHomePositionSetAlertRequired = false
        isHomePositionSet = false
        isRthActive = false
        isPreciseHomeActive = false
    }

    /// Listens to take off checklist instrument changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenTakeoffChecklist(drone: Drone) {
        takeoffChecklistRef = drone.getInstrument(Instruments.takeoffChecklist) { [weak self] checklist in
            guard let self = self else { return }
            guard let checklist = checklist else {
                // Take off checklist instrument not available => clear all related alerts.
                self.bamService.hide(AnyBannerAlert.takeoffChecklistAlerts)
                return
            }
            self.updateTakeoffChecklistAlert(checklist: checklist)
        }
    }

    /// Listens to alarms instrument changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenAlarms(drone: Drone) {
        alarmsRef = drone.getInstrument(Instruments.alarms) { [weak self] alarms in
            guard let self = self else { return }
            guard let alarms = alarms else {
                // Alarms instrument not available => clear all related alerts.
                self.bamService.hide(AnyBannerAlert.alarmsAlerts)
                return
            }

            // Update states.
            self.updateMotorsAlarmState(alarms: alarms)
            self.updateImuSaturationAlarmLevel(alarms: alarms)
            self.updateTemperatureAlarmState(alarms: alarms)
            self.updateAutolandingAlarmState(alarms: alarms)

            // Update alerts.
            self.updateConditionsAlerts(alarms: alarms)
            self.updateObstacleAvoidanceAlerts(alarms: alarms)
            self.updateGeofenceAlerts(alarms: alarms)
        }
    }

    /// Listens to copter motors peripheral changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenMotors(drone: Drone) {
        motorsRef = drone.getPeripheral(Peripherals.copterMotors) { [weak self] copterMotors in
            self?.copterMotorsBannerAlerts = copterMotors?.bannerAlerts ?? [CriticalBannerAlert.motorCutout]
        }
    }

    /// Listens to flying indicators instrument changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenFlyingIndicators(drone: Drone) {
        flyingIndicatorsRef = drone.getInstrument(Instruments.flyingIndicators) { [weak self] flyingIndicators in
            self?.updateFlyingStates(flyingIndicators: flyingIndicators)
        }
    }

    /// Listens to GPS instrument changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenGps(drone: Drone) {
        gpsRef = drone.getInstrument(Instruments.gps) { [weak self] gps in
            self?.isGpsFixMissing = gps?.fixed == false
        }
    }

    /// Listens to network control peripheral changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenNetworkControl(drone: Drone) {
        networkControlRef = drone.getPeripheral(Peripherals.networkControl) { [weak self] networkControl in
            self?.bamService.update(WarningBannerAlert.lowAndPerturbedWifi,
                                    show: networkControl?.isWifiLowAndPerturbed == true)
        }
    }

    /// Listens to gimbal peripheral changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenGimbal(drone: Drone) {
        gimbalRef = drone.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            self?.bamService.update(CriticalBannerAlert.cameraError,
                                    show: gimbal?.hasErrors == true)
        }
    }

    /// Listens to return home piloting interface changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenReturnHome(drone: Drone) {
        returnHomeRef = drone.getPilotingItf(PilotingItfs.returnHome) { [weak self] returnHome in
            guard let self = self else { return }
            self.isHomeNotReachable = returnHome?.homeReachability == .notReachable
            self.isHomePositionSet = returnHome?.homeLocation != nil
            self.isRthActive = returnHome?.state == .active
        }
    }

    /// Listens to removable user storage peripheral changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenRemovableUserStorage(drone: Drone) {
        removableUserStorageRef = drone.getPeripheral(Peripherals.removableUserStorage) { [weak self] removableUserStorage in
            self?.updateRemovableUserStorageAlerts(removableUserStorage: removableUserStorage)
        }
    }

    /// Listens to internal user storage peripheral changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenInternalUserStorage(drone: Drone) {
        internalUserStorageRef = drone.getPeripheral(Peripherals.internalUserStorage) { [weak self] internalUserStorage in
            self?.bamService.update(CriticalBannerAlert.internalMemoryError,
                                    show: internalUserStorage?.physicalState.isErrorState == true ||
                                    internalUserStorage?.fileSystemState.isErrorState == true)
        }
    }

    /// Listens to precise home peripheral changes.
    ///
    /// - Parameter drone: drone to monitor
    func listenPreciseHome(drone: Drone) {
        preciseHomeRef = drone.getPeripheral(Peripherals.preciseHome) { [weak self] preciseHome in
            self?.isPreciseHomeActive = preciseHome?.state == .active
        }
    }
}

private extension AlertsMonitor {

    /// Updates motors error state according to alarms instruments.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateMotorsAlarmState(alarms: Alarms) {
        isMotorsAlarmOn = alarms.isOn(.motorCutOut) || alarms.isOn(.motorError)
    }

    /// Updates IMU saturation level according to alarms instruments.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateImuSaturationAlarmLevel(alarms: Alarms) {
        imuSaturationAlarmLevel = alarms.level(.strongVibrations)
    }

    /// Updates critical temperature state according to alarms instruments.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateTemperatureAlarmState(alarms: Alarms) {
        isTemperatureCritical = alarms.level(.batteryTooHot) == .critical ||
        alarms.level(.batteryTooCold) == .critical
    }

    /// Updates auto landing state according to alarms instruments.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateAutolandingAlarmState(alarms: Alarms) {
        isAutolandingAlarmOn = alarms.level(.automaticLandingBatteryIssue) == .critical &&
        alarms.automaticLandingDelay == 0
    }

    /// Updates flying states according to flying indicators.
    ///
    /// - Parameter flyingIndicators: the flying indicators instrument
    func updateFlyingStates(flyingIndicators: FlyingIndicators?) {
        isDroneFlying = flyingIndicators?.state == .flying
        isDroneEmergencyLanding = flyingIndicators?.state == .emergencyLanding
        isDroneTakingOff = flyingIndicators?.flyingState == .takingOff
        isDroneLanding = flyingIndicators?.flyingState == .landing
        isDroneFlyingOrWaiting = flyingIndicators?.flyingState.isFlyingOrWaiting == true

        if isDroneTakingOff {
            // Taking off => home position set alert is required.
            isHomePositionSetAlertRequired = true
        }
    }
}

private extension AlertsMonitor {

    /// Updates take off checklist alerts.
    ///
    /// - Parameter checklist: the take off checklist
    func updateTakeoffChecklistAlert(checklist: TakeoffChecklist) {
        let isBatteryGaugeUpdateRequired = checklist.isOn(.batteryGaugeUpdateRequired)
        let isBatteryIdentificationFailed = checklist.isOn(.batteryIdentification)
        let needCalibration = checklist.isOn(.magnetoCalibration)

        bamService.update(CriticalBannerAlert.batteryGaugeUpdateRequired, show: isBatteryGaugeUpdateRequired)
        bamService.update(CriticalBannerAlert.batteryIdentification, show: isBatteryIdentificationFailed)

        bamService.update(CriticalBannerAlert.needCalibration, show: needCalibration)
    }

    /// Updates motors banner alert.
    func updateMotorsAlert() {
        guard let alert = copterMotorsBannerAlerts.first else {
            bamService.hide(AnyBannerAlert.copterMotorAlerts)
            return
        }

        // Need to clear all other motors alert in case copter motors alert is `nil` and last triggered
        // alert was not `motorCutout`.
        let otherCopterMotorAlerts = AnyBannerAlert.copterMotorAlerts
            .filter { AnyBannerAlert($0) != AnyBannerAlert(alert) }
        bamService.hide(otherCopterMotorAlerts)

        bamService.update(alert, show: isMotorsAlarmOn)
    }

    /// Updates GPS banner alert.
    func updateGpsAlert() {
        let hasGpsError = isGpsFixMissing && isDroneFlying
        bamService.update(CriticalBannerAlert.noGps, show: hasGpsError)
    }

    /// Updates conditions banner alerts.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateConditionsAlerts(alarms: Alarms) {
        bamService.update(CriticalBannerAlert.forceLandingIcedPropeller,
                          show: alarms.level(.icingLevel) == .critical)
        bamService.update(CriticalBannerAlert.noGpsTooDark,
                          show: alarms.isOn(.hoveringDifficultiesNoGpsTooDark))
        bamService.update(CriticalBannerAlert.noGpsTooHigh,
                          show: alarms.isOn(.hoveringDifficultiesNoGpsTooHigh))
        bamService.update(CriticalBannerAlert.headingLockedKoPerturbationMagnetic,
                          show: alarms.isOn(.magnetometerPertubation))
        bamService.update(CriticalBannerAlert.headingLockedKoEarthMagnetic,
                          show: alarms.isOn(.magnetometerLowEarthField))
        bamService.update(CriticalBannerAlert.tooMuchWind,
                          show: alarms.isOn(.wind))
        bamService.update(CriticalBannerAlert.stereoCameraDecalibrated,
                          show: alarms.isOn(.stereoCameraDecalibrated))
    }

    /// Updates IMU saturation banner alerts.
    func updateImuSaturationAlert() {
        let isTakingOffOrLanding = isDroneTakingOff || isDroneLanding
        let strongImuVibration = imuSaturationAlarmLevel == .critical
        let imuVibration = imuSaturationAlarmLevel == .warning

        bamService.update(CriticalBannerAlert.strongImuVibration,
                          show: strongImuVibration && isTakingOffOrLanding)
        bamService.update(WarningBannerAlert.imuVibration,
                          show: imuVibration && isTakingOffOrLanding)
    }

    /// Updates obstacle avoidance banner alerts.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateObstacleAvoidanceAlerts(alarms: Alarms) {
        // Critical alerts.
        bamService.update(CriticalBannerAlert.obstacleAvoidanceSensorsFailure,
                          show: alarms.isOn(.obstacleAvoidanceDisabledStereoFailure) ||
                          alarms.isOn(.obstacleAvoidanceDisabledStereoLensFailure))
        bamService.update(CriticalBannerAlert.obstacleAvoidanceGimbalFailure,
                          show: alarms.isOn(.obstacleAvoidanceDisabledGimbalFailure))
        bamService.update(CriticalBannerAlert.obstacleAvoidanceSensorsNotCalibrated,
                          show: alarms.isOn(.obstacleAvoidanceDisabledCalibrationFailure))
        bamService.update(CriticalBannerAlert.obstacleAvoidanceTooDark,
                          show: alarms.isOn(.obstacleAvoidanceDisabledTooDark))
        bamService.update(CriticalBannerAlert.obstacleAvoidanceDeteriorated,
                          show: alarms.isOn(.obstacleAvoidancePoorGps))
        bamService.update(CriticalBannerAlert.obstacleAvoidanceStrongWind,
                          show: alarms.isOn(.obstacleAvoidanceStrongWind))
        bamService.update(CriticalBannerAlert.obstacleAvoidanceComputationalError,
                          show: alarms.isOn(.obstacleAvoidanceComputationalError))
        // Warning alerts.
        bamService.update(WarningBannerAlert.obstacleAvoidanceBlindMotionDirection,
                          show: alarms.isOn(.obstacleAvoidanceBlindMotionDirection))
        bamService.update(WarningBannerAlert.highDeviation,
                          show: alarms.isOn(.highDeviation))
        bamService.update(WarningBannerAlert.obstacleAvoidanceDroneStucked,
                          show: alarms.isOn(.droneStuck))
    }

    /// Updates geofence banner alerts.
    ///
    /// - Parameter alarms: the alarms instrument
    func updateGeofenceAlerts(alarms: Alarms) {
        let isHOn = alarms.isOn(.horizontalGeofenceReached)
        let isVOn = alarms.isOn(.verticalGeofenceReached)

        bamService.update(CriticalBannerAlert.geofence,
                          show: isHOn || isVOn)
    }

    /// Updates RTH banner alert.
    func updateRthAlert() {
        bamService.update(CriticalBannerAlert.wontReachHome,
                          show: isDroneFlying && isHomeNotReachable)
    }

    /// Updates auto landing banner alerts.
    func updateAutolandingAlerts() {
        bamService.update(CriticalBannerAlert.forceLandingTemperature,
                          show: isDroneEmergencyLanding && isTemperatureCritical)
        bamService.update(CriticalBannerAlert.forceLandingLowBattery,
                          show: (isDroneFlying || isDroneEmergencyLanding) && isAutolandingAlarmOn)
    }

    /// Updates removable user storage banner alerts.
    ///
    /// - Parameter userStorage: the user storage peripheral
    func updateRemovableUserStorageAlerts(removableUserStorage: RemovableUserStorage?) {
        let isTooSlow = removableUserStorage?.physicalState == .mediaTooSlow
        let hasError = removableUserStorage?.physicalState.isErrorState == true ||
        removableUserStorage?.fileSystemState.isErrorState == true

        bamService.update(CriticalBannerAlert.sdTooSlow,
                          show: isTooSlow)
        bamService.update(CriticalBannerAlert.sdError,
                          show: hasError && !isTooSlow)
    }

    /// Updates home position set alert.
    func updateHomePositionSetAlert() {
        let show = isHomePositionSetAlertRequired &&
        isHomePositionSet &&
        isDroneFlyingOrWaiting

        bamService.update(HomeAlert.homePositionSet, show: show)

        if show {
            // Do not show alert again until next take off.
            isHomePositionSetAlertRequired = false
        }
    }

    /// Updates precise home alerts.
    func updatePreciseHomeAlert() {
        bamService.update(HomeAlert.preciseRthInProgress,
                          show: isRthActive && isPreciseHomeActive)
        bamService.update(HomeAlert.preciseLandingInProgress,
                          show: isDroneLanding && isPreciseHomeActive)
    }
}
