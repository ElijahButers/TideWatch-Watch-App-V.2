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

class MainInterfaceController: WKInterfaceController {
  @IBOutlet var nameLabel: WKInterfaceLabel!
  @IBOutlet var stateLabel: WKInterfaceLabel!
  @IBOutlet var waterLevelLabel: WKInterfaceLabel!
  @IBOutlet var averageWaterLevelLabel: WKInterfaceLabel!
  @IBOutlet var tideLabel: WKInterfaceLabel!
  
  var tideConditions: TideConditions = TideConditions.loadConditions()
  
  override func awakeWithContext(context: AnyObject?) {
    super.awakeWithContext(context)
  }
  
  override func willActivate() {
    super.willActivate()
    populateStationData()
    refresh()
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserverForName(PhoneUpdatedDataNotification, object: nil, queue: nil) { notification in
      if let conditions = notification.object as? TideConditions {
        self.tideConditions = conditions;
        dispatch_async(dispatch_get_main_queue()) {
          self.populateStationData()
          self.populateTideData()
        }
      }
    }
  }
  
  override func didDeactivate() {
    super.didDeactivate()
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.removeObserver(self)
  }
  
  override func contextForSegueWithIdentifier(segueIdentifier: String) -> AnyObject? {
    return tideConditions
  }
}

// MARK: Load Data
extension MainInterfaceController {
  func refresh() {
    let yesterday = NSDate(timeIntervalSinceNow: -24 * 60 * 60)
    let tomorrow = NSDate(timeIntervalSinceNow: 24 * 60 * 60)
    tideConditions.loadWaterLevels(from: yesterday, to: tomorrow) { success in
      dispatch_async(dispatch_get_main_queue()) {
        if success {
          self.populateTideData()
          TideConditions.saveConditions(self.tideConditions)
          let notificationCenter = NSNotificationCenter.defaultCenter()
          notificationCenter.postNotificationName(WatchUpdatedDataNotification, object: self.tideConditions)
        }
        else {
          print("Failed to load station: \(self.tideConditions.station.name)")
        }
      }
    }
  }
  
  func populateStationData() {
    nameLabel.setText(tideConditions.station.name)
    stateLabel.setText(tideConditions.station.state)
    waterLevelLabel.setText("--")
    tideLabel.setText("--")
    averageWaterLevelLabel.setText("--")
  }
  
  func populateTideData() {
    guard tideConditions.waterLevels.count > 0 else {
      return
    }
    
    if let currentWaterLevel = tideConditions.currentWaterLevel {
      waterLevelLabel.setText(String(format: "%.1fm", currentWaterLevel.height))
      tideLabel.setText(currentWaterLevel.situation.rawValue)
    }
    averageWaterLevelLabel.setText(String(format: "%.1fm", tideConditions.averageWaterLevel))
  }
}
