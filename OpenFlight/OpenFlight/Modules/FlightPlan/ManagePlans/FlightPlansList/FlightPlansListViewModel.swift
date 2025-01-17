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
import Combine

/// Describes FlightPlansList ViewController display mode.
enum FlightPlansListDisplayMode {
    /// Part of a sub view controller.
    case compact
    /// Part of of the view controller is visible but all executions should be loaded
    case dashboard
}

/// Struct used in order to pass the necessary information to the `FlightPlanCollectionViewCell`
struct CellProjectListProvider {
    /// Selected state
    var isSelected: Bool
    /// project model
    var project: ProjectModel
}

// MARK: - Protocols
protocol FlightPlansListViewModelDelegate: AnyObject {
    /// Called when user selects a `ProjectModel`.
    func didSelect(project: ProjectModel)
    /// Called when user selects a `FlightPlanModel`.
    func didSelect(execution: FlightPlanModel)
    /// Called when user double tap on a project
    func didDoubleTap(on project: ProjectModel)
}

/// Protocol allow to communicate from UIViewController to ViewModel
protocol FlightPlansListViewModelUIInput {

    /// Displaying Controller on `Compact` or `Full`
    var displayMode: FlightPlansListDisplayMode { get }

    /// Publisher that give new UUID value of selected project.
    var uuidPublisher: AnyPublisher<String?, Never> { get }

    /// Publisher that give value of changed array of `ProjectModel`
    var allProjectsPublisher: AnyPublisher<[ProjectModel], Never> { get }

    /// Select a project, from the filtered projects list, via his index.
    ///
    /// - Parameters:
    ///    - index: Project's index.
    ///
    /// - Returns:
    ///    - The selected `ProjectModel` if exists, or nil.
    @discardableResult
    func selectProject(at index: Int) -> ProjectModel?

    /// Select project.
    ///
    /// - Parameters:
    ///     - project: The project model
    func selectProject(_ project: ProjectModel)

    /// Return the index of a project in the current projects list.
    ///
    /// - Parameters:
    ///     - project: The project model
    func indexOfProject(_ project: ProjectModel) -> Int

    /// Deselect project.
    func deselectProject()

    /// Select flight plan execution from flight Plans executions array.
    ///
    /// - Parameters:
    ///     - execution: the flight plan model representing the execution
    func selectExecution(_ execution: FlightPlanModel)

    /// Setup corresponding delegate of type `FlightPlansListViewModelDelegate`
    ///
    /// - Parameters:
    ///     - delegate: Handle selection of flight plan
    func setupDelegate(with delegate: FlightPlansListViewModelDelegate)

    /// Initialize ViewModel at beginning
    func initViewModel()

    /// Select flight plan from flight Plans array.
    ///
    /// - Parameters:
    ///     - delegate: Handle selection of flight plan
    func projectProvider(at index: Int) -> CellProjectListProvider?

    /// Retrieve flight plan executions from project.
    ///
    /// - Parameters:
    ///     - project: The project to retrieve execution for.
    func flightPlanExecutions(ofProject project: ProjectModel) -> [FlightPlanModel]

    /// Return number of flight plan available
    func projectsCount() -> Int

    /// Check for IndexPath to get more flights
    func shouldGetMoreProjects(fromIndexPath indexPath: IndexPath)

    /// Get more projects to display
    @discardableResult func getMoreProjects() -> Bool

    /// Return corresponding Header provider to display it on Header
    func headerCellProvider() -> [FlightPlanListHeaderCellProvider]

    /// Double tap on a flight plan
    ///
    /// - Parameters:
    ///     - index: index of selected flight plan
    func openProject(at index: Int)

    /// Get selected project index
    ///
    /// - Parameters:
    ///     - forSelectedProject: the selected project
    func getProjectIndex(forSelectedProject: ProjectModel?) -> Int?
}

/// Protocol allow to communicate from Parent ViewModel to Child ViewModel
protocol FlightPlansListViewModelParentInput {

    /// Update uuid with corresponding entry.
    ///
    /// - Parameters:
    ///     - uuid: Optioanl String value, to update new uuid
    func updateUUID(with uuid: String?)

    /// Setup new display mode to corresponding View
    ///
    /// - Parameters:
    ///     - mode: FlightPlansListDisplayMode
    func setupDisplayMode(with mode: FlightPlansListDisplayMode)

    /// Setup corresponding delegate of type `FlightPlansListViewModelDelegate`
    ///
    /// - Parameters:
    ///     - delegate: Handle selection of flight plan
    func setupDelegate(with delegate: FlightPlansListViewModelDelegate)

    /// Update the Navigation Stack.
    ///
    /// - Parameters:
    ///    - selectedProject: current selected project
    func updateNavigationStack(with selectedProject: ProjectModel?)
}

final class FlightPlansListViewModel {

