//
//  ViewController.swift
//  MWBarcodeCameraDemo
//
//  Created by vladimir zivkovic on 7/24/14.
//  Copyright (c) 2014 Manateeworks. All rights reserved.
//  v2.1

/*


Changes in v2.1:
- Added Parser lib
- Added ANalytics lib

Changes in v2.0:
- Added Multithreading support
- New structured result type - MWResult

Changes in v1.4:
- Added ITF-14 support
- Added Code 11 support
- Added MSI Plessey support
- GS1 support


*/

import UIKit
import Foundation
import AVFoundation
import CoreVideo
import CoreMedia


class ScannerController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIAlertViewDelegate {
 
    
    static let OM_NONE         = 0 //Don't display any overlay
    static let OM_MWOVERLAY    = 1 //Use MW dynamic viewfinder with blinking line
    static let OM_IMAGE        = 2 //Use image file as overlay (overlay.png)

    let OVERLAY_MODE = ScannerController.OM_MWOVERLAY

    let MAX_THREADS = 4
    let PDF_OPTIMIZED = false
    let USE_TOUCH_TO_ZOOM = false
    
    let USE_ANALYTICS = false

    let USE_60_FPS = false
    
    let MAX_DIGITAL_ZOOM = 4
    
    let ANALYTICS_TAG = "CustomTag"
    
    /* Parser */
    /*
     *   Set the desired parser type
     *   Available options:
     *       MWP_PARSER_MASK_NONE
     *       MWP_PARSER_MASK_IUID
     *       MWP_PARSER_MASK_ISBT
     *       MWP_PARSER_MASK_AAMVA
     *       MWP_PARSER_MASK_HIBC
     *       MWP_PARSER_MASK_AUTO
     */
    let PARSER_MASK = MWP_PARSER_MASK_NONE
 
    
    // !!! Rects are in format: x, y, width, height!!!
    let RECT_LANDSCAPE_1D: Array<Float> =      [4, 20, 92, 60]
    let RECT_LANDSCAPE_2D: Array<Float> =      [20, 5, 60, 90]
    let RECT_PORTRAIT_1D: Array<Float> =       [20, 4, 60, 92]
    let RECT_PORTRAIT_2D: Array<Float> =       [20, 5, 60, 90]
    let RECT_FULL_1D: Array<Float> =           [4, 4, 92, 92]
    let RECT_FULL_2D: Array<Float> =           [20, 5, 60, 90]
    let RECT_DOTCODE: Array<Float> =           [30,20,40,60]
    
    
    
    enum camera_state {
        case normal,
        launching_CAMERA,
        camera,
        camera_DECODING,
        decode_DISPLAY,
        cancelling
    }
    
    let DecoderResultNotification = "DecoderResultNotification"

    @IBOutlet weak var zoomButton:UIButton!
    @IBOutlet weak var flashButton:UIButton!
    @IBOutlet weak var closeButton:UIButton!
    @IBOutlet weak var imageOverlay:UIImageView!

    
    var device: AVCaptureDevice!
    var captureSession: AVCaptureSession!
    var prevLayer: AVCaptureVideoPreviewLayer!
    var state:camera_state = camera_state.normal
    var lastFormat:String!
    var lastResultString:String!
    var focusTimer: Timer!
    var activeThreads:Int!
    var availableThreads:Int!
    var videoZoomSupported = false
    
    var param_ZoomLevel1:Int!
    var param_ZoomLevel2:Int!
    var zoomLevel:Int!
    var firstZoom:Double!
    var secondZoom:Double!
    var digitalZoom:Int = 1
    
//    var totalFrames = 0
    
