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

import ClockKit

final class ComplicationController: NSObject, CLKComplicationDataSource {
  
  // MARK: Register
  func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {
    if complication.family == .UtilitarianSmall {
      let smallFlat = CLKComplicationTemplateUtilitarianSmallFlat()
      smallFlat.textProvider = CLKSimpleTextProvider(text: "+2.6m")
      smallFlat.imageProvider = nil // CLKImageProvider(backgroundImage: UIImage(named: "tide_high")!, backgroundColor: nil)
      
      handler(smallFlat)
    }
    else if complication.family == .UtilitarianLarge {
      let largeFlat = CLKComplicationTemplateUtilitarianLargeFlat()
      largeFlat.textProvider = CLKSimpleTextProvider(text: "Rising, +2.6m", shortText:"+2.6m")
      largeFlat.imageProvider = nil // CLKImageProvider(backgroundImage: UIImage(named: "tide_high")!, backgroundColor: nil)
      
      handler(largeFlat)
    }
  }
  
  // MARK: Provide Data
  func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimelineEntry?) -> Void) {
    let tideConditions = TideConditions.loadConditions()
    
    guard let waterLevel = tideConditions.currentWaterLevel else {
      // No data is cached yet
      handler(nil)
      return
    }
    
    handler(timelineEntryFor(waterLevel, family: complication.family))
    saveDisplayedStation(tideConditions.station)
  }
  
  // MARK: Time Travel
  func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
    handler([.Forward, .Backward])
  }

  // MARK: Template Creation
  func timelineEntryFor(waterLevel: WaterLevel, family: CLKComplicationFamily) -> CLKComplicationTimelineEntry? {
    let tideImageName: String
    switch waterLevel.situation {
    case .High: tideImageName = "tide_high"
    case .Low: tideImageName = "tide_low"
    case .Rising: tideImageName = "tide_rising"
    case .Falling: tideImageName = "tide_falling"
    default: tideImageName = "tide_high"
    }
    
    if family == .UtilitarianSmall {
      let smallFlat = CLKComplicationTemplateUtilitarianSmallFlat()
      smallFlat.textProvider = CLKSimpleTextProvider(text: waterLevel.shortTextForComplication)
      smallFlat.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: tideImageName)!)
      return CLKComplicationTimelineEntry(date: waterLevel.date, complicationTemplate: smallFlat, timelineAnimationGroup: waterLevel.situation.rawValue)
    } else if family == .UtilitarianLarge{
      let largeFlat = CLKComplicationTemplateUtilitarianLargeFlat()
      largeFlat.textProvider = CLKSimpleTextProvider(text: waterLevel.longTextForComplication, shortText:waterLevel.shortTextForComplication)
      largeFlat.imageProvider = CLKImageProvider(onePieceImage: UIImage(named: tideImageName)!)
      return CLKComplicationTimelineEntry(date: waterLevel.date, complicationTemplate: largeFlat, timelineAnimationGroup: waterLevel.situation.rawValue)
    }
    return nil
  }
}

// MARK: Displayed Data
extension ComplicationController {
  private func loadDisplayedStation() -> MeasurementStation? {
    if let data = NSData(contentsOfFile: storePath) {
      let station = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! MeasurementStation
      return station
    }
    return nil
  }
  
  private func saveDisplayedStation(displayedStation: MeasurementStation) {
    NSKeyedArchiver.archiveRootObject(displayedStation, toFile: storePath)
  }
  
  private var storePath: String {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let docPath = paths.first!
    return (docPath as NSString).stringByAppendingPathComponent("CurrentStation")
  }
  
  func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
    
    let tideConditions = TideConditions.loadConditions()
    guard let waterLevel = tideConditions.waterLevels.first else {
      //
      handler(nil)
      return
    }
    handler(waterLevel.date)
  }
  
  func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
    
    let tideConditions = TideConditions.loadConditions()
    guard let waterLevel = tideConditions.waterLevels.last else {
      //
      handler(nil)
      return
    }
    handler(waterLevel.date)
  }
  
  func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: ([CLKComplicationTimelineEntry]?) -> Void) {
    
    let tideConditions = TideConditions.loadConditions()
    
    var waterLevels = tideConditions.waterLevels.filter {
      $0.date.compare(date) == .OrderedAscending
    }
    
    if waterLevels.count > limit {
      let numberToRemove = waterLevels.count - limit
      waterLevels.removeRange(0..<numberToRemove)
    }
    
    let entries = waterLevels.flatMap { waterLevel in
      return timelineEntryFor(waterLevel, family: complication.family)
  }
    handler(entries)
  }
  
  func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: ([CLKComplicationTimelineEntry]?) -> Void) {
    
    let tideConditions = TideConditions.loadConditions()
    
    var waterLevels = tideConditions.waterLevels.filter {
      $0.date.compare(date) == .OrderedDescending
    }
    
    if waterLevels.count > limit {
      waterLevels.removeRange(limit..<waterLevels.count)
    }
    
    let entries = waterLevels.flatMap { waterLevel in
      return timelineEntryFor(waterLevel, family: complication.family)
    }
    handler(entries)
  }

  func getTimelineAnimationBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimelineAnimationBehavior) -> Void) {
    
    handler(.Grouped)
  }
  
  func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
    
    let tideConditions = TideConditions.loadConditions()
    if let waterLevel = tideConditions.waterLevels.last {
      handler(waterLevel.date)
    } else {
      handler(NSDate())
    }
  }
  
  func reloadOrExtendData() {
    
    let server = CLKComplicationServer.sharedInstance()
    guard let complications = server.activeComplications
      where complications.count > 0 else { return }
    
    let tideConditions = TideConditions.loadConditions()
    let displayedStation = loadDisplayedStation()
    
    if let id = displayedStation?.id
      where id == tideConditions.station.id {
      
      if tideConditions.waterLevels.last?.date.compare(server.latestTimeTravelDate) == .OrderedDescending {
        for complication in complications {
          server.extendTimelineForComplication(complication)
        }
      }
    } else {
      for complication in complications {
        server.reloadTimelineForComplication(complication)
      }
    }
    saveDisplayedStation(tideConditions.station)
  }
  
  func refreshData() {
    
    let tideConditions = TideConditions.loadConditions()
    let yesterday = NSDate(timeIntervalSinceNow: -24 * 60 * 60)
    let tomorrow = NSDate(timeIntervalSinceNow: 24 * 60 * 60)
    tideConditions.loadWaterLevels(from: yesterday, to: tomorrow) { success in
      if success {
        TideConditions.saveConditions(tideConditions)
          self.reloadOrExtendData()
      }
    }
  }
  
  func requestedUpdateDidBegin() {
    refreshData()
  }
  
  func requestedUpdateBudgetExhausted() {
    refreshData()
  }
  
  func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
    
    handler(.HideOnLockScreen)
  }
}