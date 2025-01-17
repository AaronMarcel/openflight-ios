//    Copyright (C) 2021 Parrot Drones SAS
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

import Combine
import ArcGIS
import GroundSdk

private extension ULogTag {
    static let tag = ULogTag(name: "FPEditionService")
}

public protocol FlightPlanEditionService {

    // MARK: - Read
    var settingsChanged: [FlightPlanLightSetting] { get }

    /// Current flight plan publisher
    var currentFlightPlanPublisher: AnyPublisher<FlightPlanModel?, Never> { get }

    /// Current flight plan
    var currentFlightPlanValue: FlightPlanModel? { get }

    // MARK: - High level management
    /// Sets up flight plan modell
    func setupFlightPlan(_ flightPlan: FlightPlanModel?)

    /// Resets fligh plan
    func resetFlightPlan()

    /// Clears Flight Plan, removing MAVLink file if
    /// any and deleting all waypoints and points of interest.
    ///
    /// - Note: calling this preserves uuid & settings.
    func clearFlightPlan()

    // MARK: - Undo management

    /// Can undo.
    func canUndo() -> Bool

    /// Undo.
    func undo()

    /// Forget the latest flight plan setting in the undo stack.
    func popUndoStack()

    /// Reset undo stack.
    func resetUndoStack()

    /// Add current flight plan setting in the undo stack.
    func appendCurrentStateToUndoStack()

    // MARK: - Commands

    /// - Parameters:
    ///    - mapPoint: location of the new waypoint
    ///    - index: index at which waypoint should be inserted
    /// - Returns: new waypoint, nil if index is invalid
    func insertWayPoint(with mapPoint: AGSPoint, at index: Int) -> WayPoint?

    /// Adds a waypoint at the end of the Flight Plan.
    /// - Parameters:
    ///   - wayPoint: the waypoint to add to the current FP of the receiver.
    /// - Returns: the count of waypoints in the flight plan after the addition of the new one
    @discardableResult
    func addWaypoint(_ wayPoint: WayPoint) -> Int

    /// Removes waypoint at given index.
    ///
    /// - Parameters:
    ///    - index: waypoint index
    /// - Returns: removed waypoint, if any
    @discardableResult
    func removeWaypoint(at index: Int) -> WayPoint?

    /// Adds a point of interest to the Flight Plan.
    ///
    /// - Parameter poiPoint: the point of interest to add.
    /// - Returns: the count of points of interest in the flight plan after the addition of the new
    ///   one
    func addPoiPoint(_ poiPoint: PoiPoint) -> Int

    /// Removes point of interest at given index.
    ///
    /// - Parameters:
    ///    - index: point of interest index
    /// - Returns: removed point of interest, if any
    @discardableResult
    func removePoiPoint(at index: Int) -> PoiPoint?

    /// Update only global settings of current flight plan and replace it in stack
    ///
    /// - Parameters:
    ///     - dataSetting: flight plan data setting to update.
    func updateGlobalSettings(with dataSetting: FlightPlanDataSetting?)

    /// Update the polygon points for the current flight plan.
    ///
    /// - Parameters:
    ///     - points: Polygon points
    func updatePolygonPoints(points: [AGSPoint])

    /// Update the current flight plan's type
    /// - Parameters:
    ///   - type: flight plan type
    ///   - resetPolygonPoints: whether to reset the polygon points
    ///   - settings: default settings related to new type
    func updateFlightPlanType(_ type: String,
                              resetPolygonPoints: Bool,
                              settings: [FlightPlanLightSetting]?)

    /// Change Flight Plan settings.
    ///
    /// - Parameters:
    ///    - settings: new settings
    func updateSettings(_ settings: [FlightPlanLightSetting])

    /// Change Flight Plan settings.
    ///
    /// - Parameters:
    ///    - settings: new settings
    func updateDataSetting(_ setting: FlightPlanDataSetting?)

    func endEdition(completion: @escaping () -> Void)

    func rename(_ flightPlan: FlightPlanModel, title: String)

    func freeSettingDidChange(key: String, value: String)

