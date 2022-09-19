//
//  ViewController.swift
//  AR Voice Robot
//
//  Created by Ali Eldeeb on 9/18/22.
//

import UIKit
import RealityKit
import ARKit
import Speech
 
class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    var robotEntity: Entity?
    var moveToLocation: Transform = Transform()
    var movementDuration: Double = 3
    
    //Speech recognition
    let speechRecognizer = SFSpeechRecognizer()
    let speechRequest = SFSpeechAudioBufferRecognitionRequest()
    var speechTask = SFSpeechRecognitionTask()
    
    //Audio
    //An object that manages a graph of audio nodes, controls playback, and configures real-time rendering constraints.
    let audioEngine = AVAudioEngine()
    //An object that communicates to the system how you intend to use audio in your app.
    let audioSession = AVAudioSession.sharedInstance() //.sharedInstance returns the shared audio instance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //start and initialize
        startArSession()
        
        //load 3d model
        robotEntity = try! Entity.load(named: "robot")
        
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        
        //Start speech recognition
        startSpeechRecognition()
        
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
        }
    }
    
    //Mark: -Object movement
    
    func move(direction: String){
        switch direction{
        case "front", "Front":
            movement(x: 0, y: 0, z: 1)
            
        case "back", "Back":
            movement(x: 0, y: 0, z: -1)
        case "left", "Left":
            //GLKMathDegreesToRadians converts an angle measured in degrees to radians and we are doing it with respect to the y axis which is why we put a 1
            let rotateToAngle = simd_quatf(angle: GLKMathDegreesToRadians(90), axis: SIMD3(x: 0, y: 1, z: 0))
            //to do actual rotation
            robotEntity?.setOrientation(rotateToAngle, relativeTo: robotEntity)
           
        case "right", "Right":
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
            //play the animation, we are making it repeat for a duration of 4 secs, transition duration is the duration in seconds over which the animation fades in or cross-fades. We set startsPaused to false so the animation starts right away
            robotEntity?.playAnimation(robotAnimation.repeat(duration: movementDuration), transitionDuration: 0.5, startsPaused: false)
        }
    }
    
    func startSpeechRecognition(){
        //1. Permission
        requestPermission()
        
        //2. Audio Record
        startAudioRecording()
        
        //3.Speech Recognition
        speechRecognize()
    }
    
    func requestPermission(){
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus == .authorized{
                //just some dummy print statements, we should load the ArView in this condition
                print("Authorized")
            }else if authStatus == .denied{
                print("Denied")
            }else if authStatus == .notDetermined{
                print("Waiting")
            }else if authStatus == .restricted{
                print("Not available")
            }
        }
    }
    
    func startAudioRecording(){
        //Input node is like a channel which you initialize to record audio to a certain stream
        let node = audioEngine.inputNode //The audio engine’s singleton input audio node.
        
        //busses are virtual placeholders of signals. They are indexed by integers starting with 0. The lowest numbered buses get written to the audio hardware output. Following output busses are input busses. A bus is an abstract representation of a channel. Nodes live on buses. The node can take audio in from one bus and output it into another bus.
        // The audio runs from the head to the tail. You can put your synths in front of the monster (where the sound will run through it) or at the tail (where it will receive the signal that runs through it).
        let recordingFormat = node.outputFormat(forBus: 0)
        
        //Installs an audio tap on a bus you specify to record, monitor, and observe the output of the node.
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            //pass the audio buffer samples to speech recognition, this is the callback for everytime a set of audio sample is recieved
            self.speechRequest.append(buffer)
        }
        //Audio Engine start, needs a node to get it started.
        do{
            //configure the audioSession to record from the microphone, .measurement is a mode that indicates that your app is performing measurement of audio input or output. duckOthers reduces the volume of other audio sessions while audio from this session plays.
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            //Setting the audioSession active
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            //.prepare preallocates many resources the audio engine requires to start. Use it to responsively start audio input or output.
            audioEngine.prepare()
            //starting the engine now that its prepared
            try audioEngine.start()
        }catch{
            
        }
    }
    //Everytime we recieve an audio sample, we pass it onto the speechRecognize task
    func speechRecognize(){
        //check for the availability of the speech recognition service, and to initiate the speech recognition process.
        guard let speechRecognizer = SFSpeechRecognizer() else{return}
        
        if speechRecognizer.isAvailable == false {
            print("Temporarily not working")
        }

        //Now that we've done that availability check we need to set the speech task of it running
        speechTask = speechRecognizer.recognitionTask(with: speechRequest, resultHandler: { (result, error) in
            
                guard let result = result else{return}
                //The transcription with the highest level of confidence, we want the most recent word said, this will be what we use for robot commands
                let recognizedText = result.bestTranscription.segments.last
                
                //robot move
                if let transcriptionToText = recognizedText?.substring{
                    self.move(direction: transcriptionToText)
                }
                
           
        })
        
    }
}
