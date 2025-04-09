//
//  ARWrapper.swift
//  LidarModelApp2
//
//  Created by Andre Grossberg on 4/6/25.
//

import SwiftUI
import RealityKit
import ARKit

struct ARWrapper: UIViewRepresentable {
    @Binding var submittedExportRequest: Bool
    @Binding var exportedURL: URL?
    
    let arView = ARView(frame: .zero)
    let vm = ExportViewModel()  // Move this outside so it's persistent.

    
    func makeUIView(context: Context) -> ARView {
        arView.session.delegate = vm  // Make sure this is set only once.
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        let vm = ExportViewModel()
        
        
        setARViewOptions(arView)
        let cofniguration = buildConfigure()
        arView.session.run(cofniguration)
        
        if submittedExportRequest {
            guard let camera = arView.session.currentFrame?.camera else { return }
            if let meshAnchors = arView.session.currentFrame?.anchors.compactMap({$0 as? ARMeshAnchor}),
               let asset = vm.convertToAsset(meshAnchor: meshAnchors, camera: camera) {
                do {
                    let url = try vm.export(asset: asset)
                    exportedURL = url
                } catch {
                    print("export failure haha")
                }
            }
                
        }
    }
    
    private func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.environmentTexturing = .automatic
        configuration.sceneReconstruction = .meshWithClassification
        
        arView.automaticallyConfigureSession = false
        
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        
        return configuration
    }
    
    
    private func setARViewOptions(_ arView: ARView) {
        arView.debugOptions.insert(.showSceneUnderstanding)
    }
}

class ExportViewModel: NSObject, ObservableObject, ARSessionDelegate {
    
    func convertToAsset(meshAnchor: [ARMeshAnchor], camera: ARCamera) -> MDLAsset? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        let asset = MDLAsset()
        
        for anchor in meshAnchor {
            let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
        }
        return asset
    }
    
    func export(asset: MDLAsset) throws -> URL {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "com.original.ProjectName", code:153)
        }
        
        let folderName = "OBJ_FILES"
        
        let folderURL = directory.appendingPathComponent(folderName)
        
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        
        let url = folderURL.appendingPathComponent("\(UUID().uuidString).obj")
        
        do {
            try asset.export(to: url)
            print("Object saved successfully at ", url)
            return url
        } catch {
            print(error)
        }
        
        return url
        
        
    }
    
    //-----------------------------------------------------
    
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        guard let depthMap = frame.sceneDepth?.depthMap else {
//            print("No depth map")
//            return
//        }
//
//        let width = CVPixelBufferGetWidth(depthMap)
//        let height = CVPixelBufferGetHeight(depthMap)
//
//        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
//        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
//
//        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)
//
//        // Downsample grid (e.g., every 10 pixels)
//        let step = 10
//        var grid: [[Float]] = []
//
//        for y in stride(from: 0, to: height, by: step) {
//            var row: [Float] = []
//            for x in stride(from: 0, to: width, by: step) {
//                let depth = floatBuffer[y * width + x]
//                row.append(depth.isNaN ? 0.0 : depth)
//            }
//            grid.append(row)
//        }
//
//        print("📏 Depth Grid (in meters):")
//            for row in grid {
//                let formattedRow = row.map { String(format: "%.2f", $0) }.joined(separator: "\t")
//                print(formattedRow)
//            }
//    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.sceneDepth?.depthMap else {
            print("No depth map")
            return
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)

        // Define 3x3 sampling points
        let sampleXs = [width / 6, width / 2, (width * 5) / 6]
        let sampleYs = [height / 6, height / 2, (height * 5) / 6]

        var grid: [[Float]] = []

        for y in sampleYs {
            var row: [Float] = []
            for x in sampleXs {
                let depth = floatBuffer[y * width + x]
                row.append(depth.isNaN ? 0.0 : depth)
            }
            grid.append(row)
        }

        // Pretty print the 3x3 grid
        print("📏 3×3 Depth Grid (meters):")
        for row in grid {
            let formatted = row.map { String(format: "%.2f", $0) }.joined(separator: "\t")
            print(formatted)
        }
    }

}
