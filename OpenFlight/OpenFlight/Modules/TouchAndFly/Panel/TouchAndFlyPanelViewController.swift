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

import UIKit
import Combine

class TouchAndFlyPanelViewController: UIViewController, EditionSettingsCellModelDelegate,
                                        UITableViewDelegate, UITableViewDataSource {

    // MARK: - IBOutlet
    // Container buttons
    @IBOutlet private weak var containerbuttonsPlayDelete: UIStackView!
    @IBOutlet private weak var containerButtonsStop: UIStackView!
    @IBOutlet private weak var containerButtonsProgressView: UIStackView!
    // Buttons
    @IBOutlet private weak var playButton: ActionButton!
    @IBOutlet private weak var deleteButton: ActionButton!
    @IBOutlet private weak var trackingButton: ActionButton!
    @IBOutlet private weak var stopButtonPOI: ActionButton!
    @IBOutlet private weak var buttonsStackView: MainContainerStackView!

    @IBOutlet private weak var constraintButtonStackView: NSLayoutConstraint!
    @IBOutlet private weak var constraintTop: NSLayoutConstraint!

    @IBOutlet private weak var leadingProgressBar: NSLayoutConstraint!
    @IBOutlet private weak var trailingProgressBar: NSLayoutConstraint!
    @IBOutlet private weak var leadingMessageLabel: NSLayoutConstraint!
    @IBOutlet private weak var trailingMessageLabel: NSLayoutConstraint!
    @IBOutlet private weak var spacingProgressButtons: NSLayoutConstraint!

    // Status Drone
    @IBOutlet private weak var messageStatusDrone: UILabel!
    // Progress bar
    @IBOutlet private weak var containerProgressView: UIStackView!
    @IBOutlet private weak var progressViewMessage: UILabel!
    @IBOutlet private weak var progressViewBar: UIProgressView!
    // Loading bar
    @IBOutlet private weak var viewProgressBar: UIView!
    @IBOutlet private weak var viewLoading: UIView!
    @IBOutlet private var arrayLabels: [UILabel]!
    private var loadingProgressBar: LinearProgressBar!

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var shadowView: UIView!

    // MARK: - IBOutlet
    @IBOutlet private weak var containerStream: UIView!
    private weak var mapViewController: MapViewController?
    private var stopStreamOnSizeEvent = false

    // MARK: - Private Properties
    private var viewModel: TouchAndFlyPanelViewModelImpl!
    private var containerStatus: ContainerStatus?
    private var stream: HUDCameraStreamingViewController?

    // MARK: - Private Enums
    private enum ContainerStatus: Int, CustomStringConvertible {
        /// Container is showing the map
        case map
        /// Container is showing the streaming
        case streaming

        /// Debug description.
        public var description: String {
            switch self {
            case .map:          return "map"
            case .streaming:    return "streaming"
            }
        }
    }

    private enum Constants {
        static let progressBarHeightIphone: CGFloat = 5
        static let progressBarHeightIpad: CGFloat = 10
        static let progressViewMessageWaypoint = L10n.touchFlyFlyingToWaypoint
        static let progressViewMessagePOI = L10n.touchFlyTrackingPoi
        static let cellheight: CGFloat = 70.0
        static let streamRatio: CGFloat = 9/16
    }

    // MARK: - Cancellable
    private var cancellables = Set<AnyCancellable>()
    // MARK: - Setup
    static func instantiate(viewModel: TouchAndFlyPanelViewModelImpl) -> TouchAndFlyPanelViewController {
        let viewController: TouchAndFlyPanelViewController = StoryboardScene.TouchAndFlyPanel.touchAndFlyPanel.instantiate()
        viewController.viewModel = viewModel
        return viewController
    }

    // MARK: - Override Funcs
    override func viewDidLoad() {
        super.viewDidLoad()
        registerCell()
        setupTableView()
        setupProgressBar()
        bindViewModel()

        shadowView.addShadow(shadowOffset: CGSize(width: 0, height: -2))

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        containerStream.addGestureRecognizer(tap)
        constraintTop.constant = Layout.hudTopBarHeight(isRegularSizeClass)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initView()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(setUi),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        tableView.tableHeaderView = tableView.tableHeaderView
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if containerStatus == nil {
            containerStatus = .streaming
            startStream()
            self.viewModel.showMap()
            var frame = containerStream.frame
            frame.size.height = frame.size.width * Constants.streamRatio
            containerStream.frame = frame
            tableView.tableHeaderView = containerStream
        }
    }

    // There is a bug in the StreamView. If the size (width or height) is zero, the stream is broken
    // A workaround is to stop and restart the stream
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard containerStatus == .streaming else {
            return
        }
        if (view.frame.size.width == 0 || view.frame.size.height == 0) && !stopStreamOnSizeEvent {
            // bug detected (StreamView)
            stopStream()
            stopStreamOnSizeEvent = true
        } else if view.frame.size.width > 0 && view.frame.size.height > 0 && stopStreamOnSizeEvent {
            // restart the stream
            startStream()
            stopStreamOnSizeEvent = false
        }
    }

    // MARK: - functions to replace stream by map and map by stream
    private func startStream() {
        guard stream == nil else { return }
        let streamVC = HUDCameraStreamingViewController.instantiate()
        addChild(streamVC)

        containerStream.addWithConstraints(subview: streamVC.view)
        streamVC.mode = .preview
        containerStream.addSubview(streamVC.view)
        streamVC.didMove(toParent: self)
        containerStream.updateConstraints()
        stream = streamVC
    }

    private func stopStream() {
        containerStream.subviews.first?.removeFromSuperview()
        stream?.removeFromParent()
        stream = nil
    }

    func hideStream() {
        containerStream.isHidden = true
    }

    func showStream() {
        containerStream.isHidden = false
    }

    /// Show the map in container
    func showMiniMap() {
        let mapViewControllerVC = MapViewController.instantiate()
        addChild(mapViewControllerVC)
        containerStream.addWithConstraints(subview: mapViewControllerVC.view)
        mapViewControllerVC.didMove(toParent: self)
        mapViewController = mapViewControllerVC
        mapViewController?.clearGraphics()
    }

    /// Hide the map in container.
    func hideMiniMap() {
        containerStream.subviews.first?.removeFromSuperview()
        mapViewController?.removeFromParent()
        mapViewController = nil
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        switch containerStatus {
        case .map:
            startStream()
            hideMiniMap()
            containerStatus = .streaming
            viewModel.showMap()
        case .streaming:
            stopStream()
            showMiniMap()
            containerStatus = .map
            viewModel.showStream()
        default:
            break
        }
    }

    // MARK: - Deinit
    deinit {
        self.viewModel.showMap()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Funcs
    func bindViewModel() {
        // SECTION BUTTON
        viewModel.$buttonsDisplay
            .sink { [unowned self] buttonsDisplay in
                switch buttonsDisplay {
                case .standard(playEnabled: let playEnabled, deleteEnabled: let deleteEnabled):
                    setButtonsStandard(playEnabled, deleteEnabled)
                case .runningWaypoint, .runningPoi:
                    hideAllContainers()
                    containerButtonsProgressView.isHidden = false
                }
            }
            .store(in: &cancellables)

        // SECTION INFO STATUS
        viewModel.$infoStatusDrone
            .sink { [unowned self] infoDrone  in
                messageStatusDrone.text = infoDrone.message
                messageStatusDrone.textColor = infoDrone.color
            }
            .store(in: &cancellables)

        // SECTION DISPLAY DASHBOARD
        viewModel.displayOnMapPublisher.sink { [unowned self] _ in
            tableView.reloadData()
        }
        .store(in: &cancellables)

        // PROGRESS BAR VALUE
        viewModel.progressValue
            .sink { [unowned self] progressValue in
                guard let progressValue = progressValue else {
                    progressViewBar.progress = 0.0
                    return
                }
                progressViewBar.progress = Float(progressValue)
            }
            .store(in: &cancellables)

        // PROGRESS TIMER VALUE
        viewModel.progressTimer
            .sink { [unowned self] timer in
                guard let timer = timer else {
                    trackingButton.setTitle("  00:00", for: .normal)
                    return
                }
                let timerFormatted = timer.formattedString
                trackingButton.setTitle("  \(timerFormatted)", for: .normal)
            }
            .store(in: &cancellables)
        viewModel.$progressViewDisplay
            .sink { [unowned self] progressViewDisplay in
                setProgressView(progressViewDisplay: progressViewDisplay)
            }
            .store(in: &cancellables)
    }

    func initView() {
        setUi()
    }

    // MARK: - Action Outlet
    @IBAction func deleteButtonAction(_ sender: UIButton) {
        viewModel.clear()
    }

    @IBAction func playButtonAction(_ sender: UIButton) {
        viewModel.play()
    }

    @IBAction func stopButtonAction(_ sender: UIButton) {
        viewModel.stop()
    }

    @IBAction func trackingButton(_ sender: Any) {
        viewModel.pause()
    }

    // MARK: - EditionSettingsCellModelDelegate
    func updateSettingValue(for key: String?, value: Int) {
        switch key {
        case .some(let valueKey):
            switch valueKey {
            case TouchAndFlyPanelSettingsKey.speed.rawValue:
                viewModel.setValueSpeed(value: value)
            case TouchAndFlyPanelSettingsKey.altitude.rawValue:
                viewModel.setValueAltitude(value: value)
            default:
                break
            }
        case .none:
            break
        }
    }

    func updateChoiceSetting(for key: String?, value: Bool) {
        // nothing to do
    }

    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.displayOnMap.value {
        case .waypoint:
            return 2
        case .poi:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: CenteredRulerTableViewCell
        cell = tableView.dequeueReusableCell(for: indexPath) as CenteredRulerTableViewCell

        // fill it with setting
        cell.backgroundColor = .clear
        cell.fill(with: viewModel.rulerSettings[indexPath.row])
        cell.delegate = self
        cell.selectionStyle = .none
        return cell
    }

    private func setupTableView() {
        tableView.estimatedRowHeight = Constants.cellheight
        tableView.rowHeight = UITableView.automaticDimension
        tableView.makeUp(backgroundColor: .clear)
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func registerCell() {
        tableView.register(cellType: CenteredRulerTableViewCell.self)
    }
}

extension TouchAndFlyPanelViewController {
    @objc func setUi() {
        playButton.setup(image: Asset.Common.Icons.play.image, style: .validate)
        deleteButton.setup(image: Asset.Common.Icons.stop.image, style: .destructive)
        trackingButton.model = ActionButtonModel(image: Asset.Common.Icons.pause.image,
                                                 isMonospacedDigitsFont: true,
                                                 style: .default1)
        stopButtonPOI.setup(image: Asset.Common.Icons.stop.image, style: .destructive)
        constraintButtonStackView.constant = Layout.buttonIntrinsicHeight(isRegularSizeClass)
        buttonsStackView.screenBorders = [.bottom]
        leadingProgressBar.constant = Layout.mainPadding(isRegularSizeClass)
        trailingProgressBar.constant = Layout.mainPadding(isRegularSizeClass)
        leadingMessageLabel.constant = Layout.mainPadding(isRegularSizeClass)
        trailingMessageLabel.constant = Layout.mainPadding(isRegularSizeClass)
        spacingProgressButtons.constant = 0 // TODO: Should be Layout.mainSpacing(isRegularSizeClass)
        for label in arrayLabels {
            label.font = FontStyle.current.font(isRegularSizeClass)
        }
    }

    private func setupProgressBar() {
        let progressBar = LinearProgressBar()
        progressBar.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        progressBar.progressBarColor = ColorName.highlightColor.color

        if isRegularSizeClass {
            progressBar.progressBarHeight = Constants.progressBarHeightIpad
        } else {
            progressBar.progressBarHeight = Constants.progressBarHeightIphone
        }
        viewLoading.addWithConstraints(subview: progressBar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        self.loadingProgressBar = progressBar
    }

    private func hideAllContainers() {
        // Hides all container button
        containerbuttonsPlayDelete.isHidden = true
        containerButtonsStop.isHidden = true
        containerButtonsProgressView.isHidden = true
    }

    // Buttons
    private func setButtonsStandard(_ playEnabled: Bool, _ deleteEnabled: Bool) {
        hideAllContainers()
        containerbuttonsPlayDelete.isHidden = false
        playButton.isEnabled = playEnabled
        deleteButton.isEnabled = deleteEnabled
    }

    private func setProgressView(progressViewDisplay: TouchAndFlyPanelViewModelImpl.ProgressViewDisplay) {
        switch progressViewDisplay {
        case .standard:
            containerProgressView.isHidden = true
            messageStatusDrone.isHidden = false
            loadingProgressBar.stopAnimating()
        case .runningWaypoint:
            containerProgressView.isHidden = false
            progressViewMessage.text = Constants.progressViewMessageWaypoint
            viewProgressBar.isHidden = false
            viewLoading.isHidden = true
            messageStatusDrone.isHidden = true
        case .runningPoi:
            containerProgressView.isHidden = false
            viewProgressBar.isHidden = true
            viewLoading.isHidden = false
            viewLoading.setNeedsLayout()
            loadingProgressBar.startAnimating()
            progressViewMessage.text = Constants.progressViewMessagePOI
            messageStatusDrone.isHidden = true
        }
    }
}

enum TouchAndFlyPanelSettingsKey: String {
    case altitude = "AltitudeTouchAndFlySettingType"
    case speed = "SpeedTouchAndFlySettingType"
}