    // MARK: TODO move this somewhere relevant
    /// Updates current Flight Plan with new Mavlink.
    ///
    /// - Parameters:
    ///     - mavlinkData: Mavlink data
    ///     - type: Flight Plan type
    ///     - disablePhotoSignatureSetting: whether to disable photo signatures setting
    ///     - gsdSetting: the gsd key and value setting
    func updateFlightPlan(withMavlinkData mavlinkData: Data,
                          type: FlightPlanType,
                          disablePhotoSignatureSetting: Bool,

                          gsdSetting: (key: String, value: Int))

    func updateProjectManager(_ projectManager: ProjectManager)

    var hasChanges: Bool { get }

    /// Update the `modifiedFlightPlan`.
    ///
    /// - Parameters:
    ///    - flightPlan: the new Flight Plan state.
    ///
    /// - Note:
    ///  This method must be called to keep track of current user changes.
    ///  `modifiedFlightPlan` is used to know if there are some pending changes
    ///  which will be lost when user taps the back button.
    func updateModifiedFlightPlan(with flightPlan: FlightPlanModel?)

    /// Update the Cloud Synchro Watcher.
    ///
    /// - Parameter cloudSynchroWatcher: the cloudSynchroWatcher to update
    ///
    /// - Note:
    ///     If the cloud synchro watcher service is not yet instatiated during this service's init,
    ///     this method can be called to update and configure his watcher.
    func updateCloudSynchroWatcher(_ cloudSynchroWatcher: CloudSynchroWatcher?)
}

public class FlightPlanEditionServiceImpl {

    private var undoStack: [String] = []
    private let requester: FlightPlanThumbnailRequester = FlightPlanThumbnailRequester()
    private let repo: FlightPlanRepository!
    private let flightPlanManager: FlightPlanManager!
    private let typeStore: FlightPlanTypeStore!
    private let currentMissionManager: CurrentMissionManager!
    private let userService: UserService!
    private var projectManager: ProjectManager?
    private var cloudSynchroWatcher: CloudSynchroWatcher?

    private var synchroWatcherSubscriber: AnyCancellable?

    public var settingsChanged: [FlightPlanLightSetting] = []

    /// The initial state of the FP at the start of the edition.
    private var initialFlightPlan: FlightPlanModel?
    /// The current modified FP. Updated by each user changes.
    private var modifiedFlightPlan: FlightPlanModel?
    /// The Flight Plan containing latest Cloud state after a server response.
    private var cloudUpdatedFlightPlan: FlightPlanModel?

    private var currentFlightPlanSubject = CurrentValueSubject<FlightPlanModel?, Never>(nil)
    private var currentFlightPlan: FlightPlanModel? {
        get {
            currentFlightPlanSubject.value
        }
        set {
            // Get, if exists, the current edited FP's uuid.
            let currentFlightPlanUuid = currentFlightPlanSubject.value?.uuid
            // Update the current FP with the new one.
            currentFlightPlanSubject.send(newValue)
            // If it's not the same FP than the previous.
            if newValue?.uuid != currentFlightPlanUuid {
                // Reset the undo stack.
                resetUndoStack()
                // Save his initial states.
                updateInitialFlightPlan(with: newValue)
                updateModifiedFlightPlan(with: newValue)
                cloudUpdatedFlightPlan = nil
            }
        }
    }

    init(flightPlanRepo: FlightPlanRepository,
         flightPlanManager: FlightPlanManager,
         typeStore: FlightPlanTypeStore,
         currentMissionManager: CurrentMissionManager,
         userService: UserService,
         cloudSynchroWatcher: CloudSynchroWatcher?) {
        repo = flightPlanRepo
        self.flightPlanManager = flightPlanManager
        self.typeStore = typeStore
        self.currentMissionManager = currentMissionManager
        self.userService = userService
        updateCloudSynchroWatcher(cloudSynchroWatcher)
    }
}

extension FlightPlanEditionServiceImpl {

    public func updateCloudSynchroWatcher(_ cloudSynchroWatcher: CloudSynchroWatcher?) {
        self.cloudSynchroWatcher = cloudSynchroWatcher
        listenCloudStateUpdates()
    }

