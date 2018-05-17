//
//  Logger.swift
//  Challenger
//
//  Created by Jay Tucker on 5/17/18.
//  Copyright © 2018 Imprivata. All rights reserved.
//

import Foundation

var dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "HH:mm:ss.SSS"
    return df
}()

func log(_ message: String) {
    let timestamp = dateFormatter.string(from: Date())
    print("[\(timestamp)] \(message)")
}