    // MARK: - Private variables
    @Published private var uuid: String?
    private var filteredProjects = CurrentValueSubject<[ProjectModel], Never>([])
    private var headerProvider: [FlightPlanListHeaderCellProvider] = []
    private(set) var displayMode: FlightPlansListDisplayMode = .compact
    private weak var delegate: FlightPlansListViewModelDelegate?
    private var flightPlanTypeStore: FlightPlanTypeStore
    private let manager: ProjectManager
    private let navigationStack: NavigationStackService
    private var cancellables = Set<AnyCancellable>()
    private var selectedHeaderUuid: String?

    init(manager: ProjectManager,
         flightPlanTypeStore: FlightPlanTypeStore,
         navigationStack: NavigationStackService,
         cloudSynchroWatcher: CloudSynchroWatcher?,
         selectedHeaderUuid: String?) {
        self.manager = manager
        self.flightPlanTypeStore = flightPlanTypeStore
        self.navigationStack = navigationStack
        self.selectedHeaderUuid = selectedHeaderUuid

        cloudSynchroWatcher?.isSynchronizingDataPublisher
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isSynchronizingData in
                if !isSynchronizingData {
                    self?.initViewModel()
                }
            }).store(in: &cancellables)

        manager.projectsDidChangePublisher
            .sink { [unowned self] in
                initViewModel()
            }
            .store(in: &cancellables)
    }

    // MARK: - Private funcs
    private func loadAllProjects() -> [ProjectModel] {
        if displayMode == .compact {
            return manager.loadProjects(type: Services.hub.currentMissionManager.mode.flightPlanProvider?.projectType)
        } else {
            return manager.loadExecutedProjects(offset: 0, limit: manager.numberOfProjectsPerPage, withType: nil)
        }
    }

    private func didSelect(project: ProjectModel) {
        updateUUID(with: project.uuid)
    }

    private func didDeselectProjects() {
        updateUUID(with: nil)
    }

    /// Construct array of `FlightPlanListHeaderCellProvider` from given array of `ProjectModel`
    // TODO: Filter header for projects should not be based on a any flight plan's type
    private func buildHeader(_ projects: [ProjectModel]) {
        var headerCellProviders = [FlightPlanListHeaderCellProvider]()
        let classicCount = manager.getExecutedProjectsCount(withType: .classic)
        let pgyCount = manager.getExecutedProjectsCount(withType: .pgy)

        if classicCount != 0 {
            let defaultFlightPlanType = getDefaultFlightPlanType()
            let provider = FlightPlanListHeaderCellProvider(
                uuid: ProjectType.classic.rawValue,
                count: classicCount,
                missionType: defaultFlightPlanType?.missionProvider.mission.name,
                logo: defaultFlightPlanType?.missionProvider.mission.icon,
                isSelected: false
            )
            headerCellProviders.append(provider)
        }

        if pgyCount != 0 {
            let pgyFlightPlanType = getPgyFlightPlanType()
            let provider = FlightPlanListHeaderCellProvider(
                uuid: ProjectType.pgy.rawValue,
                count: pgyCount,
                missionType: pgyFlightPlanType?.missionProvider.mission.name,
                logo: pgyFlightPlanType?.missionProvider.mission.icon,
                isSelected: false
            )
            headerCellProviders.append(provider)
        }

        headerProvider = headerCellProviders
    }

    private func isSelected(uuid: String) -> Bool {
        return self.uuid == uuid
    }
}

// MARK: - FlightPlansListViewModelUIInput
extension FlightPlansListViewModel: FlightPlansListViewModelUIInput {

    func flightPlanExecutions(ofProject project: ProjectModel) -> [FlightPlanModel] {
        manager.executedFlightPlans(for: project)
    }

    func selectProject(_ project: ProjectModel) {
        didSelect(project: project)
    }

    func deselectProject() {
        didDeselectProjects()
    }

    func openProject(at index: Int) {
        // Select the project, if not yet done, and ensure it still exists.
        guard let project = selectProject(at: index) else { return }
        // Ask the delegate to open the project.
        delegate?.didDoubleTap(on: project)
    }

    var uuidPublisher: AnyPublisher<String?, Never> {
        $uuid.eraseToAnyPublisher()
    }

    var allProjectsPublisher: AnyPublisher<[ProjectModel], Never> {
        filteredProjects.eraseToAnyPublisher()
    }

    func indexOfProject(_ project: ProjectModel) -> Int {
        filteredProjects.value.firstIndex(where: { project.uuid == $0.uuid }) ?? 0
    }

    @discardableResult
    func selectProject(at index: Int) -> ProjectModel? {
        // Ensure index is not out of range.
        guard index < filteredProjects.value.count else { return nil }
        // Get the project from the filtered list.
        let project = filteredProjects.value[index]
        // Publish the selected project's `uuid`.
        didSelect(project: project)
        // Inform the delegate about the selection.
        delegate?.didSelect(project: project)
        return project
    }

