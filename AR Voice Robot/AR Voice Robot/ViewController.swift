//
//  ViewController.swift
//  AR Voice Robot
//
//  Created by Ali Eldeeb on 9/18/22.
//

import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    var robotEntity: ModelEntity?
    override func viewDidLoad() {
        super.viewDidLoad()
        //start and initialize
        startArSession()
        
        //load 3d model
        robotEntity = try! Entity.loadModel(named: "robot")
        
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        
    }
    //sets up ar scene to track horizontal surfaces and gets it running
    func startArSession(){
        arView.automaticallyConfigureSession = true
        //plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic //takes care of lighting and texturing to make more realistic
        arView.debugOptions = .showAnchorGeometry
        arView.session.run(configuration)
    }
    
    func placeObject(_ object: ModelEntity?, at location: SIMD3<Float>){
        let objectAnchor = AnchorEntity(world: location)
        
        if let objectEntity = object{
            objectAnchor.addChild(objectEntity)
            arView.scene.addAnchor(objectAnchor)
        }
        
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer){
        let tapLocation = sender.location(in: arView)
        //raycast 2D -> 3D point
        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let firstResult = results.first{
            //3D position of where the user tapped
            let worldPosition = simd_make_float3(firstResult.worldTransform.columns.3)
            //place 3d model
            placeObject(robotEntity, at: worldPosition)
        }
    }
    
}
