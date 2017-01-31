//
//  MWOverlay.swift
//  MWBarcodeCameraDemo
//
//  Created by vladimir zivkovic on 7/25/14.
//  Copyright (c) 2014 Manateeworks. All rights reserved.
//

import Foundation
import AVFoundation
import CoreGraphics
import QuartzCore
import UIKit


let CHANGE_TRACKING_INTERVAL = 0.1

var viewportLayer: CALayer!
var lineLayer: CALayer!
var locationLayer: CALayer!

var previewLayer: AVCaptureVideoPreviewLayer!
var isAttached: Bool = false
var isViewportVisible: Bool = true
var isBlinkingLineVisible: Bool = true


var instance:MWOverlay! = nil;

var viewportLineWidth:Float = 3.0;
var blinkingLineWidth:Float = 1.0;
let locationLineWidth:CGFloat = 4.0
var viewportAlpha:Float = 0.5;
var viewportLineAlpha:Float = 0.5;
var blinkingLineAlpha:Float = 1.0;
var blinkingSpeed:Float = 0.25;
var viewportLineColor:Int = 0xff0000;
var blinkingLineColor:Int = 0xff0000;
let locationLineColor:Int = 0x00ff00;

var lastOrientation:Int = -1;
var lastMask:Int = -1;
var lastLeft:Float = -1;
var lastTop:Float = -1;
var lastWidth:Float = -1;
var lastHeight:Float = -1;
var imageWidth = 1
var imageHeight = 1

class MWOverlay:NSObject {
    
    
    override init(){
        
    }
    class func updatePreviewLayer() {
        viewportLayer.frame = CGRect(x: 0, y: 0, width: previewLayer.frame.size.width, height: previewLayer.frame.size.height)
        lineLayer.frame = CGRect(x: 0, y: 0, width: previewLayer.frame.size.width, height: previewLayer.frame.size.height)
        locationLayer.frame = CGRect(x: 0, y: 0, width: previewLayer.frame.size.width, height: previewLayer.frame.size.height)
        MWOverlay.updateOverlay()
    }
    
    class func addToPreviewLayer(_ videoPreviewLayer: AVCaptureVideoPreviewLayer )
    {
        viewportLayer = CALayer();
        viewportLayer.frame = CGRect(x: 0, y: 0, width: videoPreviewLayer.frame.size.width, height: videoPreviewLayer.frame.size.height);
        
        
        lineLayer = CALayer();
        lineLayer.frame = CGRect(x: 0, y: 0, width: videoPreviewLayer.frame.size.width, height: videoPreviewLayer.frame.size.height);
        

        locationLayer = CALayer()
        locationLayer.frame = CGRect(x: 0, y: 0, width: videoPreviewLayer.frame.size.width, height: videoPreviewLayer.frame.size.height)
        
        
        videoPreviewLayer.addSublayer(viewportLayer);
        videoPreviewLayer.addSublayer(lineLayer);
        
        previewLayer = videoPreviewLayer;
        
        isAttached = true;
        
