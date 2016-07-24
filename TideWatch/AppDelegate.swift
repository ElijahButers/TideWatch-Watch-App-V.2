/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import WatchConnectivity

let PhoneUpdatedDataNotification = "PhoneUpdatedDataNotification"
let WatchUpdatedDataNotification = "WatchUpdatedDataNotification"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
  
  var window: UIWindow?
  
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Override point for customization after application launch.
    setupWatchConnectivity()
    setupNotificationCenter()
    return true
  }
  
  // MARK: - Notification Center
  private func setupNotificationCenter() {
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserverForName(PhoneUpdatedDataNotification, object: nil, queue: nil) { notification in
      self.sendUpdatedDataToWatch(notification)
    }
  }
  
  private func sendUpdatedDataToWatch(notification: NSNotification) {
    if WCSession.isSupported() {
      let session = WCSession.defaultSession()
      if session.watchAppInstalled,
        let conditions = notification.userInfo?["conditions"] as? TideConditions,
        let isNewStation = notification.userInfo?["newStation"]?.boolValue
      {
        do {
          let data = NSKeyedArchiver.archivedDataWithRootObject(conditions)
          let dictionary = ["data": data]
          // Transferr complication info
          if isNewStation {
            session.transferCurrentComplicationUserInfo(dictionary)
          } else {
            try session.updateApplicationContext(dictionary)
          }
        } catch {
          print("ERROR: \(error)")
        }
      }
    }
  }
  
  // MARK: - Watch Connectivity
  private func setupWatchConnectivity() {
    if WCSession.isSupported() {
      let session = WCSession.defaultSession()
      session.delegate = self
      session.activateSession()
    }
  }
  
  func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
    if let data = applicationContext["data"] as? NSData {
      if let tideConditions = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? TideConditions {
        TideConditions.saveConditions(tideConditions)
        dispatch_async(dispatch_get_main_queue()) {
          let notificationCenter = NSNotificationCenter.defaultCenter()
          notificationCenter.postNotificationName(WatchUpdatedDataNotification, object: self, userInfo:["conditions":tideConditions])
        }
      }
    }
  }
}

