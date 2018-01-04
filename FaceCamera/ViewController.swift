//
//  ViewController.swift
//  FaceCamera
//
//  Created by DerekYang on 2018/1/3.
//  Copyright © 2018年 LBD. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation

class ViewController: UIViewController
{
    var session: AVCaptureSession?
    
    @IBOutlet var boxView: UIView!
    @IBOutlet var preView: UIView!
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        sessionPrepare()
        session?.startRunning()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
        preView.layer.addSublayer(previewLayer)
      
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func sessionPrepare() {
        session = AVCaptureSession()
        guard let session = session, let captureDevice = frontCamera else { return }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            print("setup delegate")
        } catch {
            print("can't setup session")
        }
    }
    
    func detectFace(_ img: CIImage)
    {
        
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: img)
        
        // Convert Core Image Coordinate to UIView Coordinate
        let ciImageSize = img.extent.size
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -ciImageSize.height)
        
        for face in faces as! [CIFaceFeature] {
            
            print("Found bounds are \(face.bounds)")
            
            // Apply the transform to convert the coordinates
            var faceViewBounds = face.bounds.applying(transform)
            
            // Calculate the actual position and size of the rectangle in the image view
            let viewSize = boxView.bounds.size
            let scale = min((viewSize.width / ciImageSize.width),
                            (viewSize.height / ciImageSize.height))
            let offsetX = (viewSize.width - ciImageSize.width * scale) / 2
            let offsetY = (viewSize.height - ciImageSize.height * scale) / 2
            
            faceViewBounds = faceViewBounds.applying(CGAffineTransform(scaleX: scale, y: scale))
            faceViewBounds.origin.x += offsetX
            faceViewBounds.origin.y += offsetY
            
            let faceBox = UIView(frame: faceViewBounds)
            
//            if(face.hasLeftEyePosition){
//                let leftEye = UIView.init(frame:CGRect(x: 0, y: 0, width: 5, height: 5))
//                leftEye.center = face.leftEyePosition
//                faceBox.addSubview(leftEye)
//            }
//
//            if(face.hasRightEyePosition){
//                let rightEye = UIView.init(frame:CGRect(x: 0, y: 0, width: 5, height: 5))
//                rightEye.center = face.leftEyePosition
//                faceBox.addSubview(rightEye)
//            }
            
            print(face.leftEyeClosed ? "On" : "off")
            
            faceBox.layer.borderWidth = 3
            faceBox.layer.borderColor = UIColor.red.cgColor
            
            for view in self.boxView.subviews {
                view.removeFromSuperview()
            }
            self.boxView.addSubview(faceBox)
            
            
            
            //            if face.hasLeftEyePosition {
            //                print("Left eye bounds are \(face.leftEyePosition)")
            //            }
            //
            //            if face.hasRightEyePosition {
            //                print("Right eye bounds are \(face.rightEyePosition)")
            //            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue))
        DispatchQueue.main.async {
            [weak self] in
            self?.detectFace(ciImageWithOrientation)
        }
    }
    
}