    func selectExecution(_ execution: FlightPlanModel) {
        delegate?.didSelect(execution: execution)
    }

    func setupDelegate(with delegate: FlightPlansListViewModelDelegate) {
        self.delegate = delegate
    }

    func initViewModel() {
        let projects = loadAllProjects()
        switch displayMode {
        case .dashboard:
            filteredProjects.value = projects
            buildHeader(projects)
            updateFilteredProjects()
        case .compact:
            filteredProjects.value = projects
        }
    }

    func projectProvider(at index: Int) -> CellProjectListProvider? {
        if index < filteredProjects.value.count {
            let project = filteredProjects.value[index]
            let isSelected = isSelected(uuid: project.uuid)
            return CellProjectListProvider(isSelected: isSelected, project: project)
        }
        return nil
    }

    func projectsCount() -> Int {
        filteredProjects.value.count
    }

    func getProjectIndex(forSelectedProject: ProjectModel?) -> Int? {
        guard let forSelectedProject = forSelectedProject else {
            return nil
        }

        if let index = filteredProjects.value.firstIndex(where: { $0.uuid == forSelectedProject.uuid }) {
            return index
        } else {
            while getMoreProjects() {
                if let index = filteredProjects.value.firstIndex(where: { $0.uuid == forSelectedProject.uuid }) {
                    return index
                }
            }
        }

        return nil
    }

    func shouldGetMoreProjects(fromIndexPath indexPath: IndexPath) {
        if indexPath.row == projectsCount() - 1 {
            getMoreProjects()
        }
    }

    @discardableResult
    func getMoreProjects() -> Bool {
        let projectsCount = projectsCount()
        var type: ProjectType?
        if selectedHeaderUuid != nil,
           let provider = headerProvider.first(where: { $0.uuid == selectedHeaderUuid }),
           let projectType = ProjectType(rawString: provider.uuid) {
            type = projectType
        }
        let allCount = manager.getExecutedProjectsCount(withType: type)
        guard projectsCount < allCount else {
            return false
        }
        let moreProjects = manager.loadExecutedProjects(offset: projectsCount, limit: manager.numberOfProjectsPerPage, withType: type)
        if !moreProjects.isEmpty {
            filteredProjects.value.append(contentsOf: moreProjects)
        }
        return true
    }

    func updateFilteredProjects() {
        var type: ProjectType?
        if selectedHeaderUuid != nil,
           let provider = headerProvider.first(where: { $0.uuid == selectedHeaderUuid }),
           let projectType = ProjectType(rawString: provider.uuid) {
            type = projectType
        }

        filteredProjects.value = manager.loadExecutedProjects(offset: 0,
                                                              limit: manager.numberOfProjectsPerPage,
                                                              withType: type)
    }

    func headerCellProvider() -> [FlightPlanListHeaderCellProvider] {
        return headerProvider
    }

    func updateNavigationStack(with selectedProject: ProjectModel?) {
        navigationStack.updateLast(with: .myFlightsExecutedProjects(selectedProject: selectedProject,
                                                                    selectedHeaderUuid: selectedHeaderUuid))
    }
}

// MARK: - FlightPlansListViewModelParentInput
extension FlightPlansListViewModel: FlightPlansListViewModelParentInput {
    func updateUUID(with selectedUUID: String?) {
        if uuid != selectedUUID {
            uuid = selectedUUID
        }
    }

    func setupDisplayMode(with mode: FlightPlansListDisplayMode) {
        displayMode = mode
    }
}

// MARK: - FlightPlanListHeaderDelegate
extension FlightPlansListViewModel: FlightPlanListHeaderDelegate {
    func didSelectItemAt(_ provider: FlightPlanListHeaderCellProvider) {
        // get currentProvider and index
        guard let currentProvider = headerProvider.first(where: { $0.uuid == provider.uuid }),
              let index = headerProvider.firstIndex(of: currentProvider) else { return }

        // Set all element to false
        headerProvider = headerProvider.map { value in
            var element = value
            element.isSelected = false
            return element
        }

        // Set selected element on current selected value
        headerProvider[index].isSelected = provider.isSelected
        selectedHeaderUuid = provider.isSelected ? headerProvider[index].uuid : nil
        // update the selection
        updateFilteredProjects()
        // update navigation stack to save the current filter
        updateNavigationStack(with: filteredProjects.value.first { $0.uuid == uuid })
    }
}

private extension FlightPlansListViewModel {
    func flightPlanType(forType type: String?) -> FlightPlanType? {
        return Services.hub.flightPlan.typeStore.typeForKey(type)
    }

    func getDefaultFlightPlanType() -> FlightPlanType? {
        return Services.hub.flightPlan.typeStore.typeForKey("default")
    }

    func getPgyFlightPlanType() -> FlightPlanType? {
        return Services.hub.flightPlan.typeStore.typeForKey("photogrammetry_simple_grid")
    }
}
