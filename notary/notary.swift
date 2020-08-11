//
//  notary.swift
//  notary
//
//  Created by sri-7348 on 8/11/20.
//

import Foundation
import Combine

class Notary {
    var cancellable: Cancellable?
    enum NotaryError: Error {
        case statusError
        case notaryCompleted
    }
    func checkNotarization(for uuid: String) throws -> [String: Any] {
        print("Spawning process")
        let arg = ["-c", "xcrun altool --output-format xml --notarization-info " + uuid + "-u <mailID> -p <password>" ]
        let data = createProcess(with: arg)
        if let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]{
            return dict
        }
        throw NotaryError.statusError
    }
    /// Combine method to handle notarization lifecycle
    func notarize() {
        /// - ToDo: Upload software package
        let loop = 0..<10
        self.cancellable = loop.publisher
            .tryMap({ _ in
                print("Index count: ")
                let notaryOutput = try self.checkNotarization(for: "")
                if let notaryInfo = notaryOutput["notarization-info"] as? [String: String] {
                    if notaryInfo["Status"] != "inprogress" {
                        throw NotaryError.notaryCompleted
                    }
                }
            })
            .debounce(for: .seconds(30), scheduler: RunLoop.main)
            .sink(receiveCompletion: { data in
                print("Completion recived: \(data)")
            }, receiveValue: {
                print("Received value: \($0)")
            })
    }
    /// Method to create process
    func createProcess(with arguments: [String]) -> Data {
        let process = Process()
        let pipe = Pipe()
        process.launchPath = "/bin/bash"
        process.arguments = arguments
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return data
    }
}
