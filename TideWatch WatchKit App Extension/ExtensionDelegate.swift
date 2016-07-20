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

import WatchKit
import WatchConnectivity

let WatchUpdatedDataNotification = "WatchUpdatedDataNotification"
let PhoneUpdatedDataNotification = "PhoneUpdatedDataNotification"

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
  
  func applicationDidFinishLaunching() {
    setupWatchConnectivity()
    setupNotificationCenter()
  }
  
  // MARK: - Notification Center
  
  private func setupNotificationCenter() {
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserverForName(WatchUpdatedDataNotification, object: nil, queue: nil) { notification in
      self.sendUpdatedDataToPhone(notification)
    }
  }
  
  
  private func sendUpdatedDataToPhone(notification: NSNotification) {
    if WCSession.isSupported() {
      let session = WCSession.defaultSession()
      if let object = notification.object as? TideConditions {
        do {
          let data = NSKeyedArchiver.archivedDataWithRootObject(object)
          let dictonary = ["data": data]
          try session.updateApplicationContext(dictonary)
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
        conditionsUpdated(tideConditions)
      }
    }
  }
    
  func conditionsUpdated(tideConditions:TideConditions) {
    TideConditions.saveConditions(tideConditions)
    dispatch_async(dispatch_get_main_queue()) {
      let notificationCenter = NSNotificationCenter.defaultCenter()
      notificationCenter.postNotificationName(PhoneUpdatedDataNotification, object: tideConditions)
    }
  }
}
