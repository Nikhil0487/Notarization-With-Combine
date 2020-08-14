//
//  keyvalue.swift
//  notary
//
//  Created by sri-7348 on 8/11/20.
//

import Foundation
import Combine
/// This class is an example for Key-Value observer combine
/// This classis not used
class ProcessHandler: NSObject {
    @objc dynamic var data = Data()
    func createProces() {
        print("Spawning process")
        let process = Process()
        let pipe = Pipe()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", "open /Applications/Numbers.app"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        data = pipe.fileHandleForReading.readDataToEndOfFile()
    }
}
/// Struct to handle notarization
class TestNotary {
    enum NotaryError: Error {
        case dataError
    }
    var cancellable: Cancellable?
    @objc var processObj = ProcessHandler()
    func notarizeSoftware() {
        cancellable = processObj.publisher(for: \.data)
            .retry(3)
            .tryLast(where: { data in
                guard data.count != 0 else {throw NotaryError.dataError}
                return true
            })
            .sink(receiveCompletion: {_ in
                print("Completion recieved")
            }, receiveValue: { data in
                print("Value is \(data)")
            })
        processObj.createProces()
    }
}
