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

import GroundSdk

/// View model for imaging settings bar video resolution item.
final class ImagingBarVideoResolutionViewModel: BarButtonViewModel<ImagingBarState> {
    // MARK: - Private Properties
    private var cameraRef: Ref<MainCamera2>?
    /// List of available resolutions.
    private let availableResolutions: [Camera2RecordingResolution] = Camera2RecordingResolution.availableResolutions
    /// Current mission manager.
    private unowned let currentMissionManager: CurrentMissionManager

    // MARK: - init
    /// Constructor.
    init(currentMissionManager: CurrentMissionManager) {
        self.currentMissionManager = currentMissionManager
        super.init(barId: "VideoResolution")
    }

    // MARK: - Override Funcs
    override func listenDrone(drone: Drone) {
        listenCamera(drone: drone)
    }

    override func update(mode: BarItemMode) {
        guard let camera = drone?.currentCamera,
            !camera.config.updating,
            let resolution = mode as? Camera2RecordingResolution else {
                return
        }

        let editor = camera.config.edit(fromScratch: true)
        editor[Camera2Params.videoRecordingResolution]?.value = resolution

        // apply restrictions to framerate for current mission, if necessary
        if let restrictions = currentMissionManager.mode.cameraRestrictions,
           let framerate = camera.config[Camera2Params.videoRecordingFramerate]?.value,
           let supportedFrameratesInMission = restrictions.supportedFrameratesByResolution?[resolution],
           !supportedFrameratesInMission.contains(framerate) {
            let currentSupportedValues = editor[Camera2Params.videoRecordingFramerate]?.currentSupportedValues
                .intersection(supportedFrameratesInMission)
            let highestFramerate = Camera2RecordingFramerate.sortedCases.reversed()
                .filter { currentSupportedValues?.contains($0) == true }
                .first
            editor[Camera2Params.videoRecordingFramerate]?.value = highestFramerate
        }

        editor.saveSettings(currentConfig: camera.config)
    }
}

// MARK: - Private Funcs
private extension ImagingBarVideoResolutionViewModel {
    /// Starts watcher for camera.
    func listenCamera(drone: Drone) {
        cameraRef = drone.getPeripheral(Peripherals.mainCamera2) { [weak self] camera in
            guard let camera = camera,
                let copy = self?.state.value.copy(),
                let availableResolutions = self?.availableResolutions
                else {
                    return
            }

            copy.mode = camera.config[Camera2Params.videoRecordingResolution]?.value
            copy.supportedModes = camera.config[Camera2Params.videoRecordingResolution]?.overallSupportedValues
                // Several resolution values must be ignored.
                .intersection(availableResolutions)
                .sorted()
            self?.state.set(copy)
        }
    }
}
