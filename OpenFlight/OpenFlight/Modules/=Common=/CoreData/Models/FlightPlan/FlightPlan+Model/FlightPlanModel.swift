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

import Foundation
import GroundSdk
import ArcGIS
import CoreLocation

public struct FlightPlanModel {
    // MARK: __ Constants
    private enum Constants {
        static let dateTimeIntervalDivider: TimeInterval = 1000.0
        static let progressRoundPrecision: Int = 4
    }
    // MARK: __ Private
    private var lastModified: Int

    // MARK: __ User's Id
    public var apcId: String

    // MARK: __ Academy
    public var cloudId: Int
    public var uuid: String
    public var customTitle: String
    public var lastUpdate: Date {
        get {
            return Date(timeIntervalSince1970: TimeInterval(lastModified) / Constants.dateTimeIntervalDivider)
        }
        set {
            lastModified = Int(newValue.timeIntervalSince1970 * Constants.dateTimeIntervalDivider)
        }
    }
    public var latestCloudModificationDate: Date?
    public var version: String
    public var type: String
    public var projectUuid: String
    public var thumbnailUuid: String?
    public var dataStringType: String
    public var state: FlightPlanState
    public var lastMissionItemExecuted: Int64
    public var mediaCount: Int16
    public var uploadedMediaCount: Int16

    // MARK: __ Local
    ///  dataSetting: object that saved as JSON to data base
    public var dataSetting: FlightPlanDataSetting?
    /// PGY
    public var pgyProjectId: Int64 {
        get { dataSetting?.pgyProjectId ?? 0 }
        set { dataSetting?.pgyProjectId = newValue }
    }
    public var uploadAttemptCount: Int16 {
        get { dataSetting?.uploadAttemptCount ?? 0 }
        set { dataSetting?.uploadAttemptCount = newValue }
    }
    public var lastUploadAttempt: Date? {
        get { dataSetting?.lastUploadAttempt }
        set { dataSetting?.lastUploadAttempt = newValue }
    }
    /// Identifier of first media resource captured after the drone has passed the `lastMissionItemExecuted`.
    public var recoveryResourceId: String? {
        get { dataSetting?.recoveryResourceId }
        set { dataSetting?.recoveryResourceId = newValue }
    }
    ///  parrotCloudUploadUrl: Contains S3 Upload URL of FlightPlan
    public var parrotCloudUploadUrl: String?
    public var mediaCustomId: String? // UNUSED

    // MARK: __ Relationship
    public var thumbnail: ThumbnailModel?
    public var flightPlanFlights: [FlightPlanFlightsModel]?

    // MARK: __ Synchronization
    ///  Boolean to know if it delete locally but needs to be deleted on server
    public var isLocalDeleted: Bool
    ///  Synchro status
    public var synchroStatus: SynchroStatus?
    ///  Synchro error
    public var synchroError: SynchroError?
    ///  Date of last tried synchro
    public var latestSynchroStatusDate: Date?
    ///  Date of local modification
    public var latestLocalModificationDate: Date?
    ///  Contains 0 if not yet synchronized, 1 if yes,
    ///     statusCode if an error has occured during upload
    public var fileSynchroStatus: Int16?
    ///  fileSynchroDate: Date of synchro file
    public var fileSynchroDate: Date?