    public var currentFlightPlanValue: FlightPlanModel? {
        currentFlightPlan
    }

    public var currentFlightPlanPublisher: AnyPublisher<FlightPlanModel?, Never> {
        currentFlightPlanSubject.eraseToAnyPublisher()
    }

    /// - Parameters:
    ///    - mapPoint: location of the new waypoint
    ///    - index: index at which waypoint should be inserted
    /// - Returns: new waypoint, nil if index is invalid
    public func insertWayPoint(with mapPoint: AGSPoint,
                               at index: Int) -> WayPoint? {
        guard var flightPlan = currentFlightPlan,
              var dataSetting = flightPlan.dataSetting,
              0 < index, index < dataSetting.wayPoints.endIndex,
              let previousWayPoint = dataSetting.wayPoints.elementAt(index: index - 1),
              let nextWayPoint = dataSetting.wayPoints.elementAt(index: index) else { return nil }

        let tilt = (previousWayPoint.tilt + nextWayPoint.tilt) / 2.0

        // Create new waypoint.
        let wayPoint = WayPoint(coordinate: mapPoint.toCLLocationCoordinate2D(),
                                altitude: mapPoint.z.rounded(),
                                speed: nextWayPoint.speed,
                                shouldContinue: dataSetting.shouldContinue,
                                tilt: tilt.rounded())

        // Associate waypoints.
        previousWayPoint.nextWayPoint = wayPoint
        nextWayPoint.previousWayPoint = wayPoint
        wayPoint.previousWayPoint = previousWayPoint
        wayPoint.nextWayPoint = nextWayPoint

        // Insert in array.
        dataSetting.wayPoints.insert(wayPoint, at: index)

        // Update yaws.
        previousWayPoint.updateYaw()
        nextWayPoint.updateYaw()
        wayPoint.updateYaw()
        flightPlan.dataSetting = dataSetting
        // Just triggering
        currentFlightPlan = flightPlan

        return wayPoint
    }

    public func setupFlightPlan(_ flightPlan: FlightPlanModel?) {
        // Reset the current FP.
        // It's especially needed when we setup the same project than the previous one (e.g. after an execution).
        resetFlightPlan()
        // Set the new FP.
        currentFlightPlan = flightPlan
    }

    @discardableResult
    public func addWaypoint(_ wayPoint: WayPoint) -> Int {
        guard var flightplan = currentFlightPlan,
              var dataSetting = flightplan.dataSetting else { return 0 }
        let previous = dataSetting.wayPoints.last
        dataSetting.wayPoints.append(wayPoint)
        wayPoint.previousWayPoint = previous
        previous?.nextWayPoint = wayPoint
        wayPoint.updateYawAndRelations()
        flightplan.dataSetting = dataSetting
        currentFlightPlan = flightplan
        return dataSetting.wayPoints.count
    }

    @discardableResult
    public func removeWaypoint(at index: Int) -> WayPoint? {
        guard var flightplan = currentFlightPlan,
              var dataSetting = flightplan.dataSetting,
              index < dataSetting.wayPoints.endIndex else { return nil }
        let wayPoint = dataSetting.wayPoints.remove(at: index)
        // Update previous and next waypoint yaw.
        let previous = wayPoint.previousWayPoint
        let next = wayPoint.nextWayPoint
        previous?.nextWayPoint = next
        next?.previousWayPoint = previous
        previous?.updateYaw()
        next?.updateYaw()
        flightplan.dataSetting = dataSetting
        currentFlightPlan =  flightplan
        return wayPoint
    }

    public func addPoiPoint(_ poiPoint: PoiPoint) -> Int {
        guard var flightplan = currentFlightPlan,
              var dataSetting = flightplan.dataSetting else {
                  return 0
              }
        dataSetting.pois.append(poiPoint)
        flightplan.dataSetting = dataSetting
        currentFlightPlan = flightplan
        return dataSetting.pois.count
    }

