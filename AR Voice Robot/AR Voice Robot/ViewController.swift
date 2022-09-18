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
    var robotEntity: Entity?
    var moveToLocation: Transform = Transform()
    var movementDuration: Double = 5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //start and initialize
        startArSession()
        
        //load 3d model
        robotEntity = try! Entity.load(named: "robot")
        
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
    
    func placeObject(_ object: Entity?, at location: SIMD3<Float>){
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
            //hardcoding the movement for now until we add speech recognition
            move(direction: "forward")
            //move(direction: "back")
            //move(direction: "Left")
            
        }
    }
    
    //Mark: -Object movement
    
    func move(direction: String){
        switch direction{
        case "forward":
            movement(x: 0, y: 0, z: 1)
            
        case "back":
            movement(x: 0, y: 0, z: -1)
        case "left":
            //GLKMathDegreesToRadians converts an angle measured in degrees to radians and we are doing it with respect to the y axis which is why we put a 1
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(90), axis: SIMD3(x: 0, y: 1, z: 0))
            //to do actual rotation
            robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
           
        case "right":
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(-90), axis: SIMD3(x: 0, y: 1, z: 0))
            robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
        default:
            print("No movement commands")
        }
    }
    
    func movement(x: Float, y: Float, z: Float){
        
        //taking the translation(x,y,z) if our transform and getting the current 3D position of the robot and moving it forward 20 cm with a new 3D vector
        if let robotPosition = robotEntity?.transform.translation{
            moveToLocation.translation = robotPosition + simd_float3(x: x, y: y, z: z)
        }
        //this moves an entity to a new location given by a transform, relative to our model entity
        robotEntity?.move(to: moveToLocation, relativeTo: robotEntity, duration: movementDuration)
        //start the walking animation
        walkAnimation(movementDuration: movementDuration)
    }
    
    func walkAnimation(movementDuration: Double){
        //USDZ animation
        if let robotAnimation = robotEntity?.availableAnimations.first{
            //play the animation, we are making it repeat for a duration of 5 secs, transition duration is the duration in seconds over which the animation fades in or cross-fades. We set startsPaused to false so the animation starts right away
            robotEntity?.playAnimation(robotAnimation.repeat(duration: movementDuration), transitionDuration: 0.5, startsPaused: false)
        }
    }
    
}
