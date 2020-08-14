//
//  notary.swift
//  notary
//
//  Created by sri-7348 on 8/11/20.
//

import Foundation
import Combine

class Notary: NSObject, URLSessionDelegate {
    var cancellable: Cancellable?
    var dataCancellable: Cancellable?
    var uuid = String()
    var logURL = String()
    var mailID = String()
    var password = String()
    var file = String()
    var bundleID = String()
    enum NotaryError: Error {
        case statusError
        case notarySuccess
        case notaryUploadError
        case notaryFailed
        case stapleFailed
    }
    /// Combine method to handle notarization lifecycle
    func notarize() throws {
        do {
            try uploadSoftware()
        } catch {
            throw error // any issues in upload, we exit
        }
        let loop = 0..<10
        self.cancellable = loop.publisher
            /// This operator checks notary status
            /// If its still in-progress, we go down the stream and loop through
            /// the array publisher again
            /// We throw if notarization is complete to complete the stream
            .tryMap({ loopCount in
                print("Index count: \(loopCount)")
                let notaryOutput = try self.checkNotarization(for: "")
                if let notaryInfo = notaryOutput["notarization-info"] as? [String: String] {
                    if notaryInfo["Status"] != "inprogress" {
                        if let url = notaryInfo["LogFileURL"] {
                            self.logURL = url
                        }
                        guard notaryInfo["Status Code"] == "0" else {
                            throw NotaryError.notaryFailed
                        }
                        let stapledOutput = self.createProcess(with: ["-c", "stapler staple " + self.file])
                        guard stapledOutput.count == 0 else {
                            throw NotaryError.stapleFailed
                        }
                        throw NotaryError.notarySuccess
                    }
                    print("Notarization is still in progress")
                }
            })
            /// Wait 30s before each notarization
            .debounce(for: .seconds(30), scheduler: RunLoop.main)
            .sink(receiveCompletion: { completion in
                print("Completion recived: \(completion)")
                switch completion {
                       case .finished:
                        print("Notarization checked for 10 times with no result")
                       case .failure(let error):
                        self.printNotarizationLog()
                        if case NotaryError.notarySuccess = error {
                            print("Notarization success")
                        } else {
                            print("Error: Notarization failed with \(error)")
                        }
                }
            }, receiveValue: {
                print("Received value: \($0)")
            })
    }
    ///Method to download and display notarization logs
    /// Uses dataTask publisher to download log
    func printNotarizationLog() {
        if let url = URL.init(string: logURL) {
            let urlSession = URLSession.init(configuration: .default, delegate: self, delegateQueue: nil)
            dataCancellable = urlSession
                .dataTaskPublisher(for: url)
                .sink(receiveCompletion: {
                    print("Notarization log fetch completed with: \($0)")
                }, receiveValue: { data, response in
                    if let logString = String(data: data, encoding: .utf8) {
                        print("Notarization log:")
                        print(logString)
                    }
                })
        }
    }
}
// MARK: - Common utilities
extension Notary {
    /// Method to create process
    /// Common util to execute terminal commands
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
// MARK: - Notarization upload and status check
extension Notary {
    func checkNotarization(for uuid: String) throws -> [String: Any] {
        print("Checking for notarization")
        let arg = ["-c", "xcrun altool --output-format xml --notarization-info " + uuid + "-u " + mailID + " -p " + password]
        let data = createProcess(with: arg)
        if let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]{
            return dict
        }
        throw NotaryError.statusError
    }
    /// Method to upload software for notarization
    /// Throws if there is any issue in uploading/getting UUID from server
    func uploadSoftware() throws {
        print("Uploading package for notarization")
        // Commad to upload file for notarization
        let arg = ["-c", "xcrun altool --notarize-app --output-format xml --primary-bundle-id " + bundleID + " --username "  +  mailID + " -p " + password + " --file " + self.file]
        let data = createProcess(with: arg)
        print("Upload output: \(String(data: data, encoding: .utf8) ?? "")")
        if let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]{
            if let notaryInfo = dict["notarization-upload"] as? [String: String] {
                guard let uuid = notaryInfo["RequestUUID"] else {
                    print("Error: No 'RequestUUID' key")
                    throw NotaryError.notaryUploadError
                }
                self.uuid = uuid
            } else {
                print("Error: No 'notarization-upload' key")
            }
        } else {
            print("Error: JSON parsing failed")
        }
        throw NotaryError.notaryUploadError
    }
}