    @discardableResult
    public func removePoiPoint(at index: Int) -> PoiPoint? {
        guard var flightplan = currentFlightPlan,
              var dataSetting = flightplan.dataSetting,
              index < dataSetting.pois.endIndex else {
                  return nil
              }

        dataSetting.wayPoints.forEach {
            guard let poiIndex = $0.poiIndex else { return }

            switch poiIndex {
            case index:
                $0.poiIndex = nil
                $0.poiPoint = nil
            case let supIdx where supIdx > index:
                $0.poiIndex = poiIndex - 1
            default:
                break
            }
        }
        let poi = dataSetting.pois.remove(at: index)
        flightplan.dataSetting = dataSetting
        currentFlightPlan = flightplan
        return poi
    }

    /// Updates capture setting.
    ///
    /// - Parameters:
    ///     - type: setting's type
    ///     - value: setting's value
    public func updateCaptureSetting(type: ClassicFlightPlanSettingType, value: String?) {
        guard let value = value,
              var flightPlan = currentFlightPlan,
              var dataSetting = flightPlan.dataSetting else {
                  return
              }
        // Init captureSettings if needed.
        if dataSetting.captureSettings == nil {
            dataSetting.captureSettings = [:]
        }
        // Save value.
        dataSetting.captureSettings?[type.rawValue] = value
        flightPlan.dataSetting = dataSetting
        currentFlightPlan = flightPlan
    }

    /// Update the polygon points for the current flight plan.
    ///
    /// - Parameters:
    ///     - points: Polygon points
    public func updatePolygonPoints(points: [AGSPoint]) {
        let polygonPoints: [PolygonPoint] = points.map({
            return PolygonPoint(coordinate: $0.toCLLocationCoordinate2D())
        })
        currentFlightPlan?.dataSetting?.polygonPoints = polygonPoints
    }
}

extension FlightPlanEditionServiceImpl: FlightPlanEditionService {

    // MARK: - Private Enums
    private enum Constants {
        // Maximum items in undo stack.
        static let maximumUndoStack: Int = 30
    }

    public func updateFlightPlanType(_ type: String,
                                     resetPolygonPoints: Bool,
                                     settings: [FlightPlanLightSetting]?) {
        guard var flightPlan = currentFlightPlan,
              flightPlan.type != type,
              var dataSetting = flightPlan.dataSetting else { return }

        flightPlan.type = type
        if resetPolygonPoints {
            dataSetting = cleared(flightPlanDataSetting: dataSetting)
        }
        if let lightSettings = settings {
            dataSetting.settings = lightSettings
        }
        resetUndoStack(to: dataSetting)
        flightPlan.dataSetting = dataSetting
        currentFlightPlan = flightPlan
    }

    // MARK: - Undo management

    /// Can undo.
    public func canUndo() -> Bool {
        return undoStack.count > 1
    }

    /// Undo.
    public func undo() {
        guard canUndo() else { return }

        // Dump last.
        popUndoStack()

        // Restore flight plan from data to make another copy.
        // FlightPlan's currentFlightPlan must not point on undo stack.
        if let dataSetting = FlightPlanDataSetting.instantiate(with: undoStack.last),
           var flightPlan = currentFlightPlan {
            flightPlan.dataSetting = dataSetting
            currentFlightPlan = flightPlan
        }
    }

    /// Forget the latest flight plan setting in the undo stack.
    public func popUndoStack() {
        guard !undoStack.isEmpty else { return }

        undoStack.removeLast()
    }

    /// Reset undo stack.
    public func resetUndoStack() {
        resetUndoStack(to: currentFlightPlan?.dataSetting)
    }

    private func resetUndoStack(to dataSetting: FlightPlanDataSetting?) {
        undoStack.removeAll()
        appendUndoStack(with: dataSetting)
    }

    public func appendCurrentStateToUndoStack() {
        appendUndoStack(with: currentFlightPlan?.dataSetting)
    }

    private func appendUndoStack(with setting: FlightPlanDataSetting?) {
        guard let dataSettingString = setting?.toJSONString() else { return }

        // Store flight plan as data to make a copy.
        // FlightPlan's currentFlightPlan must not point on undo stack.
        if undoStack.count >= Constants.maximumUndoStack {
            undoStack.removeFirst()
        }

        undoStack.append(dataSettingString)
    }

