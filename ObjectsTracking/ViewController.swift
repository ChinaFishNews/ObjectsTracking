//
//  ViewController.swift
//  ObjectsTracking
//
//  Created by 新闻 on 2017/11/12.
//  Copyright © 2017年 新闻. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var overlayView: UIView! {
        didSet {
            self.overlayView.layer.borderColor = UIColor.red.cgColor
            self.overlayView.layer.borderWidth = 5
            self.overlayView.layer.cornerRadius = 8
            self.overlayView.backgroundColor = .clear
        }
    }
    
    lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard let backCamera =  AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: backCamera) else {
            return session
        }
        session.addInput(input)
        return session
    }()
    
    lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    // 拿到可见结果
    var previiosObservarion: VNDetectedObjectObservation?
    
    // 多图分析请求处理器
    let visionSequenceHandler = VNSequenceRequestHandler()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ObjectTrackingQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
        
        self.overlayView.frame = .zero
        self.cameraView.layer.addSublayer(self.cameraLayer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    // 点击屏幕
    @IBAction func pressScreen(_ sender: UITapGestureRecognizer) {
        print("taped")
        self.overlayView.frame.size = CGSize(width: 150, height: 150)
        self.overlayView.center = sender.location(in: self.view)
        
        let orginalRect = self.overlayView.frame
        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: orginalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        
        let currentObservervation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.previiosObservarion = currentObservervation
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 拿到当前最新的数据
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let lastObservation = self.previiosObservarion else { return }
        
        let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: handleVisionRequestUpdate)
        request.trackingLevel = .accurate // 精确追踪(耗电) fast
        try? self.visionSequenceHandler.perform([request], on: pixelBuffer)
    }
    
    // 处理结果
    func handleVisionRequestUpdate( request: VNRequest, error: Error?){
        DispatchQueue.main.async {
            guard let currentObservation = request.results?.first as? VNDetectedObjectObservation else {
                self.overlayView.frame = .zero
                return
            }
            self.previiosObservarion = currentObservation // 更新最新结果
            
            var currentBoundingBox = currentObservation.boundingBox
            currentBoundingBox.origin.y = 1 - currentBoundingBox.origin.y // 翻转坐标
            let newBoundingBox = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: currentBoundingBox)
            self.overlayView.frame = newBoundingBox
        }
    }
}

