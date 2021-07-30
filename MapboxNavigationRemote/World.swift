import Foundation
import MultipeerKit
import MapboxNavigationRemoteKit
import MapboxNavigationRemoteMultipeerKit
import Combine
#if canImport(AppKit)
import AppKit
#endif

struct World {
    internal init(transceiver: MultipeerTransceiver, dataSource: MultipeerDataSource, responses: World.Responses) {
        self.transceiver = transceiver
        self.dataSource = dataSource
        self.responses = responses
    }

    private var _peers: [Peer] = []

    let transceiver: MultipeerTransceiver
    let dataSource: MultipeerDataSource
    let responses: Responses
    let currentLocationVM: CurrentLocationView.VM = .init()
    let peersListVM: PeersListView.VM = .init()
    let historyFilesVM: HistoryFilesView.VM = .init()    

    var peers: [Peer] {
        get {
            let available = Set(transceiver.availablePeers)
            var validSelected: [Peer] = []
            for p in _peers {
                if available.contains(p) {
                    validSelected.append(p)
                }
            }
            return validSelected
        }
        set {
            let available = Set(transceiver.availablePeers)
            var validSelected: [Peer] = []
            for p in newValue {
                if available.contains(p) {
                    validSelected.append(p)
                }
            }

            _peers = validSelected
        }
    }

    struct Responses {
        let currentLocation: PassthroughSubject<PeerPayload<CurrentLocationResponse>, Never> = .init()
        let stopHistoryRecording: PassthroughSubject<PeerPayload<StopHistoryRecordingResponse>, Never> = .init()
        let listHistoryFiles: PassthroughSubject<PeerPayload<HistoryFilesResponse>, Never> = .init()
        let downloadGpxHistoryFile: PassthroughSubject<PeerPayload<DownloadGpxHistoryFileResponse>, Never> = .init()
    }

    func setupRemoteCli() {
        transceiver.receive(CurrentLocationResponse.self) { payload, sender in
            Current.responses.currentLocation.send(.init(payload: payload, sender: sender))
        }
        transceiver.receive(StopHistoryRecordingResponse.self) { payload, sender in
            Current.responses.stopHistoryRecording.send(.init(payload: payload, sender: sender))
        }
        transceiver.receive(HistoryFilesResponse.self) { payload, sender in
            Current.responses.listHistoryFiles.send(.init(payload: payload, sender: sender))
        }
        transceiver.receive(DownloadHistoryFileResponse.self) { payload, sender in
            saveFile(data: payload.data, name: payload.name)
        }
        transceiver.receive(DownloadGpxHistoryFileResponse.self) { payload, sender in
            Current.responses.downloadGpxHistoryFile.send(.init(payload: payload, sender: sender))
        }
        transceiver.resume()
    }
}

var Current: World = {
    let transceiver = MultipeerTransceiver()
    let datasource = MultipeerDataSource(transceiver: transceiver)
    return .init(
        transceiver: transceiver,
        dataSource: datasource,
        responses: .init()
    )
}()

func saveFile(data: Data, name: String) {
#if canImport(AppKit)
            let panel = NSSavePanel()
            panel.nameFieldLabel = "Save as"
            panel.nameFieldStringValue = name
            panel.canCreateDirectories = true

            panel.begin { response in
                guard response == NSApplication.ModalResponse.OK, let fileUrl = panel.url else {
                    return
                }
                do {
                    try data.write(to: fileUrl)
                }
                catch {
                    print(error)
                }
            }
#else
            #error("Write os aware logic")
#endif
}

func openFile(completion: @escaping (URL) -> Void) {
#if canImport(AppKit)
    let panel = NSOpenPanel()
    panel.nameFieldLabel = "Open GPX File"
    panel.canCreateDirectories = true
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.init(filenameExtension: "gpx")!]
    panel.allowsMultipleSelection = false

    panel.begin { response in
        guard response == NSApplication.ModalResponse.OK, let fileUrl = panel.url else {
            return
        }
        completion(fileUrl)
    }
#else
#error("Write os aware logic")
#endif
}