    /// Update only global settings of current flight plan and replace it in stack
    ///
    /// - Parameters:
    ///     - dataSetting: data setting to update.
    public func updateGlobalSettings(with dataSetting: FlightPlanDataSetting?) {
        guard let dataSetting = dataSetting?.toJSONString() else { return }
        popUndoStack()
        undoStack.append(dataSetting)
    }

    private func updateThumbnail(flightPlan: FlightPlanModel, completion: @escaping (ThumbnailModel) -> Void) {
        requester.requestThumbnail(flightPlan: flightPlan,
                                   thumbnailSize: FlightPlanThumbnailRequesterConstants.thumbnailSize) { [unowned self] thumbnailImage in
            let uuid = flightPlan.thumbnailUuid ?? UUID().uuidString
            let thumbnail = ThumbnailModel(apcId: userService.currentUser.apcId,
                                           uuid: uuid,
                                           flightUuid: nil,
                                           thumbnailImage: thumbnailImage)
            completion(thumbnail)
        }
    }

    /// Change Flight Plan settings.
    ///
    /// - Parameters:
    ///    - settings: new settings
    public func updateSettings(_ settings: [FlightPlanLightSetting]) {
        guard var flightPlan = currentFlightPlan,
        var dataSetting = flightPlan.dataSetting else { return }

        let diff = zip(dataSetting.settings, settings)
            .filter { $0.0 != $0.1 }
        // use the old setting as flightPlan.dataSteting.settings will contain the updated setting
            .map { $0.0 }
        settingsChanged = diff
        dataSetting.settings = settings
        flightPlan.dataSetting = dataSetting
        currentFlightPlan = flightPlan
        settingsChanged = []
    }

    public func updateDataSetting(_ setting: FlightPlanDataSetting?) {
        if let dataSetting = setting {
            currentFlightPlan?.dataSetting = dataSetting
        }
    }

    public func clearFlightPlan() {
        guard var flightPlan = currentFlightPlan,
              let dataSetting = flightPlan.dataSetting else {
                  return
              }
        flightPlan.dataSetting = cleared(flightPlanDataSetting: dataSetting)
        currentFlightPlan = flightPlan
    }

    private func cleared(flightPlanDataSetting: FlightPlanDataSetting) -> FlightPlanDataSetting {
        var dataSetting = flightPlanDataSetting
        dataSetting.polygonPoints = []
        dataSetting.wayPoints = []
        dataSetting.pois = []
        dataSetting.mavlinkDataFile = nil
        dataSetting.freeSettings = [:]
        return dataSetting
    }

    public func resetFlightPlan() {
        if currentFlightPlan != nil {
            currentFlightPlan = nil
        }
    }

