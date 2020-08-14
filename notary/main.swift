//
//  main.swift
//  notary
//
//  Created by sri-7348 on 8/11/20.
//

import Foundation
import ArgumentParser

struct Notarization: ParsableCommand {
    @Argument(help: "The file to notarize")
    var file: String
    @Argument(help: "Your Apple developer account email ID")
    var mailID: String
    #warning("This should be keychain's password object")
    @Argument(help: "Your Apple developer account password")
    var password: String
    #warning("Bundle ID can be made optional flag")
    @Argument(help: "Your software's bundle ID")
    var bundleID: String
    mutating func run() throws {
        let notary = Notary.init()
        notary.mailID = mailID
        notary.password = password
        notary.file = file
        try? notary.notarize()
    }
}
Notarization.main()

