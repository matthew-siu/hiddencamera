//
//  ViewController.swift
//  eclipsemints
//
//  Created by Matthew Siu on 24/6/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var switchCamBtn: UIButton!
    @IBOutlet weak var takePhotoBtn: UIButton!
    @IBOutlet weak var btnStackView: UIStackView!
    @IBOutlet weak var imageView: UIImageView!
    
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var cameraDevice: AVCaptureDevice?
    
    var currentCameraPosition: AVCaptureDevice.Position = .back
    
    
    var outputVolumeObserve: NSKeyValueObservation?
    let audioSession = AVAudioSession.sharedInstance()
    
    @IBAction func didTakePhoto(_ sender: Any) {
        print("didTakePhoto")
        self.capturePhoto()
    }
    
    @IBAction func didSwitchCam(_ sender: Any) {
        print("switch cam")
        self.currentCameraPosition = (self.currentCameraPosition == .back) ? .front : .back
        initCamera(currentCameraPosition)
    }
    
    func listenVolumeButton() {
        do {
            try audioSession.setActive(true)
        } catch {}

        outputVolumeObserve = audioSession.observe(\.outputVolume) { (audioSession, changes) in
            print("volume control")
            self.capturePhoto()
        }
    }
    
    private func capturePhoto(){
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        self.stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad")
        
        // disable dark mode
        view.overrideUserInterfaceStyle = .light
    }
    
    // hide status bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Setup your camera here...
        
        self.initCamera()
//        self.listenVolumeButton()
//        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    func initCamera(_ defaultCam: AVCaptureDevice.Position = .back){
        for subview in self.previewView.subviews{
            subview.removeFromSuperview()
        }
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        
        guard var camera = AVCaptureDevice.default(for: AVMediaType.video) else {
                print("Unable to access back camera!")
                return
        }
        
        let videoDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDualCamera], mediaType: .video, position: .unspecified).devices
        for device in videoDevices {
            if device.position == defaultCam {
                camera = device
                break
            }
        }
        
        self.cameraDevice = camera
//        camera.isFocusModeSupported(.continuousAutoFocus)
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            //Step 9
            stillImageOutput = AVCapturePhotoOutput()
            
            //Step 10
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchPoint = touches.first!
        let screenSize = previewView.bounds.size
        let focusPoint = CGPoint(x: touchPoint.location(in: previewView).y / screenSize.height, y: 1.0 - touchPoint.location(in: previewView).x / screenSize.width)

        if let device = cameraDevice {
            device.isFocusModeSupported(.continuousAutoFocus)
            do{
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            }catch{

            }
            
            
        }
    }
    
    //Step 11
    func setupLivePreview() {
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
//        self.view.bringSubviewToFront(self.btnStackView)
        
        //Step12
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            //Step 13
            
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
    }
    
    
    //Step 16
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate{
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        guard let imageData = photo.fileDataRepresentation()
            else { return }

        guard let image = UIImage(data: imageData) else{ return }
//        imageView.image = image
        
        // save photo to album
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(finishSavingPhoto(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    //MARK: - Add image to Library
    @objc func finishSavingPhoto(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            print("finishSavingPhoto failed: \(error.localizedDescription)")
        }
    }
    
    // mute the camera
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // dispose system shutter sound
        AudioServicesDisposeSystemSoundID(1108)
    }
}
