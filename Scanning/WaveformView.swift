//
//  WaveformView.swift
//  ReadCharacteristic
//
//  Created by HengJay on 2018/1/19.
//  Copyright © 2018 ITRI All rights reserved.
//

import UIKit

@IBDesignable
class WaveformView: UIView {

    private struct Parameters {
        static let backgroundOutlineWidth: CGFloat = 6.0
        static let middleSeperateLineWidth: CGFloat = 1.5
        static let signalLineWidth: CGFloat = 4.0
    }

    var signal1Min: CGFloat = 0
    var signal1Max: CGFloat = 0

    var signal1Data = [CGFloat](repeating: CGFloat(UINT16_MAX >> 1), count: 2500) {
        didSet {
            if (signal1Index + 1) % 250 == 0 { setNeedsDisplay() }
        }
    }

    var signal1Index: Int = 0
    
    var signal2Min: CGFloat = 0
    var signal2Max: CGFloat = 0

    var signal2Data = [CGFloat](repeating: CGFloat(UINT16_MAX >> 1), count: 2500) {
        didSet {
            if (signal2Index + 1) % 250 == 0 { setNeedsDisplay() }
        }
    }

    var signal2Index: Int = 0

    override func draw(_ rect: CGRect) {
        // Drawing code
        drawWaveformBackground(rect: rect)

        drawSignal(rect: rect)
    }

    func drawWaveformBackground (rect: CGRect) {
        // set black background
        let background = UIBezierPath(rect: rect)
        UIColor.black.setFill()
        background.fill()

        // draw gray middle seperate line
        let seperateLine = UIBezierPath()
        //set the path's line width to the height of the stroke
        seperateLine.lineWidth = Parameters.middleSeperateLineWidth

        // move the initial point of the path
        // to the start of the horizontal stroke
        seperateLine.move(to: CGPoint(x: 0, y: bounds.height / 2))

        // add a point to the path at the end of the stroke
        seperateLine.addLine(to: CGPoint(x: bounds.width, y: bounds.height / 2))
        UIColor.gray.setStroke()
        seperateLine.stroke()

        // draw outline of waveform area
        let outline = UIBezierPath(rect: rect)
        outline.lineWidth = Parameters.backgroundOutlineWidth
        UIColor.green.setStroke()
        outline.stroke()

    }

    func drawSignal (rect: CGRect) {

        let graphWidth: CGFloat = 0.9  // Graph is 90% of the width of the view
        let width = bounds.width
        let height = bounds.height
        let stepX = (width * graphWidth) / CGFloat(signal1Data.count - 1)

        //draw waveform of signalECG
        let origin = CGPoint(x: width * (1 - graphWidth) / 2, y: height * 0.45 )

        let signal1 = UIBezierPath()
        signal1.lineWidth = 1.5
        let ch1Min = signal1Data.min()!
        let ch1Scale = (signal1Data.max()! - ch1Min + 1)
        signal1Min = ch1Min
        signal1Max = ch1Scale + ch1Min - 1

        signal1.move(to: CGPoint(x: origin.x,
                                 y: origin.y - height * 0.4 * (signal1Data[0] - ch1Min) / ch1Scale))

        for i in 1...signal1Data.count-1 {
            signal1.addLine(to: CGPoint(x: origin.x + stepX * CGFloat(i),
                                        y: origin.y - height * 0.4 * (signal1Data[i] - ch1Min) / ch1Scale))
        }
        UIColor.cyan.setStroke()
        signal1.stroke()

        //draw waveform of signalPPG
        let origin2 = CGPoint(x: width * (1 - graphWidth) / 2, y: height * 0.95 )
        let signal2 = UIBezierPath()
        signal2.lineWidth = 1.5
        let ch2Min = signal2Data.min()!
        let ch2Scale = (signal2Data.max()! - ch2Min + 1)
        signal2Min = ch2Min
        signal2Max = ch2Scale + ch2Min - 1
        
        signal2.move(to: CGPoint(x: origin2.x,
                                 y: origin2.y - height * 0.4 * (signal2Data[0] - ch2Min) / ch2Scale))

        for i in 1...signal2Data.count-1 {
            signal2.addLine(to: CGPoint(x: origin2.x + stepX * CGFloat(i),
                                        y: origin2.y - height * 0.4 * (signal2Data[i] - ch2Min) / ch2Scale))
        }
        UIColor.red.setStroke()
        signal2.stroke()

    }

    func pushSignal1 (newValue: CGFloat) {
        signal1Data.append(newValue)
        signal1Data.removeFirst()
    }

    func pushSignal1BySliding (newValue: CGFloat) {
        signal1Data[signal1Index] = newValue
        signal1Index = (signal1Index == signal1Data.count - 1) ? 0 : (signal1Index + 1)
    }

    func pushSignal2 (newValue: CGFloat) {
        signal2Data.append(newValue)
        signal2Data.removeFirst()
    }

    func pushSignal2BySliding (newValue: CGFloat) {
        signal2Data[signal2Index] = newValue
        signal2Index = (signal2Index == signal2Data.count - 1) ? 0 : (signal2Index + 1)
    }

}