    // MARK: - Public init
    public init(apcId: String,
                type: String,
                uuid: String,
                version: String,
                customTitle: String,
                thumbnailUuid: String?,
                projectUuid: String,
                dataStringType: String,
                dataString: String?,
                pgyProjectId: Int64?,
                state: FlightPlanState,
                lastMissionItemExecuted: Int64?,
                mediaCount: Int16?,
                uploadedMediaCount: Int16?,
                lastUpdate: Date = Date(),
                synchroStatus: SynchroStatus? = .notSync,
                fileSynchroStatus: Int16 = 0,
                fileSynchroDate: Date? = nil,
                latestSynchroStatusDate: Date? = nil,
                cloudId: Int? = 0,
                parrotCloudUploadUrl: String? = nil,
                isLocalDeleted: Bool = false,
                latestCloudModificationDate: Date? = nil,
                uploadAttemptCount: Int16? = 0,
                lastUploadAttempt: Date? = nil,
                thumbnail: ThumbnailModel?,
                flightPlanFlights: [FlightPlanFlightsModel]? = nil,
                latestLocalModificationDate: Date? = nil,
                synchroError: SynchroError? = .noError) {

        self.dataSetting = FlightPlanDataSetting.instantiate(with: dataString)
        self.apcId = apcId
        self.type = type
        self.dataStringType = dataStringType
        self.uuid = uuid
        self.version = version
        self.state = state
        self.customTitle = customTitle
        self.lastModified = Int(lastUpdate.timeIntervalSince1970 * Constants.dateTimeIntervalDivider)
        self.mediaCount = mediaCount ?? 0
        self.lastMissionItemExecuted = lastMissionItemExecuted ?? 0
        self.projectUuid = projectUuid
        self.thumbnailUuid = thumbnailUuid
        self.uploadedMediaCount = uploadedMediaCount ?? 0
        self.cloudId = cloudId ?? 0
        self.isLocalDeleted = isLocalDeleted
        self.parrotCloudUploadUrl = parrotCloudUploadUrl
        self.latestSynchroStatusDate = latestSynchroStatusDate
        self.synchroStatus = synchroStatus
        self.fileSynchroDate = fileSynchroDate
        self.fileSynchroStatus = fileSynchroStatus
        self.latestCloudModificationDate = latestCloudModificationDate
        self.thumbnail = thumbnail
        self.flightPlanFlights = flightPlanFlights
        self.latestLocalModificationDate = latestLocalModificationDate
        self.synchroError = synchroError

        self.pgyProjectId = pgyProjectId ?? 0
        self.uploadAttemptCount = uploadAttemptCount ?? 0
        self.lastUploadAttempt = lastUploadAttempt
    }
}

// MARK: - Custom init
extension FlightPlanModel {
    public init(apcId: String,
                uuid: String,
                type: String,
                title: String,
                state: FlightPlanState,
                projectUuid: String,
                dataSetting: FlightPlanDataSetting) {
        self.init(apcId: apcId,
                  type: type,
                  uuid: uuid,
                  version: "1",
                  customTitle: title,
                  thumbnailUuid: nil,
                  projectUuid: projectUuid,
                  dataStringType: "json",
                  dataString: dataSetting.toJSONString(),
                  pgyProjectId: nil,
                  state: state,
                  lastMissionItemExecuted: nil,
                  mediaCount: 0,
                  uploadedMediaCount: nil,
                  lastUpdate: Date(),
                  synchroStatus: .notSync,
                  fileSynchroStatus: 0,
                  latestSynchroStatusDate: nil,
                  cloudId: nil,
                  parrotCloudUploadUrl: nil,
                  isLocalDeleted: false,
                  latestCloudModificationDate: nil,
                  uploadAttemptCount: nil,
                  lastUploadAttempt: nil,
                  thumbnail: nil,
                  flightPlanFlights: [],
                  latestLocalModificationDate: Date(),
                  synchroError: .noError)
    }

    public init(from flightPlan: FlightPlanModel, uuid: String, state: FlightPlanState, title: String) {
        // - Reset data settings
        var dataSetting = flightPlan.dataSetting
        dataSetting?.pgyProjectId = 0
        dataSetting?.uploadAttemptCount = nil
        dataSetting?.lastUploadAttempt = nil
        dataSetting?.recoveryResourceId = nil
        dataSetting?.notPropagatedSettings = [:]
        dataSetting?.takeoffActions = []

        self.init(apcId: flightPlan.apcId,
                  type: flightPlan.type,
                  uuid: uuid,
                  version: flightPlan.version,
                  customTitle: title,
                  thumbnailUuid: nil,
                  projectUuid: flightPlan.projectUuid,
                  dataStringType: flightPlan.dataStringType,
                  dataString: dataSetting?.toJSONString(),
                  pgyProjectId: flightPlan.pgyProjectId,
                  state: state,
                  lastMissionItemExecuted: 0,
                  mediaCount: 0,
                  uploadedMediaCount: 0,
                  lastUpdate: Date(),
                  synchroStatus: .notSync,
                  fileSynchroStatus: 0,
                  fileSynchroDate: nil,
                  latestSynchroStatusDate: nil,
                  cloudId: 0,
                  parrotCloudUploadUrl: nil,
                  isLocalDeleted: false,
                  latestCloudModificationDate: nil,
                  uploadAttemptCount: 0,
                  lastUploadAttempt: nil,
                  thumbnail: nil,
                  flightPlanFlights: [],
                  latestLocalModificationDate: Date(),
                  synchroError: .noError)

        self.dataSetting = dataSetting

        if let fpThumbnail = flightPlan.thumbnail {
            var fpThumbnail = fpThumbnail
            fpThumbnail.uuid = UUID().uuidString
            fpThumbnail.flightUuid = nil
            thumbnailUuid = fpThumbnail.uuid
            thumbnail = fpThumbnail
        }
    }
}

