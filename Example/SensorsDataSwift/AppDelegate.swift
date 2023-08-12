//
// AppDelegate.swift
// SensorsDataSwift
//
// Created by 王灼洲 on 2017/11/9.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import SensorsAnalyticsSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        //MARK:初始化sdk
        let options = SAConfigOptions(serverURL: "http://sdk-test.cloud.sensorsdata.cn:8006/sa?project=default&token=95c73ae661f85aa0", launchOptions: launchOptions)
        options.maxCacheSize = 10000;
        options.autoTrackEventType = [.eventTypeAppClick,.eventTypeAppStart,.eventTypeAppEnd,.eventTypeAppViewScreen]
        options.enableVisualizedAutoTrack = true
        options.enableHeatMap = true
        options.enableTrackAppCrash = true
        SensorsAnalyticsSDK.start(configOptions: options)

        SensorsAnalyticsSDK.sharedInstance()?.setFlushNetworkPolicy(SensorsAnalyticsNetworkType.typeALL)

        let dict: Dictionary = ["key": "value", "key1": "value1"]
        SensorsAnalyticsSDK.sharedInstance()?.track("testEvent", withProperties: dict)
        SensorsAnalyticsSDK.sharedInstance()?.enableTrackScreenOrientation(true)

        window = UIWindow()
        let rootVC: UIViewController = ViewController()
        window?.rootViewController = UINavigationController(rootViewController: rootVC)
        window?.makeKeyAndVisible()

        return true
    }
}