        instance = MWOverlay();
        
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Double(CHANGE_TRACKING_INTERVAL) * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)){
            MWOverlay.checkForChanges();
        }
        
        MWOverlay.updateOverlay();
        
    }
    
    class func removeFromPreviewLayer() {
        
        if (!isAttached){
            return;
        }
        
        if ((previewLayer) != nil){
            if ((lineLayer) != nil){
                lineLayer.removeFromSuperlayer();
            }
            if ((viewportLayer) != nil){
                viewportLayer.removeFromSuperlayer();
            }
            if locationLayer != nil {
                locationLayer.removeFromSuperlayer()
            }
        }
        
        isAttached = false;
        
    }
    
    class func checkForChanges() {
        
        if isAttached{
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Double(CHANGE_TRACKING_INTERVAL) * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)){
                MWOverlay.checkForChanges();
            }
        } else {
            return;
        }
        
        var left: Float = 0
        var top:Float = 0
        var width:Float = 0
        var height:Float = 0
        
        let res = MWB_getScanningRect(0, &left, &top, &width, &height);
        
        if (res == 0){
            
            let orientation = MWB_getDirection();
            
            if (Int(orientation) != lastOrientation || left != lastLeft || top != lastTop || width != lastWidth || height != lastHeight) {
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(Double(CHANGE_TRACKING_INTERVAL) * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)){
                    MWOverlay.updateOverlay();
                }
                
            }
            
            lastOrientation = Int(orientation);
            lastLeft = left;
            lastTop = top;
            lastWidth = width;
            lastHeight = height;
            
        }
        
        
    }
    
    class func updateOverlay(){
        
        if (!isAttached || (previewLayer == nil) ){
            return;
        }
        
        var yScale:Float = 1.0;
        var yOffset:Float = 0.0;
        var xScale:Float = 1.0;
        var xOffset:Float = 0.0;
        
        //aspect ratio correction available only on ios 6+
       if previewLayer.responds(to: #selector(AVCaptureVideoPreviewLayer.captureDevicePointOfInterest(for:))){

            let p1 = previewLayer.captureDevicePointOfInterest(for: CGPoint(x: 0,y: 0));
            
            yScale = 1.0/(1.0 + (Float(p1.y) - 1.0)*2.0);
            yOffset = (1.0 - yScale) / 2.0 * 100;
            
            xScale = 1.0/(1 + (Float(p1.x) - 1)*2);
            xOffset = (1.0 - xScale) / 2.0 * 100;
            
        
            if (previewLayer.connection.videoOrientation == AVCaptureVideoOrientation.portrait || previewLayer.connection.videoOrientation == AVCaptureVideoOrientation.portraitUpsideDown){
                
                yScale = 1.0/(1 + (Float(p1.x) - 1)*2);
                yOffset = (1.0 - yScale) / 2.0 * 100;
                
                xScale = 1.0/(1 + (Float(p1.y) - 1)*2);
                xOffset = (1.0 - xScale) / 2.0 * 100;
                
            }
        }
        
        
        viewportLayer.isHidden = !isViewportVisible;
        lineLayer.isHidden = !isBlinkingLineVisible;
        
        
        let overlayWidth = viewportLayer.frame.size.width;
        let overlayHeight = viewportLayer.frame.size.height;
        
        let cgRect = viewportLayer.frame;
        
        
        UIGraphicsBeginImageContext(cgRect.size);
        let context = UIGraphicsGetCurrentContext();
        UIGraphicsPushContext(context!);
        
        
        var left: Float = 0
        var top:Float = 0
        var width:Float = 0
        var height:Float = 0
        
        MWB_getScanningRect(0, &left, &top, &width, &height);
        
        if (previewLayer.connection.videoOrientation == AVCaptureVideoOrientation.portrait || previewLayer.connection.videoOrientation == AVCaptureVideoOrientation.portraitUpsideDown){
            
            var tmp:Float = left;
            left = top;
            top = tmp;
            tmp = height;
            height = width;
            width = tmp;
            
        }
        
        
        var rect = CGRect(x: CGFloat(xOffset + left * xScale), y: CGFloat(yOffset + top * yScale), width: CGFloat(width * xScale), height: CGFloat(height * yScale));
        
        rect.origin.x *= overlayWidth;
        rect.origin.x /= 100.0;
        rect.origin.y *= overlayHeight;
        rect.origin.y /= 100.0;
        rect.size.width *= overlayWidth;
        rect.size.width /= 100.0;
        rect.size.height *= overlayHeight;
        rect.size.height /= 100.0;
        
        context?.setFillColor(red: 0, green: 0, blue: 0, alpha: CGFloat(viewportAlpha));
        context?.fill(CGRect(x: 0,y: 0,width: overlayWidth,height: overlayHeight));
        context?.clear(rect);
        
        var r:Float = Float(viewportLineColor >> 16) / 255.0;
        var g:Float = Float((viewportLineColor & 0x00ff00) >> 8) / 255.0;
        var b:Float = Float(viewportLineColor & 0x0000ff) / 255.0;
        
        
        context?.setStrokeColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 0.5);
        context?.stroke(rect, width: CGFloat(viewportLineWidth));
        
        UIGraphicsPopContext();
        
        viewportLayer.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage;
        
        
        
        context?.clear(cgRect);
        
        r = Float(blinkingLineColor >> 16) / 255.0;
        g = Float((blinkingLineColor & 0x00ff00) >> 8) / 255.0;
        b = Float(blinkingLineColor & 0x0000ff) / 255.0;
        
        context?.setStrokeColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1);
        
        var orientation = MWB_getDirection();
        
        if (previewLayer.connection.videoOrientation == AVCaptureVideoOrientation.portrait || previewLayer.connection.videoOrientation == AVCaptureVideoOrientation.portraitUpsideDown){
            
            let pos1f = log(Float(MWB_SCANDIRECTION_HORIZONTAL)) / log(2);
            let pos2f = log(Float(MWB_SCANDIRECTION_VERTICAL)) / log(2);
            
            let pos1 = Int32(pos1f + 0.01);
            let pos2 = Int32(pos2f + 0.01);
            
            let bit1 = (orientation >> pos1) & 1;// bit at pos1
            let bit2 = (orientation >> pos2) & 1;// bit at pos2
            let mask = (bit2 << pos1) | (bit1 << pos2);
            orientation = orientation & 0xc;
            orientation = orientation | mask;
            
        }
        
       
        
        if ((UInt32(orientation) & MWB_SCANDIRECTION_HORIZONTAL > 0) || (UInt32(orientation) & MWB_SCANDIRECTION_OMNI > 0) || (UInt32(orientation) & MWB_SCANDIRECTION_AUTODETECT > 0)){
            context?.setLineWidth(CGFloat(blinkingLineWidth));
            context?.move(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.size.height / 2))
            context?.addLine(to: CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y + rect.size.height / 2));
            context?.strokePath();
        }
        
        if ((UInt32(orientation) & MWB_SCANDIRECTION_VERTICAL > 0) || (UInt32(orientation) & MWB_SCANDIRECTION_OMNI > 0) || (UInt32(orientation) & MWB_SCANDIRECTION_AUTODETECT > 0)){
            
            context?.move(to: CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y));
            context?.addLine(to: CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height));
            context?.strokePath();
        }
        
        if ((UInt32(orientation) & MWB_SCANDIRECTION_OMNI > 0) || (UInt32(orientation) & MWB_SCANDIRECTION_AUTODETECT > 0)){
            context?.move(to: CGPoint(x: rect.origin.x , y: rect.origin.y));
            context?.addLine(to: CGPoint(x: rect.origin.x + rect.size.width , y: rect.origin.y + rect.size.height));
            context?.strokePath();
            
            context?.move(to: CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y));
            context?.addLine(to: CGPoint(x: rect.origin.x , y: rect.origin.y + rect.size.height));
            context?.strokePath();
        }
        
        lineLayer.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage;
        
        UIGraphicsEndImageContext();
        
        MWOverlay.startLineAnimation();
        
        
    }
    
    class func showLocation(_ points:[CGPoint]!, width:Int32, height:Int32 ) {
        var points = points
        
        imageWidth = Int(width)
        imageHeight = Int(height)
        
        if points == nil {
            return
        }
        
        if (!isAttached || previewLayer == nil) {
            return
        }

        DispatchQueue.main.async {
            locationLayer.removeAllAnimations()
            
            previewLayer.addSublayer(locationLayer)

            let cgRect = locationLayer.frame
            
            UIGraphicsBeginImageContext(cgRect.size)
            let context = UIGraphicsGetCurrentContext()
            UIGraphicsPushContext(context!)
            
            context?.clear(cgRect)
            let r = CGFloat(locationLineColor >> 16) / 255.0
            let g = CGFloat((locationLineColor & 0x00ff00) >> 8) / 255.0
            let b = CGFloat(locationLineColor & 0x0000ff) / 255.0
            context?.setStrokeColor(red: r, green: g, blue: b, alpha: 1)
            context?.setLineWidth(locationLineWidth)
           
            for i in 0 ..< 4 {
                points![i].x = points![i].x / CGFloat(imageWidth);
                points![i].y = points![i].y / CGFloat(imageHeight);
                points![i] =  previewLayer.pointForCaptureDevicePoint(ofInterest: points![i]);
            }
            
            context?.move(to: CGPoint(x: (points?[0].x)!, y: (points?[0].y)!))
            
            for i in 1 ..< 4 {
                context?.addLine(to: CGPoint(x: points![i].x, y: points![i].y))
            }
            context?.addLine(to: CGPoint(x: (points?[0].x)!,y: (points?[0].y)!));
            context?.strokePath();
            UIGraphicsPopContext();
            locationLayer.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
            UIGraphicsEndImageContext();
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0
            animation.duration = 0.5
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            animation.fillMode = kCAFillModeForwards
            animation.isRemovedOnCompletion = false
            locationLayer.add(animation, forKey: "opacity")
            
        }

    }
    
    class func startLineAnimation() {
        lineLayer.removeAllAnimations();
        let animation = CABasicAnimation(keyPath: "opacity");
        animation.fromValue = blinkingLineAlpha;
        animation.toValue = 0.0;
        animation.duration = CFTimeInterval(blinkingSpeed);
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear);
        animation.autoreverses = true;
        animation.repeatCount = Float.infinity;
        lineLayer.add(animation, forKey:"opacity");
    }
    
}


