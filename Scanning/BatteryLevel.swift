//
//  BatteryLevel.swift
//  ButtonPractice
//
//  Created by Ｍ200_Macbook_Pro on 2018/9/7.
//  Copyright © 2018 ITRI. All rights reserved.
//

import UIKit

@IBDesignable
class BatteryLevel: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    var level: CGFloat = 1.0 { didSet { setNeedsDisplay() } }
    let batteryColor = UIColor.white
    
    override func draw(_ rect: CGRect) {
        drawBatteryLevel()
    }

    func drawBatteryLevel() {
        // set black background
        let rect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height*(1.0-level) )
        let batteryLevel = UIBezierPath(rect: rect)
        batteryColor.setFill()
        batteryLevel.fill()
    }
    
}
