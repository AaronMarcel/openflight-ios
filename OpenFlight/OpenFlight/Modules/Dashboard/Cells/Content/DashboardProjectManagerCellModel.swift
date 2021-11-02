//
//
//  Copyright (C) 2021 Parrot Drones SAS.
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

/// Summary about all projects.
public struct AllProjectsSummary {
    /// Total number of projects.
    public let numberOfProjects: Int
    /// Total number of FP projects.
    public let numberOfFPProjects: Int
    /// Total number of other projects.
    public let numberOfOtherProjects: Int
    /// The other projects' icon.
    public let ortherProjectsIcon: UIImage?

    static let zero = AllProjectsSummary(numberOfProjects: 0,
                                         numberOfFPProjects: 0,
                                         numberOfOtherProjects: 0,
                                         ortherProjectsIcon: nil)
}

public class DashboardProjectManagerCellModel {

    // MARK: - Public properties
    public var summary: AnyPublisher<AllProjectsSummary, Never> { summarySubject.eraseToAnyPublisher() }
    public var isSynchronizingData: AnyPublisher<Bool, Never> { isSynchronizingSubject.eraseToAnyPublisher() }

    // MARK: - Private properties
    private let manager: ProjectManager
    private let cloudSynchroWatcher: CloudSynchroWatcher?
    private let projectManagerUiProvider: ProjectManagerUiProvider!
    private var summarySubject = CurrentValueSubject<AllProjectsSummary, Never>(AllProjectsSummary.zero)
    private var isSynchronizingSubject = CurrentValueSubject<Bool, Never>(false)
    private var cancellable = Set<AnyCancellable>()

    init(manager: ProjectManager,
         cloudSynchroWatcher: CloudSynchroWatcher?,
         projectManagerUiProvider: ProjectManagerUiProvider) {
        self.manager = manager
        self.cloudSynchroWatcher = cloudSynchroWatcher
        self.projectManagerUiProvider = projectManagerUiProvider

        listenProjectsPublisher()
        listenDataSynchronization()

        summarySubject.value = projectsSummary(for: manager.loadAllProjects())
    }

    // MARK: - Private funcs
    private func listenProjectsPublisher() {
        manager.projectsPublisher
            .sink { [unowned self] projects in
                summarySubject.value = projectsSummary(for: projects)
            }
            .store(in: &cancellable)

    }

    private func listenDataSynchronization() {
        cloudSynchroWatcher?.isSynchronizingDataPublisher
            .sink { [unowned self] isSynch in
                isSynchronizingSubject.value = isSynch
            }
            .store(in: &cancellable)
    }

    func reloadAllProjects() {
        summarySubject.value = projectsSummary(for: manager.loadAllProjects())
    }

    func projectsSummary(for projects: [ProjectModel]) -> AllProjectsSummary {
        let fpProjects = projects.filter { $0.isSimpleFlightPlan }
        let otherProjects = projects.filter { !$0.isSimpleFlightPlan }
        let projectTypes = projectManagerUiProvider.uiParameters().projectTypes
        let ortherProjectsIcon = projectTypes.count > 1 ? projectTypes[1].icon : nil

        return AllProjectsSummary(numberOfProjects: projects.count,
                                  numberOfFPProjects: fpProjects.count,
                                  numberOfOtherProjects: otherProjects.count,
                                  ortherProjectsIcon: ortherProjectsIcon)
    }
}