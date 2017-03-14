//
//  main.swift
//  transcode-cli
//
//  Created by tianyi on 13/3/17.
//  Copyright © 2017 tianyi. All rights reserved.
//

import Foundation

let transcoder = Transcoder()
transcoder.createServer()
transcoder.transferKey()
transcoder.generateScript()
transcoder.transferScript()
transcoder.runScript()
