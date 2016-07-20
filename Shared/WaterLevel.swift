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

@objc(WaterLevel)
final class WaterLevel: NSObject {
  private static let dateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    return dateFormatter
    }()
  
  let date: NSDate
  let height: Double
  
  // Calculated by TideConditions
  var situation: TideConditions.TideSituation
  
  init(date: NSDate, height: Double) {
    self.date = date
    self.height = height
    self.situation = .Unknown
    super.init()
  }
  
  convenience init?(json: [String: AnyObject]) {
    guard let dateString = json["t"] as? String, heightString = json["v"] as? String else {
      return nil
    }
    
    guard let date = WaterLevel.dateFormatter.dateFromString(dateString), let height = Double(heightString) else {
      return nil
    }
    self.init(date: date, height: height)
  }
  
  override var description: String {
    return "WaterLevel: \(height)"
  }
}

// MARK: For Complication
extension WaterLevel {
  var shortTextForComplication: String {
    return String(format: "%.1fm", self.height)
  }
  
  var longTextForComplication: String {
    return String(format: "%@, %.1fm",self.situation.rawValue, self.height)
  }
}

// MARK: NSCoding
extension WaterLevel: NSCoding {
  private struct CodingKeys {
    static let date = "date"
    static let height = "height"
    static let situation = "situation"
  }
  
  convenience init(coder aDecoder: NSCoder) {
    let date = aDecoder.decodeObjectForKey(CodingKeys.date) as! NSDate
    let height = aDecoder.decodeDoubleForKey(CodingKeys.height)
    self.init(date: date, height: height)
    
    self.situation = TideConditions.TideSituation(rawValue: aDecoder.decodeObjectForKey(CodingKeys.situation) as! String)!
  }
  
  func encodeWithCoder(encoder: NSCoder) {
    encoder.encodeObject(date, forKey: CodingKeys.date)
    encoder.encodeDouble(height, forKey: CodingKeys.height)
    encoder.encodeObject(situation.rawValue, forKey: CodingKeys.situation)
  }
}