    public func endEdition(completion: @escaping () -> Void) {
        guard var flightPlan = currentFlightPlan,
        var dataSetting = flightPlan.dataSetting else { return }
        flightPlan.lastUpdate = Date()

        // If we received some Cloud state updates from the server (e.g. cloudID), apply them to the current FP.
        if let cloudUpdatedFlightPlan = cloudUpdatedFlightPlan {
            flightPlan.updateCloudState(with: cloudUpdatedFlightPlan)
            // Reset it for next use.
            self.cloudUpdatedFlightPlan = nil
        }

        // clear mavlink data if the data can be generated for this type.
        // mavlink generation is done by FPRunManager > StartedNotFlyingState > MavlinkGenerator
        let type = typeStore.typeForKey(flightPlan.type)
        let canGenerateMavlink = type?.canGenerateMavlink ?? false
        if canGenerateMavlink {
            dataSetting.mavlinkDataFile = nil
            flightPlan.dataSetting = dataSetting
        }

        currentMissionManager.mode.stateMachine?.flightPlanWasEdited(flightPlan: flightPlan)
        currentFlightPlan = flightPlan
        repo.saveOrUpdateFlightPlan(flightPlan,
                                    byUserUpdate: true,
                                    toSynchro: true,
                                    withFileUploadNeeded: false)
        if let projectManager = projectManager, let project = projectManager.project(for: flightPlan) {
            var project = project
            projectManager.setAsLastUsed(project) { lastProject in
                guard let lastProject = lastProject else { return }
                project = lastProject

                if project.title != flightPlan.customTitle {
                    projectManager.rename(project, title: flightPlan.customTitle, completion: nil)
                }
            }
        }
        // Save the FP initial states.
        // This step will allow to have up to date values when re-entering the edition mode.
        updateInitialFlightPlan(with: flightPlan)
        updateModifiedFlightPlan(with: flightPlan)

        // get thumbnail, can take some time to generate thumbnail
        // check for thumbnail dates to update with the most recent one
        updateThumbnail(flightPlan: flightPlan) { [unowned self] thumbnail in
            guard var aFlightPlan = repo.getFlightPlan(withUuid: flightPlan.uuid) else {
                return
            }

            // only store generated thumbnail if none exists or is the newest one from existing thumbnail
            if let aFlightPlanThumbnailLastUpdate = aFlightPlan.thumbnail?.lastUpdate,
               let thumbnailLastUpdate = thumbnail.lastUpdate,
               aFlightPlanThumbnailLastUpdate >= thumbnailLastUpdate {
                return
            }

            aFlightPlan.thumbnail = thumbnail
            ULog.i(.tag, "Updated thumbnail '\(thumbnail.uuid)' of flightPlan '\(aFlightPlan.uuid)'")
            repo.saveOrUpdateFlightPlan(aFlightPlan,
                                        byUserUpdate: true,
                                        toSynchro: true,
                                        withFileUploadNeeded: false)
        }

        ULog.i(.tag, "Ended edition of flightPlan '\(flightPlan.uuid)'")
        completion()
        resetUndoStack()
    }

    public func rename(_ flightPlan: FlightPlanModel, title: String) {
        if flightPlan.uuid == currentFlightPlan?.uuid {
            currentFlightPlan?.customTitle = title
        }
    }

    public func updateFlightPlan(withMavlinkData mavlinkData: Data,
                                 type: FlightPlanType,
                                 disablePhotoSignatureSetting: Bool,
                                 gsdSetting: (key: String, value: Int)) {

        guard let currentFP = currentFlightPlan,
              var flightPlan = type.mavLinkType
                .generateFlightPlanFromMavlink(url: nil,
                                               mavlinkString: String(data: mavlinkData, encoding: .utf8),
                                               flightPlan: currentFP),
              flightPlan.state == .editable,
              var dataSetting = flightPlan.dataSetting else {
                  return
              }
        dataSetting.disablePhotoSignature = disablePhotoSignatureSetting
        // update the GSD settings
        if let currentGsdSettingIndex = dataSetting.settings
            .firstIndex(where: { $0.key == gsdSetting.key }) {
            var currentGsdSetting = dataSetting.settings[currentGsdSettingIndex]
            currentGsdSetting.currentValue = gsdSetting.value
            dataSetting.settings[currentGsdSettingIndex] = currentGsdSetting
        }

        if currentFP.type != flightPlan.type {
            ULog.w(.tag, "Unexpected flightPlan type '\(flightPlan.type)' current '\(currentFP.type)'")
        }
        // Save Mavlink into the intended Mavlink url if needed.
        if !type.canGenerateMavlink {
            dataSetting.mavlinkDataFile = mavlinkData
        }

        // Backup OA settings.
        dataSetting.obstacleAvoidanceActivated = currentFP.dataSetting?.obstacleAvoidanceActivated ?? true
        // Backup capture settings.
        let captureSettings = currentFP.dataSetting?.captureSettings
        dataSetting.captureSettings = captureSettings

        // Update FP data.
        flightPlan.dataSetting = dataSetting
        currentFlightPlan = flightPlan
    }

