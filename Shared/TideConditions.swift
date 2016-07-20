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

@objc(TideConditions)
final class TideConditions: NSObject {
  private static let dateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    return dateFormatter
    }()
  
  var station: MeasurementStation
  var waterLevels: [WaterLevel] = []
  var averageWaterLevel: Double = 0
  
  var currentWaterLevel: WaterLevel? {
    guard waterLevels.count > 0 else { return nil }
    let currentDate = NSDate()
    for waterLevel in waterLevels {
      if waterLevel.date.compare(currentDate) != .OrderedAscending {
        return waterLevel
      }
    }
    return nil
  }
  
  init(station: MeasurementStation) {
    self.station = station
    super.init()
  }
}

// MARK: Tide Situations
extension TideConditions {
  enum TideSituation: String {
    case High, Low, Rising, Falling, Unknown
  }
  
  func computeTideSituations() {
    let totalWaterLevel = self.waterLevels.reduce(0.0) { (result, waterLevel) -> Double in
      return result + waterLevel.height
    }
    averageWaterLevel = totalWaterLevel / Double(waterLevels.count)
    
    for (i, value) in waterLevels.enumerate() {
      let height = value.height
      if i == 0 { // First data point
        let nextHeight = waterLevels[i+1].height
        value.situation = height > nextHeight ? .Falling : .Rising
        continue
      } else if i == waterLevels.count-1 { // Last data point
        let prevHeight = waterLevels[i-1].height
        value.situation = prevHeight > height ? .Falling : .Rising
        continue
      }
      let prevHeight = waterLevels[i-1].height
      let nextHeight = waterLevels[i+1].height
      
      if height > prevHeight && height > nextHeight {
        value.situation = .High
      } else if height < prevHeight && height < nextHeight {
        value.situation = .Low
      } else if height < nextHeight {
        value.situation = .Rising
      } else {
        value.situation = .Falling
      }
    }
  }
}

// MARK: CO-OPS API
// http://tidesandcurrents.noaa.gov/api/
extension TideConditions {
  func loadWaterLevels(from fromDate: NSDate, to toDate: NSDate, completion:(success: Bool)->()) {
    var params = [
      "product": "predictions",
      "units": "metric",
      "time_zone": "gmt",
      "application": "TideWatch",
      "format": "json",
      "datum": "mllw",
      "interval": "h",
      "station": station.id
    ]
    
    params["begin_date"] = TideConditions.dateFormatter.stringFromDate(fromDate)
    params["end_date"] = TideConditions.dateFormatter.stringFromDate(toDate)
    
    let paramString = params.map({ "\($0.0)=\($0.1)" }).joinWithSeparator("&")
    let requestEndpoint = "http://tidesandcurrents.noaa.gov/api/datagetter"
    
    let urlString = [requestEndpoint, paramString].joinWithSeparator("?")
    
    let url = NSURL(string: urlString)!
    let task = NSURLSession.sharedSession().dataTaskWithURL(url) { data, _, _ in
      guard let data = data else {
        completion(success: false)
        return
      }
      
      guard let json = try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? [String: AnyObject] else {
        completion(success: false)
        return
      }
      
      guard let jsonWaterLevels = json["predictions"] as? [[String: AnyObject]] else {
        completion(success: false)
        return
      }
      
      let allWaterLevels = jsonWaterLevels.map { json in
        WaterLevel(json: json)!
      }
      
      // Filter out so we only have -24h to 24h data points
      self.waterLevels = allWaterLevels.filter { waterLevel -> Bool in
        return waterLevel.date.compare(fromDate) == NSComparisonResult.OrderedDescending &&
          waterLevel.date.compare(toDate) == NSComparisonResult.OrderedAscending
      }
      
      self.computeTideSituations()
      
      completion(success: true)
      
    }
    task.resume()
  }
}

// MARK: Persistance
extension TideConditions {
  private static var storePath: String {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let docPath = paths.first!
    return (docPath as NSString).stringByAppendingPathComponent("TideConditions")
  }
  
  static func loadConditions() -> TideConditions {
    if let data = NSData(contentsOfFile: storePath) {
      let savedConditions = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! TideConditions
      return savedConditions
    } else {
      // Default
      let station = MeasurementStation.allStations()[0];
      return TideConditions(station: station)
    }
  }
  
  static func saveConditions(tideConditions:TideConditions) {
    NSKeyedArchiver.archiveRootObject(tideConditions, toFile: storePath)
  }
}

// MARK: NSCoding
extension TideConditions: NSCoding {
  private struct CodingKeys {
    static let station = "station"
    static let waterLevels = "waterLevels"
    static let averageWaterLevel = "averageWaterLevel"
  }
  
  convenience init(coder aDecoder: NSCoder) {
    let station = aDecoder.decodeObjectForKey(CodingKeys.station) as! MeasurementStation
    self.init(station: station)
    
    self.waterLevels = aDecoder.decodeObjectForKey(CodingKeys.waterLevels) as! [WaterLevel]
    self.averageWaterLevel = aDecoder.decodeDoubleForKey(CodingKeys.averageWaterLevel)
  }
  
  func encodeWithCoder(encoder: NSCoder) {
    encoder.encodeObject(station, forKey: CodingKeys.station)
    encoder.encodeObject(waterLevels, forKey: CodingKeys.waterLevels)
    encoder.encodeDouble(averageWaterLevel, forKey: CodingKeys.averageWaterLevel)
  }
}