extension FlightPlanModel {
    public enum FlightPlanState: String, CaseIterable, CustomStringConvertible {

        /// Flight Plan States Enum.
        case editable, stopped, flying, completed, uploading, processing, processed, unknown

        public init?(rawString: String?) {
            guard let rawValue = rawString else { return nil }
            self.init(rawValue: rawValue)
        }

        public var description: String {
            switch self {
            case .editable:
                return ".editable"
            case .stopped:
                return ".stopped"
            case .flying:
                return ".flying"
            case .completed:
                return ".completed"
            case .uploading:
                return ".uploading"
            case .processing:
                return ".processing"
            case .processed:
                return ".processed"
            case .unknown:
                return ".unknown"
            }
        }

        public var isExecution: Bool {
            switch self {
            case .editable,
                 .unknown:
                return false
            default:
                return true
            }
        }
    }

    /// Returns formatted date.
    /// - Returns: formatted execution date or dash if formatting failed
    public func formattedDate() -> String {
        let formattedDate = self.flightPlanFlights?.first?.dateExecutionFlight.commonFormattedString
        return formattedDate ?? L10n.flightPlanHistoryExecutionNotSynchronized
    }

    /// Tells if flight Plan should be cleared.
    public func shouldClearFlightPlan() -> Bool {
        return self.dataSetting?.wayPoints.isEmpty == false ||
            self.dataSetting?.pois.isEmpty == false
    }

    public var lastFlightDate: Date? {
        flightPlanFlights?.compactMap { $0.ofFlight?.startTime }.max()
    }
}

// MARK: - `FlightPlanModel` helpers
extension FlightPlanModel {

    var points: [CLLocationCoordinate2D] {
        dataSetting?.wayPoints.compactMap({ $0.coordinate }) ?? []
    }

    var center: CLLocationCoordinate2D? {
        let points = self.points
        guard !points.isEmpty else { return nil }
        var lat = 0.0
        var lng = 0.0
        for point in points {
            lat += point.latitude
            lng += point.longitude
        }
        return CLLocationCoordinate2D(latitude: lat / Double(points.count), longitude: lng / Double(points.count))
    }

    var isEmpty: Bool {
        return self.dataSetting?.polygonPoints.isEmpty == true && points.isEmpty
    }

    public var hasReachedFirstWayPoint: Bool {
        guard let commands = dataSetting?.mavlinkCommands else { return lastMissionItemExecuted > 0 }
        guard let firstWayPointIndex = commands.firstIndex(where: { $0 is MavlinkStandard.NavigateToWaypointCommand })
        else { return false }
        return lastMissionItemExecuted >= firstWayPointIndex
    }

    var hasReachedLastWayPoint: Bool {
        guard let commands = dataSetting?.mavlinkCommands,
              let lastWayPointIndex = commands.lastIndex(where: { $0 is MavlinkStandard.NavigateToWaypointCommand })
        else { return false }
        return lastMissionItemExecuted >= lastWayPointIndex
    }

    /// Returns last passed waypoint index.
    var lastPassedWayPointIndex: Int? {
        // Ensure we can access Mavlink commands
        guard let commands = dataSetting?.mavlinkCommands else { return nil }
        // Check if the first Way Point reached
        guard hasReachedFirstWayPoint else { return nil }
        // Calculate the number of NavigateToWaypointCommand commands executed until the lastMissionItemExecuted
        return commands
            .prefix(Int(lastMissionItemExecuted) + 1)
            .filter { $0 is MavlinkStandard.NavigateToWaypointCommand }
            .count - 1
    }

