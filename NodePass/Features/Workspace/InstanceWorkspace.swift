//
//  InstanceWorkspace.swift
//  NodePass
//
//  Operations on the instances of one master in a macOS window.
//
//  The table, its context menu, the toolbar, the inspector and the Instance menu all act through
//  this object, so an operation behaves the same wherever it starts. `MasterWorkspaceView` owns
//  it and presents what it asks for: confirmations, batch reports and the editor sheet.
//

#if os(macOS)
import Foundation
import Observation

@Observable
@MainActor
final class InstanceWorkspace {
    let session: MasterSession
    let master: Server
    let commander = InstanceCommander()

    var filter = InstanceFilter()
    var editorMode: InstanceEditorView.Mode?

    /// Pending "Add Tag" prompt.
    var tagTargets: [String] = []
    var tagKey = ""
    var tagValue = ""

    private let navigation: NavigationModel
    private let settings: AppSettings

    init(session: MasterSession, master: Server, navigation: NavigationModel, settings: AppSettings) {
        self.session = session
        self.master = master
        self.navigation = navigation
        self.settings = settings
    }

    // MARK: Selection

    /// Selected instances that still exist, in a stable order.
    var selectedIDs: [String] {
        navigation.selectedInstanceIDs.filter { session.instance($0) != nil }.sorted()
    }

    /// The instances an operation applies to: `ids` when given (a context menu's rows), otherwise
    /// the selection.
    func targets(_ ids: Set<String>? = nil) -> [Instance] {
        let source = ids.map { Array($0).sorted() } ?? selectedIDs
        return source.compactMap(session.instance)
    }

    // MARK: Control

    func canRun(_ action: InstanceAction, on ids: Set<String>? = nil) -> Bool {
        targets(ids).contains { action.isApplicable(to: $0.status) && !session.isBusy($0.id) }
    }

    func run(_ action: InstanceAction, on ids: Set<String>? = nil) {
        let applicable = targets(ids).filter { action.isApplicable(to: $0.status) }.map(\.id)
        commander.run(action, on: applicable, session: session, settings: settings)
    }

    /// `true` or `false` when every target agrees, `nil` when they differ or there are none.
    func autoRestart(of ids: Set<String>? = nil) -> Bool? {
        let values = Set(targets(ids).map(\.restart))
        return values.count == 1 ? values.first : nil
    }

    func setAutoRestart(_ enabled: Bool, on ids: Set<String>? = nil) {
        commander.setRestartPolicy(enabled, on: targets(ids).map(\.id), session: session)
    }

    func delete(_ ids: Set<String>? = nil) {
        let doomed = targets(ids).map(\.id)
        commander.delete(doomed, session: session, settings: settings) { [navigation] in
            navigation.selectedInstanceIDs.subtract(doomed)
        }
    }

    func refresh() {
        Task {
            await session.refreshInstances()
            await session.refreshInfo()
        }
    }

    // MARK: Editing

    func createInstance(prefill: InstanceURL? = nil) {
        editorMode = .create(prefill: prefill)
    }

    func edit(_ id: String) {
        guard let instance = session.instance(id) else { return }
        editorMode = .edit(instance)
    }

    func duplicate(_ id: String) {
        guard let instance = session.instance(id) else { return }
        editorMode = .duplicate(instance)
    }

    func didCreate(_ instance: Instance) {
        navigation.selectedInstanceIDs = [instance.id]
    }

    /// Opens the editor prefilled with the first dropped or pasted URL this master can run.
    @discardableResult
    func createInstance(fromURLs strings: [String]) -> Bool {
        for string in strings {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = try? InstanceURL(parsing: trimmed), url.flavor == session.flavor {
                createInstance(prefill: url)
                return true
            }
        }
        return false
    }

    func beginTagging(_ ids: Set<String>? = nil) {
        tagTargets = targets(ids).map(\.id)
        tagKey = ""
        tagValue = ""
    }

    func commitTag() {
        commander.applyTag(
            key: tagKey.trimmingCharacters(in: .whitespaces),
            value: tagValue.trimmingCharacters(in: .whitespaces),
            on: tagTargets,
            session: session)
        tagTargets = []
    }

    // MARK: Clipboard

    func copyURLs(_ ids: Set<String>? = nil) {
        Clipboard.copy(targets(ids).map(\.url).joined(separator: "\n"))
    }

    func consoleTarget(for id: String) -> ConsoleTarget {
        ConsoleTarget(masterID: session.id, instanceID: id)
    }
}
#endif