    override var prefersStatusBarHidden: Bool{
        return true;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("\(#function) -> \(#line) ---start-------")
        
        
        param_ZoomLevel1 = 0; //set automatic
        param_ZoomLevel2 = 0; //set automatic
        zoomLevel = 0;
        digitalZoom = 1
        
        initDecoder();
        
        /*
        if USE_ANALYTICS {
            initAnalytics();
        }*/

    
        
        //var timer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: Selector("measureFPS"), userInfo: nil, repeats: true)
        
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    /*
    func measureFPS() {
        var fps = Float(totalFrames)/3
        totalFrames = 0
        
        println("FPS: \(fps)")
        
    }*/
    
    func initAnalytics() {

        /* Analytics */
        /*
         *   Register analytics with given apiUser and apiKey
         */
        
        //MWBAnalytics.getInstance().initializeAnalytics(withUsername: "apiUser", apiKey: "apiKey")

    }
 
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        print("\(#function) -> \(#line)------start-------")
        self.initCapture();
        self.startScanning();
        print("\(#function) -> \(#line)------end-------")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //flashButton.isSelected = false;
        print("\(#function) -> \(#line)------start-------")
        //updateFlash()
        print("\(#function) -> \(#line)------end-------")
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
        flashButton.isSelected = false;
        //updateFlash()
        
        self.stopScanning();
        self.deinitCapture();
        
        print("\(#function) -> \(#line)")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval ){
    
       // UIView.setAnimationsEnabled(false);
        print("\(#function) -> \(#line)")
        
        if toInterfaceOrientation == UIInterfaceOrientation.landscapeLeft{
            self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft;
            self.prevLayer.frame = CGRect(x: 0, y: 0, width: max(self.view.frame.size.width,self.view.frame.size.height), height: min(self.view.frame.size.width,self.view.frame.size.height));
        }
        
        if toInterfaceOrientation == UIInterfaceOrientation.landscapeRight{
            self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
            self.prevLayer.frame = CGRect(x: 0, y: 0, width: max(self.view.frame.size.width,self.view.frame.size.height), height: min(self.view.frame.size.width,self.view.frame.size.height));
        }
        
        if toInterfaceOrientation == UIInterfaceOrientation.portrait{
            self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait;
            self.prevLayer.frame = CGRect(x: 0, y: 0, width: min(self.view.frame.size.width,self.view.frame.size.height), height: max(self.view.frame.size.width,self.view.frame.size.height));
        }
        
        if toInterfaceOrientation == UIInterfaceOrientation.portraitUpsideDown{
            self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown;
            self.prevLayer.frame = CGRect(x: 0, y: 0, width: min(self.view.frame.size.width,self.view.frame.size.height), height: max(self.view.frame.size.width,self.view.frame.size.height));
        }

        
    
   
        if OVERLAY_MODE == ScannerController.OM_MWOVERLAY {
            MWOverlay.removeFromPreviewLayer();
            MWOverlay.addToPreviewLayer(self.prevLayer);
        }
    
    
    }
    
    func startScanning() {
        print("\(#function) -> \(#line) ----start-------")
        self.captureSession.startRunning()
        self.prevLayer.isHidden = false
        self.state = camera_state.camera
        if device.isTorchModeSupported(AVCaptureTorchMode.on) {
            view.bringSubview(toFront: flashButton)
        }
        if videoZoomSupported {
            zoomButton.isHidden = false
            view.bringSubview(toFront: zoomButton)
        } else {
            zoomButton.isHidden = true
        }
        view.bringSubview(toFront: closeButton)
        print("\(#function) -> \(#line) ----done-------")
    }
    
    func stopScanning() {
        print("\(#function) -> \(#line)")
        self.captureSession.stopRunning();
        self.state = camera_state.normal
        self.prevLayer.isHidden = true
    }
    
    func reFocus() {
        print("\(#function) -> \(#line) -----calling reFocus------")
        
        do{
            
            try self.device.lockForConfiguration()
            
            if (self.device.isFocusPointOfInterestSupported){
                self.device.focusPointOfInterest = CGPoint(x: 0.49,y: 0.49)
                self.device.focusMode = AVCaptureFocusMode.autoFocus
            }
            self.device.unlockForConfiguration();

        }catch _{
            
        }
    }
    
    func toggleTorch()
        
    {
        print("\(#function) -> \(#line)")
        if (self.device.isTorchModeSupported(AVCaptureTorchMode.on)) {
            do{
                try self.device?.lockForConfiguration()
                if (self.device.torchMode == AVCaptureTorchMode.on){
                    self.device.torchMode = AVCaptureTorchMode.off
                }else {
                    self.device.torchMode = AVCaptureTorchMode.on
                }
                
                self.device.unlockForConfiguration()
                
            }catch _{
            }
        }
    }
    