    public var percentCompleted: Double {
        // Get the last drone location for the FP run.
        // This location is updated by the `FlightPlanRunManager`during the flight.
        guard let droneLocation = dataSetting?.lastDroneLocation else {
            // Handle the backward compatibility.
            // Calculate an estimated progress with the number of executed Mavlink commands.
            if let commands = dataSetting?.mavlinkCommands,
               !commands.isEmpty {
                return Double(lastMissionItemExecuted) / Double(commands.count) * 100
            }
            return 0
        }

        // Ensure a `lastPassedWayPointIndex` exists
        guard let lastPassedWayPointIndex = lastPassedWayPointIndex else { return 0 }

        // Calculate the progress
        let progress = dataSetting?.completionProgress(with: droneLocation.agsPoint,
                                                       lastWayPointIndex: lastPassedWayPointIndex) ?? 0
        return progress.rounded(toPlaces: Constants.progressRoundPrecision) * 100.0
    }

    var lastFlightExecutionDate: Date? {
        return self.flightPlanFlights?.compactMap { $0.dateExecutionFlight }.max()
    }

    /// Update the Flight Plan's Cloud State.
    ///
    /// - Parameter flightPlan: the flight plan with updated cloud state
    mutating func updateCloudState(with flightPlan: FlightPlanModel) {
        // Ensure it's the correct FP.
        guard uuid == flightPlan.uuid else { return }
        // Ensure to have a valid CloudID before overwriting it.
        cloudId = flightPlan.cloudId > 0 ? flightPlan.cloudId : cloudId
        latestCloudModificationDate = flightPlan.latestCloudModificationDate
        synchroError = flightPlan.synchroError
        synchroStatus = flightPlan.synchroStatus
        latestSynchroStatusDate = flightPlan.latestSynchroStatusDate
        latestLocalModificationDate = flightPlan.latestLocalModificationDate
    }

    // MARK: Edition mode
    /// Indicates if a Flight Plan has the same settings than the one passed in parameters.
    ///
    /// - Parameters:
    ///  - flightPlan: The flight plan to compare.
    ///
    /// - Returns: `true` if settings (Custom Title and Data Settings) are identicals, `false` in other cases.
    func hasSameSettings(than flightPlan: FlightPlanModel) -> Bool {
        // Checking title.
        guard customTitle == flightPlan.customTitle else { return false }
        // Checking Data Settings.
        return dataSetting == flightPlan.dataSetting
    }
}

/// Extension for Equatable conformance.
extension FlightPlanModel: Equatable {
    public static func == (lhs: FlightPlanModel, rhs: FlightPlanModel) -> Bool {
        lhs.apcId == rhs.apcId
        && lhs.type == rhs.type
        && lhs.uuid == rhs.uuid
        && lhs.version == rhs.version
        && lhs.customTitle == rhs.customTitle
        && lhs.thumbnailUuid == rhs.thumbnailUuid
        && lhs.projectUuid == rhs.projectUuid
        && lhs.dataStringType == rhs.dataStringType
        && lhs.dataSetting == rhs.dataSetting
        && lhs.pgyProjectId == rhs.pgyProjectId
        && lhs.state == rhs.state
        && lhs.lastMissionItemExecuted == rhs.lastMissionItemExecuted
        && lhs.mediaCount == rhs.mediaCount
        && lhs.uploadedMediaCount == rhs.uploadedMediaCount
        && lhs.lastUpdate == rhs.lastUpdate
        && lhs.synchroStatus == rhs.synchroStatus
        && lhs.fileSynchroStatus == rhs.fileSynchroStatus
        && lhs.fileSynchroDate == rhs.fileSynchroDate
        && lhs.latestSynchroStatusDate == rhs.latestSynchroStatusDate
        && lhs.cloudId == rhs.cloudId
        && lhs.parrotCloudUploadUrl == rhs.parrotCloudUploadUrl
        && lhs.isLocalDeleted == rhs.isLocalDeleted
        && lhs.latestCloudModificationDate == rhs.latestCloudModificationDate
        && lhs.uploadAttemptCount == rhs.uploadAttemptCount
        && lhs.lastUploadAttempt == rhs.lastUploadAttempt
        && lhs.thumbnail == rhs.thumbnail
        && lhs.flightPlanFlights == rhs.flightPlanFlights
        && lhs.latestLocalModificationDate == rhs.latestLocalModificationDate
        && lhs.synchroError == rhs.synchroError
    }
}