    public func freeSettingDidChange(key: String, value: String) {
        guard var flightPlan = currentFlightPlan,
              var dataSetting = flightPlan.dataSetting else { return }
        dataSetting.freeSettings[key] = value
        flightPlan.dataSetting = dataSetting
        currentFlightPlan = flightPlan
    }

    public func updateProjectManager(_ projectManager: ProjectManager) {
        self.projectManager = projectManager
    }

    /// Whether the current editing flight plan has changes.
    public var hasChanges: Bool {
        // Ensure the updated FP exists, else inform there is no changes.
        guard let modifiedFlightPlan = modifiedFlightPlan else { return false }
        // Get the initial FP state.
        // If not set (should not occurs), treat as 'FP changed'.
        guard let initialFlightPlan = initialFlightPlan else { return true }
        // Compare both FPs.
        return !initialFlightPlan.hasSameSettings(than: modifiedFlightPlan)
    }

    /// Update the `modifiedFlightPlan`.
    public func updateModifiedFlightPlan(with flightPlan: FlightPlanModel?) {
        updateFlightPlan(&modifiedFlightPlan, with: flightPlan)
    }

    /// Update the `initialFlightPlan`.
    private func updateInitialFlightPlan(with flightPlan: FlightPlanModel?) {
        updateFlightPlan(&initialFlightPlan, with: flightPlan)
    }

    /// Update a  Flight Plan with a copy of another one.
    ///
    /// - Parameters:
    ///    - flightPlan: The Flight Plan to update.
    ///    - updatedFlightPlan: The Flight Plan to copy.
    ///
    /// - Note:
    ///     `newFlightPlan(basedOn:save:)` is used to prevent keeping the same reference of FP properties like `DataSettings`.
    ///     `DataSettings` is a class, this means affecting FPb to FPa then modifying FPb data settings will modify FPa datasettings.
    private func updateFlightPlan(_ flightPlan: inout FlightPlanModel?, with updatedFlightPlan: FlightPlanModel?) {
        guard let updatedFlightPlan = updatedFlightPlan else {
            flightPlan = nil
            return
        }
        flightPlan = flightPlanManager.newFlightPlan(basedOn: updatedFlightPlan,
                                                     save: false)
    }

    /// Listen when a Flight Plan has been updated by a server response.
    private func listenCloudStateUpdates() {
        synchroWatcherSubscriber?.cancel()
        synchroWatcherSubscriber = cloudSynchroWatcher?.flightPlanCloudStateUpdatedPublisher?
            .receive(on: RunLoop.main)
            .sink { [unowned self] in
                // Ensure the updated FP is the one opened in Edition Service.
                guard currentFlightPlan?.uuid == $0.uuid else { return }
                // Save the Cloud state in dedicated local variable.
                // This will be used during endEditing process.
                // Updating directly the currentFlightPlan can cause some unexpected
                // behaviors like removing the keyboard while editing.
                cloudUpdatedFlightPlan = currentFlightPlan
                cloudUpdatedFlightPlan?.updateCloudState(with: $0)
            }
    }
}

private extension FlightPlanInterpreter {
    /// Generates FlightPlan from MAVLink file at given URL or MAVLink string.
    ///
    /// - Parameters:
    ///    - url: url of MAVLink file to parse
    ///    - mavlinkString: MAVLink string to parse
    ///    - flightPlan: the existing flight plan.
    ///
    /// - Returns: generated `FlightPlanModel` is operation succeeded, `nil` otherwise
    func generateFlightPlanFromMavlink(url: URL? = nil,
                                       mavlinkString: String? = nil,
                                       flightPlan: FlightPlanModel?) -> FlightPlanModel? {
        guard let flightPlan = flightPlan else { return nil }
        switch self {
        case .legacy:
            return MavlinkToFlightPlanParser.generateFlightPlanFromMavlinkLegacy(url: url,
                                                                                 mavlinkString: mavlinkString,
                                                                                 flightPlan: flightPlan)
        case .standard:
            return MavlinkToFlightPlanParser.generateFlightPlanFromMavlinkStandard(url: url,
                                                                                   mavlinkString: mavlinkString,
                                                                                   flightPlan: flightPlan)
        }
    }
}
