//
//  CameraType.swift
//  Navigator
//
//  Created by Shuichi Tsutsumi on 2018/06/20.
//  Modified by wireMuffin on 20/4/2020.
//  Original Work Copyright © 2018 Shuichi Tsutsumi. All rights reserved.
//  Modified Work Copyright © 2020 wireMuffin. All rights reserved.
//

import AVFoundation

enum CameraType : Int {
    case back
    case front
    
    func captureDevice() -> AVCaptureDevice {
        switch self {
        case .front:
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices
            print("devices:\(devices)")
            for device in devices where device.position == .front {
                return device
            }
        default:
            break
        }
        return AVCaptureDevice.default(for: .video)!
    }
}