    @IBAction func doClose(_: AnyObject) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onFlashButton(){
        flashButton.isSelected = !flashButton.isSelected
        updateFlash();
    }
    @IBAction func onZoomButton(){

        zoomLevel = zoomLevel + 1
        
        if zoomLevel>2 {
            zoomLevel = 0
        }
        digitalZoom = 2 * digitalZoom
        
        if digitalZoom > MAX_DIGITAL_ZOOM {
            digitalZoom = 1
        }
        
        updateDigitalZoom()
    
    }
    func doZoomToggle(){
        zoomLevel = zoomLevel + 1
        if zoomLevel > 2 {
            zoomLevel = 0
        }
        
        updateDigitalZoom()
    }
    
  
    func initDecoder() {

        print("\(#function) -> \(#line)")
        //register your copy of library with given key
        let registerResult:Int32 = MWB_registerSDK("N2TfAe6UiOhNk17zw7PzYqX6bJFUzhQpUSC8t6iZgGU=")
        
        switch (registerResult) {
        case MWB_RTREG_OK:
            NSLog("Registration OK")
            break
        case MWB_RTREG_INVALID_KEY:
            NSLog("Registration Invalid Key")
            break
        case MWB_RTREG_INVALID_CHECKSUM:
            NSLog("Registration Invalid Checksum")
            break
        case MWB_RTREG_INVALID_APPLICATION:
            NSLog("Registration Invalid Application")
            break
        case MWB_RTREG_INVALID_SDK_VERSION:
            NSLog("Registration Invalid SDK Version")
            break
        case MWB_RTREG_INVALID_KEY_VERSION:
            NSLog("Registration Invalid Key Version")
            break
        case MWB_RTREG_INVALID_PLATFORM:
            NSLog("Registration Invalid Platform")
            break
        case MWB_RTREG_KEY_EXPIRED:
            NSLog("Registration Key Expired")
            break
            
        default:
            NSLog("Registration Unknown Error")
            break
        }

        
        // choose code type or types you want to search for
        
        if (PDF_OPTIMIZED){
            MWB_setActiveCodes(MWB_CODE_MASK_PDF);
            MWB_setDirection(MWB_SCANDIRECTION_HORIZONTAL);
            MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3] );
        } else {
            // Our sample app is configured by default to search all supported barcodes...
            MWB_setActiveCodes( MWB_CODE_MASK_PDF );
            
            
            // Our sample app is configured by default to search both directions...
            MWB_setDirection(MWB_SCANDIRECTION_HORIZONTAL | MWB_SCANDIRECTION_VERTICAL);
            // set the scanning rectangle based on scan direction(format in pct: x, y, width, height)
            MWB_setScanningRect(MWB_CODE_MASK_25,     RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3] );
            MWB_setScanningRect(MWB_CODE_MASK_39,     RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_93,     RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_128,    RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_AZTEC,  RECT_FULL_2D[0], RECT_FULL_2D[1], RECT_FULL_2D[2], RECT_FULL_2D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_DM,     RECT_FULL_2D[0], RECT_FULL_2D[1], RECT_FULL_2D[2], RECT_FULL_2D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_EANUPC, RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_POSTAL,    RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_MAXICODE,    RECT_FULL_2D[0], RECT_FULL_2D[1], RECT_FULL_2D[2], RECT_FULL_2D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_QR,     RECT_FULL_2D[0], RECT_FULL_2D[1], RECT_FULL_2D[2], RECT_FULL_2D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_RSS,    RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_CODABAR,RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_DOTCODE,RECT_DOTCODE[0], RECT_DOTCODE[1], RECT_DOTCODE[2], RECT_DOTCODE[3]);
            MWB_setScanningRect(MWB_CODE_MASK_11,     RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
            MWB_setScanningRect(MWB_CODE_MASK_MSI,    RECT_FULL_1D[0], RECT_FULL_1D[1], RECT_FULL_1D[2], RECT_FULL_1D[3]);
        }
        
        
        // But for better performance, only activate the symbologies your application requires...
        // MWB_setActiveCodes( MWB_CODE_MASK_25 );
        // MWB_setActiveCodes( MWB_CODE_MASK_39 );
        // MWB_setActiveCodes( MWB_CODE_MASK_93 );
        // MWB_setActiveCodes( MWB_CODE_MASK_128 );
        // MWB_setActiveCodes( MWB_CODE_MASK_AZTEC );
        // MWB_setActiveCodes( MWB_CODE_MASK_DM );
        // MWB_setActiveCodes( MWB_CODE_MASK_EANUPC );
        // MWB_setActiveCodes( MWB_CODE_MASK_PDF );
        // MWB_setActiveCodes( MWB_CODE_MASK_QR );
        // MWB_setActiveCodes( MWB_CODE_MASK_RSS );
        // MWB_setActiveCodes( MWB_CODE_MASK_CODABAR );
        // MWB_setActiveCodes( MWB_CODE_MASK_DOTCODE );
        // MWB_setActiveCodes( MWB_CODE_MASK_11 );
        // MWB_setActiveCodes( MWB_CODE_MASK_MAXICODE );
        // MWB_setActiveCodes( MWB_CODE_MASK_POSTAL );
        // MWB_setActiveCodes( MWB_CODE_MASK_MSI );
        
        
        // But for better performance, set like this for PORTRAIT scanning...
        // MWB_setDirection(MWB_SCANDIRECTION_VERTICAL);
        // set the scanning rectangle based on scan direction(format in pct: x, y, width, height)
        // MWB_setScanningRect(MWB_CODE_MASK_25,     RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3] );
        // MWB_setScanningRect(MWB_CODE_MASK_39,     RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_93,     RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_128,    RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_AZTEC,  RECT_PORTRAIT_2D[0], RECT_PORTRAIT_2D[1], RECT_PORTRAIT_2D[2], RECT_PORTRAIT_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_DM,     RECT_PORTRAIT_2D[0], RECT_PORTRAIT_2D[1], RECT_PORTRAIT_2D[2], RECT_PORTRAIT_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_EANUPC, RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_QR,     RECT_PORTRAIT_2D[0], RECT_PORTRAIT_2D[1], RECT_PORTRAIT_2D[2], RECT_PORTRAIT_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_RSS,    RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_MAXICODE,     RECT_PORTRAIT_2D[0], RECT_PORTRAIT_2D[1], RECT_PORTRAIT_2D[2], RECT_PORTRAIT_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_POSTAL,    RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_CODABAR,RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_DOTCODE,RECT_DOTCODE[0], RECT_DOTCODE[1], RECT_DOTCODE[2], RECT_DOTCODE[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_11,     RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_MSI,    RECT_PORTRAIT_1D[0], RECT_PORTRAIT_1D[1], RECT_PORTRAIT_1D[2], RECT_PORTRAIT_1D[3]);
        
        // or like this for LANDSCAPE scanning - Preferred for dense or wide codes...
        // MWB_setDirection(MWB_SCANDIRECTION_HORIZONTAL);
        // set the scanning rectangle based on scan direction(format in pct: x, y, width, height)
        // MWB_setScanningRect(MWB_CODE_MASK_25,     RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_39,     RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_93,     RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_128,    RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_AZTEC,  RECT_LANDSCAPE_2D[0], RECT_LANDSCAPE_2D[1], RECT_LANDSCAPE_2D[2], RECT_LANDSCAPE_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_DM,     RECT_LANDSCAPE_2D[0], RECT_LANDSCAPE_2D[1], RECT_LANDSCAPE_2D[2], RECT_LANDSCAPE_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_EANUPC, RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_PDF,    RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_QR,     RECT_LANDSCAPE_2D[0], RECT_LANDSCAPE_2D[1], RECT_LANDSCAPE_2D[2], RECT_LANDSCAPE_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_RSS,    RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_MAXICODE,     RECT_LANDSCAPE_2D[0], RECT_LANDSCAPE_2D[1], RECT_LANDSCAPE_2D[2], RECT_LANDSCAPE_2D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_POSTAL,    RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_CODABAR,RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_DOTCODE,RECT_DOTCODE[0], RECT_DOTCODE[1], RECT_DOTCODE[2], RECT_DOTCODE[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_11,     RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        // MWB_setScanningRect(MWB_CODE_MASK_MSI,    RECT_LANDSCAPE_1D[0], RECT_LANDSCAPE_1D[1], RECT_LANDSCAPE_1D[2], RECT_LANDSCAPE_1D[3]);
        
        
        // set decoder effort level (1 - 5)
        // for live scanning scenarios, a setting between 1 to 3 will suffice
        // levels 4 and 5 are typically reserved for batch scanning
        MWB_setLevel(2)
        
        
        //Set minimum result length for low-protected barcode types
        MWB_setMinLength(MWB_CODE_MASK_25, 5);
        MWB_setMinLength(MWB_CODE_MASK_MSI, 5);
        MWB_setMinLength(MWB_CODE_MASK_39, 5);
        MWB_setMinLength(MWB_CODE_MASK_CODABAR, 5);
        MWB_setMinLength(MWB_CODE_MASK_11, 5);
        
        MWB_setResultType(MWB_RESULT_TYPE_MW)
        //get and print Library version
        let ver = MWB_getLibVersion()
        let v1 = (ver >> 16)
        let v2 = (ver >> 8) & 0xff
        let v3 = (ver & 0xff)
        print(NSString(format:"--------Lib version: %d.%d.%d----------", v1, v2, v3))
        print("\(#function) -> \(#line) -> -----done---------")
        
        
    }
    
    func deinitCapture() {
        if (self.focusTimer != nil){
            self.focusTimer?.invalidate();
            self.focusTimer = nil;
        }
        
        if (self.captureSession != nil){
            if OVERLAY_MODE == ScannerController.OM_MWOVERLAY {
                MWOverlay.removeFromPreviewLayer();
            }
            
            
            self.captureSession=nil;
            
            self.prevLayer.removeFromSuperlayer();
            self.prevLayer = nil;
        }
    }
    
    func initCapture(){
        print("\(#function) -> \(#line) -----start----------")
        self.device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo);
       
        //if you want to use front cammera
      /*  let devices = AVCaptureDevice.devices()
        
        
        for device in devices {
            if (device.hasMediaType(AVMediaTypeVideo)) {
                if(device.position == AVCaptureDevicePosition.Front) {
                    self.device = device as? AVCaptureDevice
                }
            }
        }*/
        
        self.flashButton.removeFromSuperview()
        
        if device.isTorchModeSupported(AVCaptureTorchMode.on) {
            self.view.addSubview(flashButton)
        }
  
        do {
        
            let captureInput:AVCaptureDeviceInput = try AVCaptureDeviceInput(device: self.device)
            let captureOutput:AVCaptureVideoDataOutput = AVCaptureVideoDataOutput();
            captureOutput.alwaysDiscardsLateVideoFrames = true;
            captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main);
            
            captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]

            self.captureSession = AVCaptureSession();
            
            self.captureSession.addInput(captureInput);
            self.captureSession.addOutput(captureOutput);
            
            
            }catch _{}
            var resX:Int32 = 640
            var resY:Int32 = 480
            
            if self.captureSession.canSetSessionPreset(AVCaptureSessionPreset1280x720){
                print("Set preview port to 1280X720");
                self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
                
                resX = 1280
                resY = 720
                
            } else {
                if self.captureSession.canSetSessionPreset(AVCaptureSessionPreset640x480){
                    print("Set preview port to 640x480");
                    self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
                }
            }
            
            //        // Limit camera FPS to 15 for single core devices (iPhone 4 and older) so more CPU power is available for decoder
            
            print("Number of processors \(ProcessInfo.processInfo.processorCount)")
            
            
            
            if (ProcessInfo.processInfo.processorCount < 2){
                do{
                    try self.device.lockForConfiguration();
                    self.device.activeVideoMinFrameDuration = CMTimeMake(1,15)
                    self.device.unlockForConfiguration()
                    print("activeVideoMinFrameDuration: \(self.device.activeVideoMinFrameDuration)")
                }catch _{}
            }else if USE_60_FPS {
                
                for vFormat in self.device.formats as! [AVCaptureDeviceFormat]{
                    let description = vFormat.formatDescription
                    let rates = vFormat.videoSupportedFrameRateRanges[0] as! AVFrameRateRange
                    
                    let maxrate = rates.maxFrameRate
                    let minrate = rates.minFrameRate
                    
                    
                    
                    
                    let dimensions: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(description!);
                    if maxrate > 59 && Int32(CMFormatDescriptionGetMediaSubType(description!)) == Int32(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) && dimensions.width == resX && dimensions.height == resY {
                        do{
                            try self.device.lockForConfiguration()
                            self.device.activeFormat = vFormat
                            self.device.activeVideoMinFrameDuration = CMTimeMake(Int64(10), Int32(minrate * 10))
                            self.device.activeVideoMaxFrameDuration = CMTimeMake(Int64(10), Int32(600))
                            self.device.unlockForConfiguration()
                        }catch _{}
                        
                    }
                    
                }
            }
            
            
            availableThreads = min(MAX_THREADS, ProcessInfo.processInfo.processorCount)
            activeThreads = 0
            
            self.prevLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        
            if UIApplication.shared.statusBarOrientation == .landscapeLeft{
                self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft;
                self.prevLayer.frame = CGRect(x: 0, y: 0, width: max(self.view.frame.size.width,self.view.frame.size.height), height: min(self.view.frame.size.width,self.view.frame.size.height));
                print("landscapeLeft")
            }
            
            if UIApplication.shared.statusBarOrientation == .landscapeRight{
                self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
                self.prevLayer.frame = CGRect(x: 0, y: 0, width: max(self.view.frame.size.width,self.view.frame.size.height), height: min(self.view.frame.size.width,self.view.frame.size.height));
                print("landscapeRight")
            }
            
            if UIApplication.shared.statusBarOrientation == .portrait{
                self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait;
                self.prevLayer.frame = CGRect(x: 0, y: 0, width: min(self.view.frame.size.width,self.view.frame.size.height), height: max(self.view.frame.size.width,self.view.frame.size.height));
            }
            
            if UIApplication.shared.statusBarOrientation == .portraitUpsideDown{
                self.prevLayer.connection.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown;
                self.prevLayer.frame = CGRect(x: 0, y: 0, width: min(self.view.frame.size.width,self.view.frame.size.height), height: max(self.view.frame.size.width,self.view.frame.size.height));
            }
            
            
            self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.view.layer.addSublayer(self.prevLayer);
        
        if OVERLAY_MODE == ScannerController.OM_MWOVERLAY {
            MWOverlay.addToPreviewLayer(self.prevLayer);
            imageOverlay.isHidden = true
            print("imageoverlay = true")
        } else if OVERLAY_MODE == ScannerController.OM_IMAGE {
            imageOverlay.isHidden = false
            view.bringSubview(toFront: imageOverlay)
        } else {
            imageOverlay.removeFromSuperview()
        }
        
            
            videoZoomSupported = false
            
            
            let maxZoom = self.device.activeFormat.videoZoomFactorUpscaleThreshold
            let maxZoomTotal = self.device.activeFormat.videoMaxZoomFactor
            
            
            if maxZoomTotal > 1.1 {
                print(maxZoomTotal)
                videoZoomSupported = true
                if param_ZoomLevel1 != 0 && param_ZoomLevel2 != 0{
                    
                    if CGFloat(param_ZoomLevel1) > maxZoomTotal * 100 {
                        param_ZoomLevel1 = Int(maxZoomTotal * 100)
                    }
                    if CGFloat(param_ZoomLevel2) > maxZoomTotal * 100 {
                        param_ZoomLevel2 = Int(maxZoomTotal * 100);
                    }
                    
                    firstZoom = 0.01 * Double(param_ZoomLevel1);
                    secondZoom = 0.01 * Double(param_ZoomLevel2);
                    
                    
                } else {
                    
                    if maxZoomTotal > 2{
                        print("Function: \(#function), line: \(#line) -> \(maxZoomTotal)")

                        if (maxZoom > 1.0 && maxZoom <= 2.0){
                            firstZoom = Double(maxZoom);
                            secondZoom = Double(maxZoom) * 2;
                        } else
                            if (maxZoom > 2.0){
                                firstZoom = 2.0;
                                secondZoom = 4.0;
                        }
                        
                    }
                }
                
                
            }
        
            // call refocus repeatly, waiting till code in camara zone
            self.focusTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(ScannerController.reFocus), userInfo: nil, repeats: true);
        
    }


    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
   
    {
        //totalFrames++
        print("\(#function) -> \(#line)*****capture start**********")
        if state != camera_state.camera && state != camera_state.camera_DECODING {
            return;
        }

        if self.activeThreads >= self.availableThreads {
            return;
        }
        
        if self.state != camera_state.camera_DECODING
        {
            self.state = camera_state.camera_DECODING;
        }
        
        self.activeThreads = self.activeThreads+1
        
      //print("active threads: \(self.activeThreads) / \(self.availableThreads)")
    
      //  var imageBuffer : COpaquePointer = CMSampleBufferGetImageBuffer(sampleBuffer).toOpaque()
      //  var pixelBuffer : CVPixelBuffer = (Unmanaged<CVPixelBuffer>.fromOpaque(imageBuffer)).takeUnretainedValue()
        
        
        
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
       
        CVPixelBufferLockBaseAddress(pixelBuffer!,CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
        
        //Get information about the image
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!,0)!.assumingMemoryBound(to: UInt8.self)
        //var pixelFormat:OSType = CVPixelBufferGetPixelFormatType(pixelBuffer!);
        
        //var pixelFormatInt:UInt32 = pixelFormat.bigEndian;
        
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!,0);
        let width:Int32 = Int32(bytesPerRow);//CVPixelBufferGetWidthOfPlane(imageBuffer,0);
        let height:Int32 = Int32(CVPixelBufferGetHeightOfPlane(pixelBuffer!,0));
        
        let frameBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(Int(width) * Int(height)))    //UnsafeMutablePointer<UInt8>(allocatingCapacity: Int(width * height));
        frameBuffer.initialize(from: UnsafeMutablePointer<UInt8>(baseAddress), count: Int(width * height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
        
        
        DispatchQueue.global(qos: .default).async {
            
            var pResult:UnsafeMutablePointer<UInt8>? = UnsafeMutablePointer<UInt8>.allocate(capacity: 8);
            var resLength:Int32 = 0

            resLength = MWB_scanGrayscaleImage(frameBuffer,width,height, &pResult);
            
            frameBuffer.deallocate(capacity: Int(width * height));
            
            var mwResults:MWResults! = nil
            var mwResult:MWResult! = nil;
            if resLength > 0 {
                if self.state == camera_state.normal {
                    resLength = 0
                    free(pResult)
                } else {
                    mwResults =  MWResults.init(buffer: pResult)
                    if mwResults != nil && mwResults.count > 0 {
                        mwResult = mwResults.results.object(at: 0) as! MWResult
                    }
                    free(pResult)
                }
                
            }
            
            if (mwResult != nil)
            {
                self.state = camera_state.normal
                
                if self.USE_ANALYTICS {
                    MWBAnalytics.getInstance().mwa_sendReport(UnsafeMutablePointer<UInt8> (mwResult.encryptedResult), resultType: mwResult.typeName, tag: self.ANALYTICS_TAG)
                }

                self.captureSession.stopRunning()
                
                if mwResult.locationPoints != nil && self.OVERLAY_MODE == ScannerController.OM_MWOVERLAY  {

                    let locPoints: [CGPoint]! = [mwResult.locationPoints.points[0] ,mwResult.locationPoints.points[1], mwResult.locationPoints.points[2],mwResult.locationPoints.points[3]]
                    MWOverlay.showLocation(locPoints! , width: mwResult.imageWidth, height: mwResult.imageHeight)
                   
                }
                
                var typeName = mwResult.typeName;
                
                
                if (mwResult.isGS1){
                    
                    typeName = NSString(format:"%@ (GS1)", typeName!) as String;
                    
                }
                
                DispatchQueue.main.async {
                    self.captureSession.stopRunning();
                    
                    var resultString:String = ""
                    resultString = mwResult.text
                    
                    if self.PARSER_MASK != MWP_PARSER_MASK_NONE && !(self.PARSER_MASK == MWP_PARSER_MASK_GS1 && !mwResult.isGS1) {
                       
                        var p_output:UnsafeMutablePointer<UInt8>? = nil
                        let parserRes =  MWP_getJSON(Int32(self.PARSER_MASK), UnsafePointer<UInt8>(mwResult.encryptedResult), mwResult.bytesLength, &p_output)
                        if (parserRes >= 0){
                            resultString = String.init(cString: p_output!)
                            
                            
                            var parserMask:String = ""
                            
                            switch (self.PARSER_MASK) {
                            case MWP_PARSER_MASK_GS1:
                                parserMask = "GS1";
                                break;
                            case MWP_PARSER_MASK_IUID:
                                parserMask = "IUID";
                                break;
                            case MWP_PARSER_MASK_ISBT:
                                parserMask = "ISBT";
                                break;
                            case MWP_PARSER_MASK_AAMVA:
                                parserMask = "AAMVA";
                                break;
                            case MWP_PARSER_MASK_HIBC:
                                parserMask = "HIBC";
                                break;
                            case MWP_PARSER_MASK_SCM:
                                parserMask = "SCM";
                                break;
                            default:
                                break;
                            }
                            
                            typeName = "\(typeName)(\(parserMask))"
                    
                        }
                    }
                        
                    
                    
                    
                        //use new ios 8 alerts
                    //option to show info on web app
                        if #available(iOS 8.0, *) {
                            
                            print("\(#function) -> \(#line)-------\(resultString)------------")
                            
                            //let pat = "DCS(*n)\\n"
                            //print(resultString.captureGroup(withRegex: pat))
                            
                            //let data = self.extractData(for: pat, in: resultString)
                            //print(data)
                            
                            //let alertController = UIAlertController(title: typeName, message: resultString, preferredStyle:.alert)
                            
                            
                            let alertController = UIAlertController(title: "Card Scanned!", message: "Search in web app", preferredStyle: .alert)
                            
                            let cancelAction = UIAlertAction(title: "Cancel", style: .destructive) { action in
                                self.state = camera_state.camera;
                                self.captureSession.startRunning();
                            }
                            
                            let searchAction = UIAlertAction(title: "Search", style: .cancel, handler: { action in
                                print("\(#function) -> \(#line)------searching...-------")
                                
                                
                                //**********************************crate request
                                //let url: NSURL = NSURL(string: "http://192.168.0.152:3000/")!
                                let url: NSURL = NSURL(string: "https://flwebscanner.herokuapp.com")!
                                let session = URLSession.shared
                                
                                let request = NSMutableURLRequest(url: url as URL)
                                request.httpMethod = "POST"
                                
                                let paramString = "dlInfo=\(resultString)"
                                request.httpBody = paramString.data(using: String.Encoding.utf8)
                                
                                let task = session.dataTask(with: request as URLRequest){
                                (data, response, error) in
                                    guard let _:NSData = data as NSData?, let _:URLResponse = response, error == nil else {
                                        print("error")
                                        return
                                    }
                                    
                                    if let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                                    {
                                        print("\(dataString)")
                                        
                                    }
                    
                                }
                                task.resume()
                                
                                //**********************************
                                self.state = camera_state.camera;
                                self.captureSession.startRunning();
                                UIApplication.shared.openURL(NSURL(string: "https://flwebscanner.herokuapp.com")! as URL)
                                //UIApplication.shared.openURL(NSURL(string: "http://192.168.0.152:3000/")! as URL)
                                
                            })
                            
                            
                            
                            alertController.addAction(cancelAction)
                            alertController.addAction(searchAction)
                                                        
                            self.present(alertController, animated: true, completion: nil)

                        } else {
                            //use old alerts
                            let alert = UIAlertView()
                            alert.title = self.lastFormat!;
                            alert.message = self.lastResultString;
                            alert.addButton(withTitle: "Close")
                            alert.cancelButtonIndex = 0;
                            alert.delegate = self;
                            
                            alert.show()
                        }
                        
                    
                }
                
                
            } else {
                self.state = camera_state.camera;
                print("Function: \(#function), line: \(#line) -> \(self.state) ******result=nil******")
            }
            
            self.activeThreads = self.activeThreads-1
            
        }
        
    }
    
    func updateFlash(){
        print("\(#function) -> \(#line)------start-------")
        setTorch(flashButton.isSelected);
    }
    
    func setTorch(_ torchOn: Bool){
        if(device.isTorchModeSupported(AVCaptureTorchMode.on)){
            
            do {
                try self.device.lockForConfiguration()
                
                if torchOn {
                    device.torchMode = AVCaptureTorchMode.on;
                } else {
                    device.torchMode = AVCaptureTorchMode.off;
                }
                
                
                self.device.unlockForConfiguration()
                
            }catch _{
                
            }

        }
    }

    
    func updateDigitalZoom(){
        if videoZoomSupported {
            
            do {
                try self.device.lockForConfiguration()
                
                switch zoomLevel {
                case 0:
                    self.device.videoZoomFactor = 1
                    break;
                case 1:
                    self.device.videoZoomFactor = CGFloat(firstZoom)
                    break;
                case 2:
                    self.device.videoZoomFactor = CGFloat(secondZoom)
                    break;
                    
                default:
                    break;
                }
                self.device.unlockForConfiguration()

            }catch _{
                
            }
            
        }
    }
    

    
    /*
    func extractData(for regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error {
            print("bad regex: \(error)")
            return []
        }
    }*/
    
    
    
}

extension String {
    func captureGroup(withRegex pattern: String) -> [String] {
        var results = [String]()
        
        var regex: NSRegularExpression
        
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.characters.count))
        
        guard let match = matches.first else {
            return results
        }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else {
            return results
        }
        
        for i in 1...lastRangeIndex {
            let captureGroupIndex = match.rangeAt(i)
            let matchedString = (self as NSString).substring(with: captureGroupIndex)
            results.append(matchedString)
        }
        
        
        
        return results
    }
}
