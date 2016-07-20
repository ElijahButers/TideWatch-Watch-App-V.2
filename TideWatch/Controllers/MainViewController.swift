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

class MainViewController: UIViewController {
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  @IBOutlet weak var stationNameLabel: UILabel!
  @IBOutlet weak var stationStateLabel: UILabel!
  
  @IBOutlet weak var currentWaterLevelLabel: UILabel!
  @IBOutlet weak var averageWaterLevelLabel: UILabel!
  @IBOutlet weak var tideLabel: UILabel!
  
  @IBOutlet weak var chartView: LineChart!
  @IBOutlet weak var selectedValueLabel: UILabel!
  
  var tideConditions: TideConditions = TideConditions.loadConditions()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    var xLabels = [String](count: 50, repeatedValue: "")
    xLabels[0] = "-24h"
    xLabels[47] = "+24h"
    xLabels[23] = "Now"
    chartView.x.labels.values = xLabels
    chartView.area = false
    chartView.delegate = self
    
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserverForName(WatchUpdatedDataNotification, object: nil, queue: nil) { notification in
      if let conditions = notification.userInfo?["conditions"] as? TideConditions {
        self.tideConditions = conditions;
        dispatch_async(dispatch_get_main_queue()) {
          self.populateData()
        }
      }
    }
    populateData()
    refresh(false)
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let dest = segue.destinationViewController as? StationsViewController {
      dest.delegate = self
    }
  }
}

// MARK: Load Data
extension MainViewController {
  func refresh(newStation: Bool) {
    activityIndicator.startAnimating()
    let yesterday = NSDate(timeIntervalSinceNow: -24 * 60 * 60)
    let tomorrow = NSDate(timeIntervalSinceNow: 24 * 60 * 60)
    tideConditions.loadWaterLevels(from: yesterday, to: tomorrow) { success in
      dispatch_async(dispatch_get_main_queue()) {
        self.activityIndicator.stopAnimating()
        if success {
          self.populateData()
          TideConditions.saveConditions(self.tideConditions)
          let notificationCenter = NSNotificationCenter.defaultCenter()
          notificationCenter.postNotificationName(PhoneUpdatedDataNotification, object: self, userInfo:
            ["conditions": self.tideConditions,
              "newStation": NSNumber(bool: newStation)
            ])
        }
        else {
          print("Failed to load station: \(self.tideConditions.station.name)")
        }
      }
    }
  }
  
  func populateData() {
    stationNameLabel.text = tideConditions.station.name
    stationStateLabel.text = tideConditions.station.state
    
    chartView.clearAll()
    selectedValueLabel.text = "Select a point"
    
    guard tideConditions.waterLevels.count > 0 else {
      return
    }
    
    if let currentWaterLevel = tideConditions.currentWaterLevel {
      currentWaterLevelLabel.text = String(format: "%.1fm", currentWaterLevel.height)
      tideLabel.text = currentWaterLevel.situation.rawValue
    }
    averageWaterLevelLabel.text = String(format: "%.1fm", tideConditions.averageWaterLevel)
    
    let levels = tideConditions.waterLevels.map { CGFloat($0.height) }
    chartView.addLine(levels)
    chartView.setNeedsDisplay()
  }
}

// MARK: StationsViewControllerDelegate
extension MainViewController: StationsViewControllerDelegate {
  func selectedStation(station: MeasurementStation) {
    navigationController?.popViewControllerAnimated(true)
    guard station.name != tideConditions.station.name else { return }
    tideConditions = TideConditions(station: station)
    refresh(true)
  }
}

// MARK: LineChartDelegate
extension MainViewController: LineChartDelegate {
  func didSelectDataPoint(x: CGFloat, yValues: [CGFloat]) {
    if yValues.count > 0 {
      let y = yValues[0]
      selectedValueLabel.text = String(format: "%.1fm", y)
    }
    else {
      selectedValueLabel.text = "Select a point"
    }
  }
}
