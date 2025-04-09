//
//  ARWrapper.swift
//  LidarModelApp2
//
//  Created by Andre Grossberg on 4/6/25.
//

import SwiftUI
import RealityKit
import ARKit
import Foundation
import CoreBluetooth

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
    
    let bluetooth = BluetoothManager()
    
    private var lastSendTime = Date.distantPast
    private let sendInterval: TimeInterval = 1

    
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
    

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.sceneDepth?.depthMap else {
            print("No depth map")
            return
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastSendTime) > sendInterval else {
            return
        }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)

        // Define 3x3 sampling points
        let sectionWidth = width / 3
        let sectionHeight = height / 3

        var grid: [[Float]] = [
            
        ]
        let topRow: [Float] = [0.0, 0.0, 0.0]
        grid.append(topRow)
        


        for col in 0..<3 {  // left to right
            var column: [Float] = []
            
            for row in (0..<3).reversed() {  // top to bottom
                var sum: Float = 0
                var count: Int = 0

                let startX = col * sectionWidth
                let endX = (col == 2) ? width : (startX + sectionWidth)

                let startY = row * sectionHeight
                let endY = (row == 2) ? height : (startY + sectionHeight)

                for y in startY..<endY {
                    for x in startX..<endX {
                        let depth = floatBuffer[y * width + x]
                        if depth.isFinite && depth > 0 {
                            sum += depth
                            count += 1
                        }
                    }
                }

                let avg = count > 0 ? sum / Float(count) : 0.0
                column.append(avg)
            }
            
            grid.append(column)
        }
        
       let col1Avg = (grid[1][0] + grid[2][0] + grid[3][0]) / Float(3)
       grid[0][0] = col1Avg

       // Calculate average for column 3 (grid[3])
       let col3Avg = (grid[1][2] + grid[2][2] + grid[3][2]) / Float(3)
       grid[0][2] = col3Avg
        
        




//         Pretty print the 3x4 grid
//        print("📏 3×4 Depth Grid (meters):")
//        for row in grid {
//            let formatted = row.map { String(format: "%.2f", $0) }.joined(separator: "\t")
//            print(formatted)
//        }
        
        bluetooth.sendDepthGrid(grid)
        lastSendTime = now


    }

}
