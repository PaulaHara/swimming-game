//
//  GameScene.swift
//  Racing
//
//  Created by paula on 2018-10-23.
//  Copyright © 2018 paula. All rights reserved.
//

import SpriteKit
import GameplayKit
import AVFoundation
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var motionManager = CMMotionManager()
    
    var whalePlayer = SKSpriteNode()
    var landRight = SKSpriteNode()
    var landLeft = SKSpriteNode()
    var donut = SKSpriteNode()
    
    var joystickBack = SKShapeNode()
    var joystickBtn = SKShapeNode()
    var joystickInUse = Bool()
    var velocityX = CGFloat()
    var velocityY = CGFloat()
    
    var location = CGPoint(x: 0, y: 0)
    
    var lakeMinX = CGFloat()
    var lakeMaxX = CGFloat()
    var lakeMaxY = CGFloat()
    var lakeBorderR = CGFloat()
    var lakeBorderL = CGFloat()
    
    var timePassed = Int()
    var calcScore = Int()
    var score = SKLabelNode()
    var velocity = CGFloat(10)
    var maxScore = Int()
    var obstaclesPassed = Int()
    
    var audioPlayer: AVAudioPlayer?
    var soundEffects: AVAudioPlayer?
        
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setUp()
        physicsWorld.contactDelegate = self
        Timer.scheduledTimer(timeInterval: TimeInterval(0.5), target: self, selector: #selector(GameScene.createLakeWave), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: TimeInterval(1), target: self, selector: #selector(GameScene.treeObstacles), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: TimeInterval(3), target: self, selector: #selector(GameScene.createDonut), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: TimeInterval(1), target: self, selector: (#selector(GameScene.updateTimer)), userInfo: nil, repeats: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Will delay for 1 second the starting of the music
            if let path = Bundle.main.path(forResource: "Gameplay-Music", ofType: ".mp3") {
                let url = URL(fileURLWithPath: path)
                self.audioPlayer = try? AVAudioPlayer(contentsOf: url)
                
                if let player = self.audioPlayer {
                    player.play()
                    player.numberOfLoops = -1
                }
            }
        }
        
        motionManager.startAccelerometerUpdates()
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data, error) in
            self.physicsWorld.gravity = CGVector(dx: CGFloat((data?.acceleration.x)!) * 10, dy: CGFloat((data?.acceleration.y)!) * 10)
            
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        showGameObjects()
        removeItems()
        
        self.whalePlayer.position.x += velocityX
        self.whalePlayer.position.y += velocityY
    }
    
    func setUp() {
        whalePlayer = self.childNode(withName: "whalePlayer") as! SKSpriteNode
        landRight = self.childNode(withName: "landRight") as! SKSpriteNode
        landLeft = self.childNode(withName: "landLeft") as! SKSpriteNode
        
        score = self.childNode(withName: "score") as! SKLabelNode
        score.position.x = -(UIScreen.main.bounds.maxX - CGFloat(180))
        score.position.y = UIScreen.main.bounds.maxY - CGFloat(250)
        score.zPosition = 20
        
        landRight.zPosition = 10
        landLeft.zPosition = 10
        whalePlayer.zPosition = 10
        
        lakeMaxX = UIScreen.main.bounds.maxX - landRight.size.width
        lakeMinX = -lakeMaxX
        lakeMaxY = UIScreen.main.bounds.maxY
        
        lakeBorderR = lakeMaxX - whalePlayer.size.width/2
        lakeBorderL = lakeMinX + whalePlayer.size.width/2
        
        landRight.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: (landRight.size.width), height: (landRight.size.height)))
        landRight.physicsBody?.categoryBitMask = ColliderType.ITEM_COLLIDER
        landRight.physicsBody?.collisionBitMask = 0
        landRight.physicsBody?.affectedByGravity = false
        
        landLeft.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: (landLeft.size.width), height: (landLeft.size.height)))
        landLeft.physicsBody?.categoryBitMask = ColliderType.ITEM_COLLIDER
        landLeft.physicsBody?.collisionBitMask = 0
        landLeft.physicsBody?.affectedByGravity = false
        
        whalePlayer.physicsBody?.categoryBitMask = ColliderType.PLAYER_COLLIDER
        whalePlayer.physicsBody?.contactTestBitMask = ColliderType.ITEM_COLLIDER
        whalePlayer.physicsBody?.collisionBitMask = 0
        
        // Joystick
        joystickBtn = SKShapeNode(circleOfRadius: CGFloat(50))
        joystickBack = SKShapeNode(circleOfRadius: CGFloat(90))
        joystickBack.fillColor = .darkGray
        joystickBtn.fillColor = .gray
        joystickBack.alpha = 0.5
        joystickBtn.alpha = 0.8
        
        joystickBack.position.x = -(UIScreen.main.bounds.maxX - CGFloat(160))
        joystickBack.position.y = -(UIScreen.main.bounds.maxY - CGFloat(240))
        joystickBack.zPosition = 20
        
        joystickBtn.position.x = -(UIScreen.main.bounds.maxX - CGFloat(160))
        joystickBtn.position.y = -(UIScreen.main.bounds.maxY - CGFloat(240))
        joystickBtn.zPosition = 20
        
        addChild(joystickBack)
        addChild(joystickBtn)
    }
    
    @objc func updateTimer() {
        timePassed += 1
        
        calcScore += 5
        updateScoreText()
    }
    
    func updateScoreText() {
        score.text = "Score: \(calcScore)"
    }
    
    func playSoundEffects(soundName: String, type: String) {
        if let path = Bundle.main.path(forResource: soundName, ofType: type) {
            let url = URL(fileURLWithPath: path)
            soundEffects = try? AVAudioPlayer(contentsOf: url)
            
            if let sfx = soundEffects {
                sfx.volume = Float(5)
                sfx.play()
            }
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody?
        var gotADonut = false
        
        if contact.bodyA.node?.name == "whalePlayer" && contact.bodyB.node?.name == "donut" {
            firstBody = contact.bodyB
            gotADonut = true
        } else if contact.bodyA.node?.name == "donut" && contact.bodyB.node?.name == "whalePlayer" {
            firstBody = contact.bodyA
            gotADonut = true
        } else if contact.bodyA.node?.name == "whalePlayer" && (contact.bodyB.node?.name != "landLeft" &&  contact.bodyB.node?.name != "landRight") {
            firstBody = contact.bodyA
        } else if contact.bodyB.node?.name == "whalePlayer" && (contact.bodyA.node?.name != "landLeft" &&  contact.bodyA.node?.name != "landRight") {
            firstBody = contact.bodyB
        } else {
            firstBody = nil // Player hit the land, so nothing happens
        }
        
        if let bodyToRemove = firstBody {
            bodyToRemove.node?.removeFromParent()
        
            if !gotADonut { // Player hit a tree
                playSoundEffects(soundName: "demage-sound", type: ".mp3")
                
                maxScore = ScoreType.highScore
                if maxScore < calcScore {
                    ScoreType.highScore = calcScore
                }
                
                if let player = audioPlayer {
                    player.stop()
                }
                afterCollision()
            } else { // Player got a donut
                playSoundEffects(soundName: "coin-sound", type: ".mp3")
                
                calcScore += 50
                updateScoreText()
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            
            if joystickBtn.frame.contains(location) {
                joystickInUse = true
            } else {
                joystickInUse = false
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        for touch in touches {
//            let location = touch.location(in: self)
//
//            if location.x <= lakeBorderR && location.x >= lakeBorderL {
//                whalePlayer.position.x = location.x
//            }
//            whalePlayer.position.y = location.y
//        }
        
        for touch in touches {
            let location = touch.location(in: self)
            
            if joystickInUse {
                let vector = CGVector(dx: location.x - joystickBack.position.x, dy: location.y - joystickBack.position.y)
                
                let angle = atan2(vector.dy, vector.dx)
                
                let distanceFromCenter = CGFloat(joystickBack.frame.size.height/2)
                
                let distanceX = CGFloat(sin((angle - CGFloat(M_PI/2)) + distanceFromCenter))
                let distanceY = CGFloat(cos((angle - CGFloat(M_PI/2)) + distanceFromCenter))
                
                if joystickBack.frame.contains(location) {
                    joystickBtn.position = location
                } else {
                    joystickBtn.position = CGPoint(x: joystickBack.position.x - distanceX, y: joystickBack.position.y - distanceY)
                }
                
                velocityX = (joystickBtn.position.x - joystickBack.position.x)/7
                velocityY = (joystickBtn.position.y - joystickBack.position.y)/7
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        movementOver()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        movementOver()
    }
    
    func movementOver() {
        let moveBack = SKAction.move(to: CGPoint(x: joystickBack.position.x, y: joystickBack.position.y), duration: TimeInterval(0.1))
        moveBack.timingMode = .linear
        joystickBtn.run(moveBack)
        joystickInUse = false
        velocityY = 0
        velocityX = 0
    }
    
    @objc func createLakeWave() {
        let lakeWave = SKShapeNode(ellipseOf: CGSize(width: 80, height: 10))
        lakeWave.strokeColor = SKColor.white
        lakeWave.fillColor = SKColor.white
        lakeWave.alpha = 0.5
        lakeWave.name = "lakeWave"
        
        let randomNum = Int.random(in: 1...3)
        switch randomNum {
        case 1:
            lakeWave.position.x = 50
        case 2:
            lakeWave.position.x = -50
        case 3:
            lakeWave.position.x = 0
        default:
            lakeWave.position.x = 0
        }
        
        lakeWave.position.y = lakeMaxY
        addChild(lakeWave)
    }
    
    func enumerateChildNodes(objectName: String, objectVelocity: CGFloat) {
        enumerateChildNodes(withName: objectName, using: { (objectChildNode, stop) in
            let object = objectChildNode as! SKSpriteNode
            object.position.y -= objectVelocity
        })
    }
    
    func showGameObjects() {
        enumerateChildNodes(withName: "lakeWave", using: { (lakeWave, stop) in
          let wave = lakeWave as! SKShapeNode
            wave.position.y -= 20 + CGFloat(self.timePassed/10)
            
            let randomNum = Int.random(in: 1...2)
            if randomNum == 1 {
                wave.position.x -= 5
            }
            if randomNum == 2 {
                wave.position.x += 5
            }
        })
        
        enumerateChildNodes(objectName: "smallTreeR", objectVelocity: self.velocity + CGFloat(self.timePassed/10))
        enumerateChildNodes(objectName: "smallTreeL", objectVelocity: self.velocity + CGFloat(self.timePassed/10))
        enumerateChildNodes(objectName: "mediumTreeR", objectVelocity: self.velocity + CGFloat(self.timePassed/10))
        enumerateChildNodes(objectName: "mediumTreeL", objectVelocity: self.velocity + CGFloat(self.timePassed/10))
        enumerateChildNodes(objectName: "donut", objectVelocity: self.velocity + CGFloat(self.timePassed/10))
    }
    
    @objc func treeObstacles() {
        let randomNumber = Int.random(in: 1...50)
        
        switch randomNumber {
        case 1...5:
            createTree(treeName: "smallTreeR", treeImgName: "treeShortRight", widthSize: CGFloat(110), positionX: nil, calcPositionX: true)
            break
        case 6...10:
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: nil, calcPositionX: true)
            break
        case 11...15:
            createTree(treeName: "mediumTreeR", treeImgName: "treeMediumRight", widthSize: CGFloat(300), positionX: nil, calcPositionX: true)
            break
        case 16...20:
            createTree(treeName: "smallTreeR", treeImgName: "treeShortRight", widthSize: CGFloat(110), positionX: lakeMaxX - CGFloat(110)/2, calcPositionX: false)
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: lakeMinX + CGFloat(110)/2, calcPositionX: false)
            break
        case 21...25:
            createTree(treeName: "smallTreeR", treeImgName: "treeShortRight", widthSize: CGFloat(110), positionX: lakeMaxX - CGFloat(110)/2, calcPositionX: false)
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: 0, calcPositionX: false)
            break
        case 22...30:
            createTree(treeName: "smallTreeR", treeImgName: "treeShortRight", widthSize: CGFloat(110), positionX: 0, calcPositionX: false)
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: lakeMinX + CGFloat(110)/2, calcPositionX: false)
            break
        case 31...35:
            createTree(treeName: "smallTreeR", treeImgName: "treeShortRight", widthSize: CGFloat(110), positionX: lakeMaxX - CGFloat(110)/2, calcPositionX: false)
            createTree(treeName: "mediumTreeL", treeImgName: "treeMediumLeft", widthSize: CGFloat(300), positionX: lakeMinX + CGFloat(300)/2, calcPositionX: false)
            break
        case 36...40:
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: lakeMinX + CGFloat(110)/2, calcPositionX: false)
            createTree(treeName: "mediumTreeR", treeImgName: "treeMediumRight", widthSize: CGFloat(300), positionX: lakeMaxX - CGFloat(300)/2, calcPositionX: false)
            break
        case 41...45:
            createTree(treeName: "smallTreeR", treeImgName: "treeShortRight", widthSize: CGFloat(110), positionX: lakeMaxX - CGFloat(110)/2, calcPositionX: false)
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: 0, calcPositionX: false)
            createTree(treeName: "smallTreeL", treeImgName: "treeShortLeft", widthSize: CGFloat(110), positionX: lakeMinX + CGFloat(110)/2, calcPositionX: false)
            break
        default:
            createTree(treeName: "mediumTreeL", treeImgName: "treeMediumLeft", widthSize: CGFloat(300), positionX: nil, calcPositionX: true)
            break
        }
    }
    
    func createTree(treeName: String, treeImgName: String, widthSize: CGFloat, positionX: CGFloat?, calcPositionX: Bool){
        let tree: SKSpriteNode!
        
        tree = SKSpriteNode(texture: SKTexture.init(imageNamed: treeImgName))
        tree.name = treeName
        tree.size.height = 60
        tree.size.width = widthSize
        
        if calcPositionX {
            let randomN = Int.random(in: 1...15)
            switch randomN {
            case 1...5:
                if treeName.range(of: "R") != nil {
                    tree.position.x = lakeMaxX - widthSize/2
                } else if treeName.range(of: "L") != nil {
                    tree.position.x = lakeMinX + widthSize/2
                }
            case 6...10:
                if treeName.range(of: "R") != nil && treeName.range(of: "small") != nil {
                    tree.position.x = lakeMaxX - widthSize/2 - whalePlayer.size.width - CGFloat(randomN)*10
                } else if treeName.range(of: "L") != nil && treeName.range(of: "small") != nil {
                    tree.position.x = lakeMinX + widthSize/2 + whalePlayer.size.width + CGFloat(randomN)*10
                } else {
                    fallthrough
                }
            default:
                tree.position.x = 0
            }
        } else {
            tree.position.x = positionX!
        }
        
        tree.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        tree.position.y = lakeMaxY
        
        tree.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: (tree.size.width - 20), height: (tree.size.height - 20)))
        tree.physicsBody?.categoryBitMask = ColliderType.ITEM_COLLIDER
        tree.physicsBody?.collisionBitMask = 0
        tree.physicsBody?.affectedByGravity = false
        
        addChild(tree)
    }
    
    @objc func createDonut() {
        let donutPrize = SKSpriteNode(texture: SKTexture(imageNamed: "donut"))
        donutPrize.size.width = 50
        donutPrize.size.height = 50
        donutPrize.name = "donut"
        
        let randomN = Int.random(in: 1...15)
        switch randomN {
        case 1...5:
            donutPrize.position.x = lakeMinX + donutPrize.size.width
        case 6...10:
            donutPrize.position.x = lakeMaxX - donutPrize.size.width
        default:
            donutPrize.position.x = 0
        }
        
        donutPrize.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        donutPrize.position.y = lakeMaxY + donutPrize.size.height + 10
        
        donutPrize.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: (donutPrize.size.width - 20), height: (donutPrize.size.height - 20)))
        donutPrize.physicsBody?.categoryBitMask = ColliderType.ITEM_COLLIDER
        donutPrize.physicsBody?.collisionBitMask = 0
        donutPrize.physicsBody?.affectedByGravity = false
        
        addChild(donutPrize)
    }
    
    func removeItems() {
        for child in children {
            if child.position.y < -self.size.height - 100 {
                child.removeFromParent()
                calcScore += 1
            }
        }
    }
    
    func afterCollision() {
        if let menuScene = SKScene(fileNamed: "GameMenu") {
            menuScene.scaleMode = .aspectFill
            view?.presentScene(menuScene, transition: SKTransition.moveIn(with: SKTransitionDirection.right, duration: TimeInterval(0.5)))
        }
    }
}
