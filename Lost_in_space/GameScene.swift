import SpriteKit
import AVFoundation
import UIKit

// MARK: - Global Constants for Naming
let OBSTACLE_NAME_PREFIX = "GAME_OBSTACLE_"

extension Notification.Name {
    static let UserChoseToEndRun = Notification.Name("UserChoseToEndRun")
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Constants
    let rocketCategory: UInt32 = 0x1 << 0
    let astronautCategory: UInt32 = 0x1 << 1
    let obstacleCategory: UInt32 = 0x1 << 2
    let normalObstacleCategory: UInt32 = 0x1 << 3
    let gravityFieldAffectsRocketCategory: UInt32 = 0x1 << 4

    // MARK: - Audio Properties
    var successSound: AVAudioPlayer?
    var gameOverSound: AVAudioPlayer?
    var sfxVolume: Float = UserDefaults.standard.float(forKey: "sfxVolume")
    var musicVolume: Float = UserDefaults.standard.float(forKey: "musicVolume")

    // MARK: - Game Properties
    let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    var astronautContactNode: SKNode?
    var astronautSprite: SKSpriteNode?
    var astronautAttachmentJoint: SKPhysicsJoint?
    var isAstronautAttached: Bool = false

    var levelToLoadOnAppear: Int = 1
    var level = 1

    var onLevelSuccessfullyCompleted: ((_ starsEarnedThisLevel: Int, _ completedLevelNumber: Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onTimerUpdate: ((Int) -> Void)?

    var levelTimer: Timer?
    var timeRemaining: TimeInterval = 15.0
    let levelDuration: TimeInterval = 15.0
    var fadeTransitionDuration: TimeInterval = 0.3
    var gravityAngle: CGFloat = 0.0
    var backgroundNode: SKSpriteNode?
    var isPausedGame = false // GameScene's internal pause state
    var gameOver = false

    var initialImpulsesToApply: [(node: SKSpriteNode, impulse: CGVector)] = []


    enum SpawnCorner: Int, CaseIterable, CustomStringConvertible {
        case bottomLeft = 1
        case bottomRight = 2
        case topRight = 3
        case topLeft = 4

        var description: String {
            switch self {
            case .bottomLeft: return "Bottom-Left"
            case .bottomRight: return "Bottom-Right"
            case .topRight: return "Top-Right"
            case .topLeft: return "Top-Left"
            }
        }
    }
    var rocketSpawnLocation: SpawnCorner = .bottomLeft
    static var currentSpawnCornerIndex: Int = 0


    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        self.level = self.levelToLoadOnAppear
        print("GameScene didMove. Initializing for Level: \(self.level)")

        musicVolume = Float(UserDefaults.standard.double(forKey: "musicVolume"))
        sfxVolume = Float(UserDefaults.standard.double(forKey: "sfxVolume"))

        physicsWorld.contactDelegate = self
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)
        physicsWorld.gravity = .zero
        
        setupObservers()
        setupSounds()
        setupBackground()
        setupPhysicsBounds()
        setupLevelElements()
        
        physicsWorld.speed = 0.4
        
       
        
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        if !isPausedGame && !gameOver {
            if let rocketBody = childNode(withName: "rocketNode")?.physicsBody, rocketBody.isDynamic {
                 updateRocketOrientationAndSpeed()
            }

            if isAstronautAttached, let contactNodePos = astronautContactNode?.position {
                astronautSprite?.position = contactNodePos
            }

            let maxObstacleSpeed: CGFloat = 150.0
            for node in children {
                if let obstacleName = node.name,
                   obstacleName.hasPrefix(OBSTACLE_NAME_PREFIX),
                   obstacleName.contains("_Moving_"),
                   let obstacleBody = node.physicsBody, obstacleBody.isDynamic {
                    
                    let velocity = obstacleBody.velocity
                    let currentSpeed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)

                    if currentSpeed > maxObstacleSpeed {
                        let scale = maxObstacleSpeed / currentSpeed
                        obstacleBody.velocity = CGVector(dx: velocity.dx * scale, dy: velocity.dy * scale)
                    }
                }
            }
        }
    }

    deinit {
        levelTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        print("GameScene deinitialized for level: \(level)")
    }

    // MARK: - Setup Methods
    func setupObservers() {
        NotificationCenter.default.addObserver(forName: Notification.Name("VolumeChanged"), object: nil, queue: .main) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.musicVolume = Float(UserDefaults.standard.double(forKey: "musicVolume"))
            strongSelf.sfxVolume = Float(UserDefaults.standard.double(forKey: "sfxVolume"))
            strongSelf.successSound?.volume = strongSelf.sfxVolume
            strongSelf.gameOverSound?.volume = strongSelf.sfxVolume
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("TogglePause"), object: nil, queue: .main) { [weak self] notification in
            guard let strongSelf = self, let pauseState = notification.object as? Bool else { return }
            
            // Prevent unpausing if gameOver is true internally in GameScene (e.g. due to win condition)
            // unless the intent is to unpause for a new game state (which should be handled by full reset).
            if !pauseState && strongSelf.gameOver {
                print("GameScene: Attempted to unpause while GameScene.gameOver is true. Keeping paused.")
                // Ensure SKScene's isPaused reflects this if GameScene's internal gameOver is true
                if !strongSelf.isPaused { strongSelf.isPaused = true }
                return
            }
            
            strongSelf.isPausedGame = pauseState
            strongSelf.isPaused = pauseState // This controls SKScene's update loop and physics
            print("GameScene: Pause state set to \(pauseState). SKScene.isPaused: \(strongSelf.isPaused)")

            if pauseState {
                strongSelf.levelTimer?.invalidate()
            } else {
                if !strongSelf.gameOver { // Only resume if game not over
                    if strongSelf.action(forKey: "levelRevealSequence") == nil && strongSelf.timeRemaining > 0 &&
                       (strongSelf.levelTimer == nil || !(strongSelf.levelTimer?.isValid ?? false)) {
                        if strongSelf.childNode(withName: "rocketNode")?.physicsBody?.isDynamic == true {
                            strongSelf.startLevelCountdown()
                        }
                    }
                }
            }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name.UserChoseToEndRun, object: nil, queue: .main) { [weak self] _ in
            guard let strongSelf = self else { return }
            if !strongSelf.gameOver {
                strongSelf.gameOver = true
                strongSelf.isPaused = true // Pause the scene
                strongSelf.levelTimer?.invalidate()
                strongSelf.onGameOver?() // Notify ContentView
            }
        }
    }

    func setupBackground() {
        // ... (as before) ...
        backgroundNode?.removeFromParent()
        let backgroundIndex = max(1, (level - 1) % 10 + 1)
        let backgroundName = "background\(backgroundIndex).jpg"
        if let bgImage = UIImage(named: backgroundName) {
            let backgroundTexture = SKTexture(image: bgImage)
            backgroundTexture.filteringMode = .linear
            let background = SKSpriteNode(texture: backgroundTexture)
            let textureAspectRatio = backgroundTexture.size().width / backgroundTexture.size().height
            let sceneAspectRatio = size.width / size.height
            if textureAspectRatio >= sceneAspectRatio {
                background.size.height = size.height
                background.size.width = size.height * textureAspectRatio
            } else {
                background.size.width = size.width
                background.size.height = size.width / textureAspectRatio
            }
            background.size.width *= 1.02; background.size.height *= 1.02
            background.position = CGPoint(x: size.width / 2, y: size.height / 2)
            background.zPosition = -10
            background.name = "gameBackground"
            addChild(background)
            backgroundNode = background
        } else {
            print("⚠️ Background image '\(backgroundName)' missing!")
            self.backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)
        }
    }

    func setupPhysicsBounds() {
        // ... (as before) ...
        physicsBody = nil
        physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        physicsBody?.categoryBitMask = obstacleCategory
        physicsBody?.friction = 0.2
        physicsBody?.restitution = 0.4
    }

    func setupSounds() {
        

        if let successURL = Bundle.main.url(forResource: "success", withExtension: "mp3") {
            successSound = try? AVAudioPlayer(contentsOf: successURL)
            successSound?.prepareToPlay(); successSound?.volume = sfxVolume
        } else { print("⚠️ Success sound file 'success.mp3' missing!") }

        if let gameOverURL = Bundle.main.url(forResource: "gameover", withExtension: "mp3") {
            gameOverSound = try? AVAudioPlayer(contentsOf: gameOverURL)
            gameOverSound?.prepareToPlay(); gameOverSound?.volume = sfxVolume
        } else { print("⚠️ Game over sound file 'gameover.mp3' missing!") }
    }

    
    func playSuccessSound() {
        // ... (as before) ...
        successSound?.volume = sfxVolume
        if let player = successSound, !player.isPlaying {
            player.currentTime = 0; player.play()
        } else if successSound == nil { AudioServicesPlaySystemSound(1105) }
    }

    func playGameOverSound() {
        // ... (as before) ...
        gameOverSound?.volume = sfxVolume
        if let player = gameOverSound, !player.isPlaying {
            player.currentTime = 0; player.play()
        } else if gameOverSound == nil { AudioServicesPlaySystemSound(1073) }
    }

    func setupLevelElements() {
        print("GameScene: Setting up elements for internal level \(self.level)")
        levelTimer?.invalidate()
        timeRemaining = levelDuration
        onTimerUpdate?(Int(timeRemaining))

        self.removeAction(forKey: "levelRevealSequence")
        
        let oldContentNode = SKNode()
        children.filter { node in
            node.name != "gameBackground" &&
            node !== backgroundNode &&
            node.name != "astronautContact" &&
            node.name != "visibleAstronaut" &&
            node.name != "rocketNode" &&
            !(node.name?.hasPrefix(OBSTACLE_NAME_PREFIX) ?? false)
        }.forEach { node in
            node.removeFromParent()
            oldContentNode.addChild(node)
        }
        
        if !oldContentNode.children.isEmpty {
            addChild(oldContentNode)
            oldContentNode.run(SKAction.sequence([
                .fadeOut(withDuration: fadeTransitionDuration),
                .removeFromParent()
            ])) { [weak self] in
                self?.loadCurrentLevelContent()
            }
        } else {
            loadCurrentLevelContent()
        }
    }
    
    private func loadCurrentLevelContent() {
        print(">>> [DEBUG] Entering loadCurrentLevelContent for level \(self.level)")
        initialImpulsesToApply.removeAll()

        astronautContactNode?.removeFromParent()
        astronautSprite?.removeFromParent()
        childNode(withName: "rocketNode")?.removeFromParent()

        self.children.filter { $0.name?.hasPrefix(OBSTACLE_NAME_PREFIX) == true }.forEach {
            print(">>> [DEBUG] loadCurrentLevelContent: Removing old obstacle: \($0.name ?? "nil")")
            $0.removeFromParent()
        }

        astronautContactNode = nil
        astronautSprite = nil
        astronautAttachmentJoint = nil
        isAstronautAttached = false
        
        if backgroundNode == nil || backgroundNode?.parent == nil { setupBackground() }
        if self.physicsBody == nil { setupPhysicsBounds() }

        setupAstronautTarget()
        setupRocket()
        setupObstacles()

        let elementFadeInDuration: TimeInterval = 0.4
        let delayBetweenElements: TimeInterval = 0.3

        var actionsSequence: [SKAction] = []

        if let astronaut = self.astronautSprite {
            let fadeInAstronaut = SKAction.run {
                print(">>> [DEBUG] Fading in Astronaut (\(astronaut.name ?? "N/A"))")
                astronaut.run(SKAction.fadeIn(withDuration: elementFadeInDuration))
            }
            actionsSequence.append(fadeInAstronaut)
            actionsSequence.append(SKAction.wait(forDuration: elementFadeInDuration + delayBetweenElements))
        } else {
            print("⚠️ Astronaut sprite ('visibleAstronaut') not found for staggered appearance.")
            actionsSequence.append(SKAction.wait(forDuration: elementFadeInDuration + delayBetweenElements))
        }

        if let rocket = self.childNode(withName: "rocketNode") {
            let fadeInRocket = SKAction.run {
                print(">>> [DEBUG] Fading in Rocket (\(rocket.name ?? "N/A"))")
                rocket.run(SKAction.fadeIn(withDuration: elementFadeInDuration))
            }
            actionsSequence.append(fadeInRocket)
            actionsSequence.append(SKAction.wait(forDuration: elementFadeInDuration + delayBetweenElements))
        } else {
            print("⚠️ Rocket node ('rocketNode') not found for staggered appearance.")
            actionsSequence.append(SKAction.wait(forDuration: elementFadeInDuration + delayBetweenElements))
        }
        
        let obstacleNodesForFadeIn = self.children.filter { $0.name?.hasPrefix(OBSTACLE_NAME_PREFIX) == true }
        print(">>> [DEBUG] In loadCurrentLevelContent: Found \(obstacleNodesForFadeIn.count) obstacle nodes to fade in.")
        
        if !obstacleNodesForFadeIn.isEmpty {
            let fadeInIndividualObstaclesActions = obstacleNodesForFadeIn.map { obstacleNode -> SKAction in
                return SKAction.run {
                    if obstacleNode.name?.contains("Gravity") == true {
                        print(">>> [DEBUG] ACTION: Fading in GRAVITY OBSTACLE ('\(obstacleNode.name ?? "N/A")')")
                    }
                    obstacleNode.run(SKAction.fadeIn(withDuration: elementFadeInDuration))
                }
            }
            let groupFadeInObstacles = SKAction.group(fadeInIndividualObstaclesActions)
            actionsSequence.append(groupFadeInObstacles)
            actionsSequence.append(SKAction.wait(forDuration: elementFadeInDuration))
        } else {
             print(">>> [DEBUG] No obstacle nodes found to fade in for level \(self.level).")
             actionsSequence.append(SKAction.wait(forDuration: elementFadeInDuration))
        }

        let activatePhysicsAction = SKAction.run { [weak self] in
            guard let strongSelf = self else { return }
            print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Running...")

            if strongSelf.isPausedGame || strongSelf.gameOver {
                print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Skipped due to game paused or over.")
                return
            }

            strongSelf.startRotatingGravity()

            if let rocketNode = strongSelf.childNode(withName: "rocketNode"), let rocketBody = rocketNode.physicsBody {
                print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Activating rocket physics.")
                rocketBody.isDynamic = true
                rocketBody.affectedByGravity = true
            }

            print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Activating dynamic obstacles. Stored impulses: \(strongSelf.initialImpulsesToApply.count)")
            for item in strongSelf.initialImpulsesToApply {
                guard let obstacleNode = item.node as? SKSpriteNode, let obstacleBody = obstacleNode.physicsBody else {
                    print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Skipping impulse - node or body nil for \(item.node.name ?? "Unknown")")
                    continue
                }
                if obstacleNode.name?.contains("_Moving_") == true {
                    print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Activating and impulsing \(obstacleNode.name ?? "N/A")")
                    obstacleBody.isDynamic = true
                    obstacleBody.applyImpulse(item.impulse)
                } else {
                    obstacleBody.isDynamic = false
                    print(">>> [DEBUG] ACTIVATE PHYSICS ACTION: Obstacle \(obstacleNode.name ?? "N/A") is static.")
                }
            }
            strongSelf.initialImpulsesToApply.removeAll()
        }
        actionsSequence.append(SKAction.wait(forDuration: 0.2))
        actionsSequence.append(activatePhysicsAction)
        
        let startCountdownAction = SKAction.run { [weak self] in
            guard let strongSelf = self else { return }
            if !strongSelf.isPausedGame && !strongSelf.gameOver {
                print(">>> [DEBUG] Starting countdown timer after physics activation.")
                strongSelf.startLevelCountdown()
            } else {
                print(">>> [DEBUG] Skipping countdown timer start (paused or game over).")
            }
        }
        actionsSequence.append(SKAction.wait(forDuration: 0.1))
        actionsSequence.append(startCountdownAction)

        self.run(SKAction.sequence(actionsSequence), withKey: "levelRevealSequence")
        print(">>> [DEBUG] Started 'levelRevealSequence' (with physics activation) for level \(self.level).")
    }

    func startLevelCountdown() {
        print("Starting level countdown for level \(level). Time: \(timeRemaining)")
        levelTimer?.invalidate()
        guard !isPausedGame, !gameOver else {
            print("Countdown not started: game paused or over.")
            return
        }
        guard childNode(withName: "rocketNode")?.physicsBody?.isDynamic == true else {
            print("Countdown not started: physics not yet active.")
            return
        }
        
        onTimerUpdate?(Int(timeRemaining))
        
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let strongSelf = self else { timer.invalidate(); return }
            
            if strongSelf.isPausedGame { return }
            if strongSelf.gameOver { timer.invalidate(); return }

            strongSelf.timeRemaining -= 1
            strongSelf.onTimerUpdate?(Int(strongSelf.timeRemaining))
            
            if strongSelf.timeRemaining <= 0 {
                timer.invalidate()
                if !strongSelf.gameOver {
                    print("Level timeout for level \(strongSelf.level). Calling onGameOver.")
                    strongSelf.handleLevelTimeout()
                }
            }
        }
    }

    func setupRocket() {
        // ... (as before, with isDynamic=false, affectedByGravity=false) ...
        guard let rocketImageFile = UIImage(named: "rocket_image") else {
            print("⚠️ rocket_image.png missing from assets!"); return
        }
        let rocketTexture = SKTexture(image: rocketImageFile)

        let rocketSize = CGSize(width: 50, height: 100)
        let rocket = SKSpriteNode(texture: rocketTexture, size: rocketSize)
        rocket.name = "rocketNode"; rocket.zPosition = 2
        
        let padding: CGFloat = 40.0
        let halfRocketWidth = rocket.size.width / 2
        let halfRocketHeight = rocket.size.height / 2

        let topLeftPos = CGPoint(x: padding + halfRocketWidth, y: size.height - padding - halfRocketHeight)
        let topRightPos = CGPoint(x: size.width - padding - halfRocketWidth, y: size.height - padding - halfRocketHeight)
        let bottomRightPos = CGPoint(x: size.width - padding - halfRocketWidth, y: padding + halfRocketHeight)
        let bottomLeftPos = CGPoint(x: padding + halfRocketWidth, y: padding + halfRocketHeight)
        
        let allCorners = SpawnCorner.allCases
        let cornerToSpawn = allCorners[GameScene.currentSpawnCornerIndex % allCorners.count]
        self.rocketSpawnLocation = cornerToSpawn

        switch cornerToSpawn {
        case .topLeft: rocket.position = topLeftPos
        case .topRight: rocket.position = topRightPos
        case .bottomRight: rocket.position = bottomRightPos
        case .bottomLeft: rocket.position = bottomLeftPos
        }
        
        print("Rocket spawn (Level \(self.level), Index \(GameScene.currentSpawnCornerIndex)): \(self.rocketSpawnLocation.description)")
        GameScene.currentSpawnCornerIndex += 1
        
        rocket.alpha = 0.0
        
        rocket.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: rocket.size.width * 0.3, height: rocket.size.height * 0.65))
        rocket.physicsBody?.usesPreciseCollisionDetection = true
        rocket.physicsBody?.categoryBitMask = rocketCategory
        rocket.physicsBody?.contactTestBitMask = astronautCategory | obstacleCategory
        rocket.physicsBody?.collisionBitMask = obstacleCategory
        rocket.physicsBody?.restitution = 0.2
        rocket.physicsBody?.friction = 0.3
        rocket.physicsBody?.linearDamping = 0.15
        rocket.physicsBody?.angularDamping = 0.9
        rocket.physicsBody?.mass = 0.5
        rocket.physicsBody?.allowsRotation = true
        rocket.physicsBody?.fieldBitMask = gravityFieldAffectsRocketCategory

        rocket.physicsBody?.isDynamic = false
        rocket.physicsBody?.affectedByGravity = false

        rocket.zRotation = 0
        addChild(rocket)
        print(">>> [DEBUG] Added rocketNode to scene. Initial isDynamic: false, affectedByGravity: false")
    }

    func setupAstronautTarget() {
        // ... (as before) ...
        let contactRadius: CGFloat = 18
        
        let newAstronautContactNode = SKNode()
        newAstronautContactNode.name = "astronautContact"
        newAstronautContactNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        
        newAstronautContactNode.physicsBody = SKPhysicsBody(circleOfRadius: contactRadius)
        newAstronautContactNode.physicsBody?.isDynamic = false
        newAstronautContactNode.physicsBody?.categoryBitMask = astronautCategory
        newAstronautContactNode.physicsBody?.contactTestBitMask = rocketCategory | obstacleCategory
        newAstronautContactNode.physicsBody?.collisionBitMask = obstacleCategory
        
        addChild(newAstronautContactNode)
        self.astronautContactNode = newAstronautContactNode

        guard let astronautImgFile = UIImage(named: "astronaut_image") else {
            print("⚠️ astronaut_image.png missing from assets!"); return
        }
        let astronautTexture = SKTexture(image: astronautImgFile)
        let newVisibleAstronaut = SKSpriteNode(texture: astronautTexture, size: CGSize(width: 28, height: 42))
        newVisibleAstronaut.position = newAstronautContactNode.position
        newVisibleAstronaut.name = "visibleAstronaut"
        newVisibleAstronaut.zPosition = 1
        newVisibleAstronaut.alpha = 0.0
        
        addChild(newVisibleAstronaut)
        self.astronautSprite = newVisibleAstronaut
        print(">>> [DEBUG] Added astronautContact & visibleAstronaut to scene. Alpha: \(newVisibleAstronaut.alpha)")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPausedGame || gameOver { return }
        guard let rocket = childNode(withName: "rocketNode") as? SKSpriteNode,
              let rocketBody = rocket.physicsBody,
              rocketBody.isDynamic else {
            return
        }
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let dx = location.x - rocket.position.x
        let dy = location.y - rocket.position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 10 else { return }

        let maxPullDistance: CGFloat = 120
        let normalizedDistance = min(distance, maxPullDistance) / maxPullDistance
        let baseForce: CGFloat = 80.0
        let impulseMagnitude = normalizedDistance * baseForce * (rocketBody.mass > 0 ? rocketBody.mass : 1.0)
        
        rocketBody.applyImpulse(CGVector(dx: (dx / distance) * impulseMagnitude, dy: (dy / distance) * impulseMagnitude))
        hapticFeedback.impactOccurred(intensity: 0.7)
    }

    // MARK: - SKPhysicsContactDelegate
    func didBegin(_ contact: SKPhysicsContact) {
           if gameOver { return } // Already processing or game ended

           let bodyA = contact.bodyA
           let bodyB = contact.bodyB
           let nodeA = bodyA.node
           let nodeB = bodyB.node
           
           let isRocketAstronautContact =
               (bodyA.categoryBitMask == rocketCategory && bodyB.categoryBitMask == astronautCategory) ||
               (bodyA.categoryBitMask == astronautCategory && bodyB.categoryBitMask == rocketCategory)

           if isRocketAstronautContact {
               let astronautNodeInstance = (bodyA.categoryBitMask == astronautCategory) ? nodeA : nodeB
               let rocketNodeInstance = (bodyA.categoryBitMask == rocketCategory) ? nodeA : nodeB
               
               // Ensure contact involves the main astronaut target and the rocket is active
               if astronautNodeInstance === astronautContactNode && rocketNodeInstance?.physicsBody?.isDynamic == true {
                   if !gameOver { // Process only once
                       gameOver = true // Set internal flag to prevent re-triggering this block
                       // DO NOT set self.isPaused = true here. Let ContentView handle pausing after animation.

                       levelTimer?.invalidate() // Stop the level timer

                       // --- STOP THE ROCKET IMMEDIATELY ---
                       if let rocket = rocketNodeInstance as? SKSpriteNode, let rocketBody = rocket.physicsBody {
                           print(">>> [DEBUG] Rocket-Astronaut contact: Stopping rocket's physics.")
                           rocketBody.isDynamic = false
                           rocketBody.velocity = .zero
                           rocketBody.angularVelocity = 0
                           rocket.removeAllActions() // Stop any other actions on the rocket itself
                       }
                       // --- END STOP ROCKET ---
                       
                       if isAstronautAttached, let joint = astronautAttachmentJoint {
                           physicsWorld.remove(joint)
                           astronautAttachmentJoint = nil
                           isAstronautAttached = false
                           astronautContactNode?.physicsBody?.isDynamic = false
                       }
                       
                       var starsEarned = 0
                       let percentageTimeRemaining = max(0, timeRemaining / levelDuration)
                       if percentageTimeRemaining >= 0.8 { starsEarned = 5 }
                       else if percentageTimeRemaining >= 0.6 { starsEarned = 4 }
                       else if percentageTimeRemaining >= 0.4 { starsEarned = 3 }
                       else if percentageTimeRemaining >= 0.2 { starsEarned = 2 }
                       else if percentageTimeRemaining > 0 { starsEarned = 1 }
                       
                       let completedLevelNumber = self.level
                       
                       guard let actualRocketNode = rocketNodeInstance as? SKSpriteNode,
                             let actualAstronautSprite = self.astronautSprite else {
                           print("GameScene Error: Rocket or Collectible Astronaut sprite node not found for win animation.")
                           createSparkles(at: contact.contactPoint); hapticFeedback.impactOccurred(); playSuccessSound()
                           // Even if animation fails, call the completion handler
                           self.onLevelSuccessfullyCompleted?(starsEarned, completedLevelNumber)
                           return
                       }
                       
                       // Remove physics from astronaut elements to allow smooth animation
                       self.astronautContactNode?.physicsBody = nil
                       actualAstronautSprite.physicsBody = nil
                       
                       let targetPositionInScene = actualRocketNode.position
                       let moveAction = SKAction.move(to: targetPositionInScene, duration: 0.65)
                       moveAction.timingMode = .easeInEaseOut
                       let scaleAction = SKAction.scale(to: 0.05, duration: 0.65)
                       scaleAction.timingMode = .easeIn
                       let fadeOutAction = SKAction.fadeOut(withDuration: 0.60)
                       let groupAllActions = SKAction.group([moveAction, scaleAction, fadeOutAction])
                       let animationSequence = SKAction.sequence([groupAllActions, .removeFromParent()])
                       
                       createSparkles(at: actualRocketNode.position)
                       hapticFeedback.impactOccurred()
                       playSuccessSound() // Play success sound as animation starts
                       
                       print(">>> [DEBUG] Running astronaut collection animation.")
                       actualAstronautSprite.run(animationSequence) { [weak self] in
                           print(">>> [DEBUG] Astronaut collection animation complete. Calling onLevelSuccessfullyCompleted.")
                           // After animation, notify ContentView that the level is "successfully completed"
                           // ContentView will then handle pausing the GameScene and showing the banner.
                           self?.onLevelSuccessfullyCompleted?(starsEarned, completedLevelNumber)
                       }
                   }
                   return // Contact processed
               }
           }


        if !gameOver && !isAstronautAttached {
            // ... (sticky obstacle logic as before) ...
            var stickyObstacleNodeInstance: SKNode?
            var astronautTargetNodeInstance: SKNode?
            
            let nodeAName = nodeA?.name ?? ""
            let nodeBName = nodeB?.name ?? ""

            if bodyA.categoryBitMask == astronautCategory && nodeA === astronautContactNode &&
               bodyB.categoryBitMask == obstacleCategory && (nodeBName.contains("Sticky") || nodeBName.contains("sticky")) {
                astronautTargetNodeInstance = nodeA
                stickyObstacleNodeInstance = nodeB
            }
            else if bodyB.categoryBitMask == astronautCategory && nodeB === astronautContactNode &&
                    bodyA.categoryBitMask == obstacleCategory && (nodeAName.contains("Sticky") || nodeAName.contains("sticky")) {
                astronautTargetNodeInstance = nodeB
                stickyObstacleNodeInstance = nodeA
            }
            
            if let actualAstronautTargetNode = astronautTargetNodeInstance,
               let actualStickyObstacle = stickyObstacleNodeInstance,
               let astronautTargetBody = actualAstronautTargetNode.physicsBody,
               let stickyObstacleBody = actualStickyObstacle.physicsBody,
               (stickyObstacleBody.isDynamic || astronautTargetBody.isDynamic) { // Check if either interacting body is dynamic
                
                print(">>> [DEBUG] Astronaut target contacted STICKY obstacle: \(actualStickyObstacle.name ?? "N/A")")
                
                astronautTargetBody.isDynamic = true
                astronautTargetBody.affectedByGravity = false
                astronautTargetBody.mass = 0.01
                
                guard astronautTargetBody.node?.scene != nil && stickyObstacleBody.node?.scene != nil else {
                    print("Error: Nodes for joint not in scene. Astronaut target body dynamic state reverted.")
                    astronautTargetBody.isDynamic = false
                    return
                }
                
                let joint = SKPhysicsJointFixed.joint(withBodyA: astronautTargetBody,
                                                      bodyB: stickyObstacleBody,
                                                      anchor: contact.contactPoint)
                physicsWorld.add(joint)
                astronautAttachmentJoint = joint
                isAstronautAttached = true
                print(">>> [DEBUG] Astronaut attached to sticky obstacle via joint.")
            }
        }
    }


    func handleLevelTimeout() {
        if gameOver { return }
        gameOver = true
        self.isPausedGame = true // Set GameScene's internal flag
        self.isPaused = true     // Set SKScene's pause flag
        playGameOverSound()
        onGameOver?()
    }

    func startRotatingGravity() {
        guard !isPausedGame, !gameOver else {
            print("startRotatingGravity: Skipped due to game paused or over. World gravity remains .zero")
            physicsWorld.gravity = .zero
            removeAction(forKey: "gravityRotation")
            return
        }

        print("Starting rotating gravity for level \(level). Rocket spawned at: \(self.rocketSpawnLocation.description)")
        removeAction(forKey: "gravityRotation")
        
        let rotationSpeed: CGFloat = .pi / 10
        let gravityMagnitude: CGFloat = 3.0

        switch self.rocketSpawnLocation {
        case .bottomLeft: self.gravityAngle = (5 * .pi) / 4
        case .bottomRight: self.gravityAngle = (7 * .pi) / 4
        case .topRight: self.gravityAngle = .pi / 4
        case .topLeft: self.gravityAngle = (3 * .pi) / 4
        }
        print("Initial gravity for \(self.rocketSpawnLocation.description): Angle \(self.gravityAngle * 180 / .pi) degrees")
        
        self.physicsWorld.gravity = CGVector(dx: cos(self.gravityAngle) * gravityMagnitude,
                                             dy: sin(self.gravityAngle) * gravityMagnitude)
        if let bg = backgroundNode {
            bg.run(SKAction.rotate(toAngle: self.gravityAngle, duration: 0.1))
        }
        
        let rotateAction = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { [weak self] in
                guard let strongSelf = self, !strongSelf.isPausedGame, !strongSelf.gameOver else {
                    // If SKScene.isPaused is true, this block won't run anyway.
                    // But if internal isPausedGame is true, we also stop.
                    return
                }
                
                let angleIncrement = rotationSpeed * (1.0 / 60.0)
                strongSelf.gravityAngle += angleIncrement
                
                if strongSelf.gravityAngle >= .pi * 2 { strongSelf.gravityAngle -= .pi * 2 }
                else if strongSelf.gravityAngle < 0 { strongSelf.gravityAngle += .pi * 2 }
                
                strongSelf.physicsWorld.gravity = CGVector(dx: cos(strongSelf.gravityAngle) * gravityMagnitude,
                                                           dy: sin(strongSelf.gravityAngle) * gravityMagnitude)
                strongSelf.backgroundNode?.run(SKAction.rotate(toAngle: strongSelf.gravityAngle, duration: 1/60.0, shortestUnitArc: true))
            },
            SKAction.wait(forDuration: 1/60.0)
        ]))
        run(rotateAction, withKey: "gravityRotation")
    }

    func createSparkles(at position: CGPoint?) {
        // ... (as before) ...
        guard let pos = position, let emitter = SKEmitterNode(fileNamed: "ScoreSparkles.sks") else {
            print("⚠️ ScoreSparkles.sks emitter file missing or position nil.")
            return
        }
        emitter.position = pos
        emitter.zPosition = 10
        addChild(emitter)
        let lifetime = TimeInterval(emitter.particleLifetime + emitter.particleLifetimeRange)
        emitter.run(SKAction.sequence([
            .wait(forDuration: lifetime + 0.5),
            .removeFromParent()
        ]))
    }

    func updateRocketOrientationAndSpeed() {
        guard let rocket = childNode(withName: "rocketNode") as? SKSpriteNode, let rocketBody = rocket.physicsBody else { return }
        
        if let targetPosition = astronautContactNode?.position {
            let angle = atan2(targetPosition.y - rocket.position.y, targetPosition.x - rocket.position.x)
            rocket.run(SKAction.rotate(toAngle: angle - .pi/2, duration: 0.08, shortestUnitArc: true))
        }
        
        let maxSpeed: CGFloat = 300.0
        let velocity = rocketBody.velocity
        let currentSpeed = sqrt(velocity.dx*velocity.dx + velocity.dy*velocity.dy)
        if currentSpeed > maxSpeed {
            let scale = maxSpeed / currentSpeed
            rocketBody.velocity.dx *= scale
            rocketBody.velocity.dy *= scale
        }
    }
}

// MARK: - Obstacle Setup Extension
extension GameScene {
    func setupObstacles() {
        initialImpulsesToApply.removeAll()

        let obstacleCount = min(10, level + 1)
        guard obstacleCount > 0, let astronautTargetPos = astronautContactNode?.position else {
            print(">>> [DEBUG] No obstacles to setup (count: \(obstacleCount)) or astronaut target missing.")
            return
        }
        print(">>> [DEBUG] Setting up \(obstacleCount) obstacles for level \(level).")

        let columns = 4; let rows = 5
        let availableWidth = size.width * 0.9
        let availableHeight = size.height * 0.60
        let cellWidth = availableWidth / CGFloat(columns)
        let cellHeight = availableHeight / CGFloat(rows)
        let startX = (size.width - availableWidth) / 2
        let startY = (size.height - availableHeight) / 2 + (size.height * 0.05)

        var occupiedCells = Set<String>()
        var existingObstacleFrames: [CGRect] = []
        let generalSafeZonePadding: CGFloat = 20
        let astronautSafeRadius: CGFloat = 90

        existingObstacleFrames.append(CGRect(
            x: astronautTargetPos.x - astronautSafeRadius, y: astronautTargetPos.y - astronautSafeRadius,
            width: astronautSafeRadius * 2, height: astronautSafeRadius * 2
        ).insetBy(dx: -generalSafeZonePadding, dy: -generalSafeZonePadding))

        if let rocketNode = childNode(withName: "rocketNode"), let rocketNodePosition = rocketNode.position as CGPoint? {
            let rocketSafeRadius: CGFloat = 100
            existingObstacleFrames.append(CGRect(
                x: rocketNodePosition.x - rocketSafeRadius, y: rocketNodePosition.y - rocketSafeRadius,
                width: rocketSafeRadius * 2, height: rocketSafeRadius * 2
            ).insetBy(dx: -generalSafeZonePadding, dy: -generalSafeZonePadding))
        }

        enum ObstacleTypeInternal: CaseIterable {
            // ... (enum as before) ...
            case normal, sticky, bouncy, gravity
            var imageName: String {
                switch self {
                case .normal: return "normal_obstacle"
                case .sticky: return "sticky_obstacle"
                case .bouncy: return "bouncy_obstacle"
                case .gravity: return "gravity_obstacle"
                }
            }
            var uniqueNamePart: String {
                switch self {
                case .normal: return "Normal"
                case .sticky: return "Sticky"
                case .bouncy: return "Bouncy"
                case .gravity: return "Gravity"
                }
            }
        }

        var obstaclesPlaced = 0
        for placementAttempt in 0..<(obstacleCount * 15) {
            if obstaclesPlaced >= obstacleCount { break }
            // ... (obstacle placement logic as before, ensuring isDynamic=false initially and storing impulses) ...
            let col = Int.random(in: 0..<columns); let row = Int.random(in: 0..<rows)
            let cellKey = "\(col)-\(row)"
            if occupiedCells.contains(cellKey) { continue }

            let cellPadding: CGFloat = 10
            let posX = startX + (CGFloat(col) * cellWidth) + CGFloat.random(in: cellPadding...(cellWidth - cellPadding))
            let posY = startY + (CGFloat(row) * cellHeight) + CGFloat.random(in: cellPadding...(cellHeight - cellPadding))

            let minRadius: CGFloat = 28.0
            let maxRadiusBase: CGFloat = 49.0
            let levelBonusRadius: CGFloat = min(15.0, CGFloat(level) * 2.0)
            let maxPossibleRadius = maxRadiusBase + levelBonusRadius
            let radius = CGFloat.random(in: minRadius...max(minRadius + 1, maxPossibleRadius))
            let obstacleFrame = CGRect(x: posX - radius, y: posY - radius, width: radius * 2, height: radius * 2)

            var overlap = false
            for frame in existingObstacleFrames { if frame.intersects(obstacleFrame) { overlap = true; break } }
            if overlap { continue }

            let edgeScreenPadding: CGFloat = radius + 5
            if obstacleFrame.minX < edgeScreenPadding || obstacleFrame.maxX > size.width - edgeScreenPadding ||
               obstacleFrame.minY < edgeScreenPadding || obstacleFrame.maxY > size.height - edgeScreenPadding {
                continue
            }

            let typeWeights: [ObstacleTypeInternal: Int] = [
                .normal: max(4 - level / 3, 1),
                .sticky: min(level / 2 + 1, 3),
                .bouncy: min(level / 2 + 1, 3),
                .gravity: min(level / 3, 2)
            ]
            var weightedTypes: [ObstacleTypeInternal] = []
            typeWeights.forEach { type, weight in
                weightedTypes.append(contentsOf: Array(repeating: type, count: max(1, weight)))
            }
            guard let obstacleType = weightedTypes.randomElement() else { continue }
            guard let obstacleUiImage = UIImage(named: obstacleType.imageName) else { continue }
            let obstacleTexture = SKTexture(image: obstacleUiImage)
            let obstacleNode = SKSpriteNode(texture: obstacleTexture)

            let imageOriginalSize = obstacleTexture.size()
            if imageOriginalSize.width == 0 || imageOriginalSize.height == 0 {
                print("⚠️ Texture for \(obstacleType.imageName) loaded with zero size.")
                continue
            }
            let targetSize = CGSize(width: radius * 2, height: radius * 2)
            let textureAspectRatio = imageOriginalSize.width / imageOriginalSize.height
            let targetAspectRatio = targetSize.width / targetSize.height
            var newWidth: CGFloat
            var newHeight: CGFloat
            if textureAspectRatio > targetAspectRatio {
                newHeight = targetSize.height
                newWidth = newHeight * textureAspectRatio
            } else {
                newWidth = targetSize.width
                newHeight = newWidth / textureAspectRatio
            }
            obstacleNode.size = CGSize(width: newWidth, height: newHeight)


            obstacleNode.physicsBody = SKPhysicsBody(circleOfRadius: radius)
            obstacleNode.physicsBody?.isDynamic = false
            obstacleNode.physicsBody?.affectedByGravity = false

            obstacleNode.position = CGPoint(x: posX, y: posY); obstacleNode.zPosition = 0
            obstacleNode.alpha = 0.0
            var statusSuffix = "Static"

            switch obstacleType {
            case .normal:
                statusSuffix = "Moving"
                obstacleNode.physicsBody?.categoryBitMask = obstacleCategory | normalObstacleCategory
                obstacleNode.physicsBody?.collisionBitMask = obstacleCategory | rocketCategory
                obstacleNode.physicsBody?.contactTestBitMask = rocketCategory
                obstacleNode.physicsBody?.allowsRotation = true
                obstacleNode.physicsBody?.friction = 0.1; obstacleNode.physicsBody?.restitution = 0.8
                obstacleNode.physicsBody?.linearDamping = 0.05; obstacleNode.physicsBody?.angularDamping = 0.1
                obstacleNode.physicsBody?.mass = 0.7
                obstacleNode.physicsBody?.fieldBitMask = 0
                let initialVelocityMagnitude = 50.0 + CGFloat.random(in: -10.0...10.0)
                let randomAngle = CGFloat.random(in: 0...(2 * .pi))
                let velocityVector = CGVector(dx: cos(randomAngle) * initialVelocityMagnitude, dy: sin(randomAngle) * initialVelocityMagnitude)
                if let mass = obstacleNode.physicsBody?.mass, mass > 0 {
                    let impulse = CGVector(dx: velocityVector.dx * mass, dy: velocityVector.dy * mass)
                    initialImpulsesToApply.append((node: obstacleNode, impulse: impulse))
                }
            
            case .sticky:
                obstacleNode.physicsBody?.categoryBitMask = obstacleCategory
                obstacleNode.physicsBody?.collisionBitMask = obstacleCategory | rocketCategory | astronautCategory
                obstacleNode.physicsBody?.contactTestBitMask = astronautCategory
                obstacleNode.physicsBody?.allowsRotation = false
                obstacleNode.physicsBody?.friction = 0.99; obstacleNode.physicsBody?.restitution = 0.0
                obstacleNode.physicsBody?.linearDamping = 0.1; obstacleNode.physicsBody?.angularDamping = 1.0
                obstacleNode.physicsBody?.mass = 0.4
                obstacleNode.physicsBody?.fieldBitMask = 0
                if Int.random(in: 0..<3) == 0 {
                    statusSuffix = "Static"
                } else {
                    statusSuffix = "Moving"
                    let initialVelocityMagnitude = 80.0 + CGFloat.random(in: -15.0...15.0)
                    let randomAngle = CGFloat.random(in: 0...(2 * .pi))
                    let velocityVector = CGVector(dx: cos(randomAngle) * initialVelocityMagnitude, dy: sin(randomAngle) * initialVelocityMagnitude)
                    if let mass = obstacleNode.physicsBody?.mass, mass > 0 {
                        let impulse = CGVector(dx: velocityVector.dx * mass, dy: velocityVector.dy * mass)
                        initialImpulsesToApply.append((node: obstacleNode, impulse: impulse))
                    }
                }

            case .bouncy:
                statusSuffix = "Moving"
                obstacleNode.physicsBody?.categoryBitMask = obstacleCategory | normalObstacleCategory
                obstacleNode.physicsBody?.collisionBitMask = obstacleCategory | rocketCategory
                obstacleNode.physicsBody?.contactTestBitMask = rocketCategory
                obstacleNode.physicsBody?.allowsRotation = true
                obstacleNode.physicsBody?.restitution = 1.35; obstacleNode.physicsBody?.friction = 0.01
                obstacleNode.physicsBody?.linearDamping = 0.01; obstacleNode.physicsBody?.angularDamping = 0.02
                obstacleNode.physicsBody?.mass = 0.7
                obstacleNode.physicsBody?.fieldBitMask = 0
                let effectNode = SKEffectNode()
                if let filter = CIFilter(name: "CIBloom") {
                    filter.setValue(max(4, radius / 3.0), forKey: "inputRadius")
                    filter.setValue(0.7, forKey: "inputIntensity")
                    effectNode.filter = filter; effectNode.shouldRasterize = true
                    obstacleNode.addChild(effectNode)
                }
                let initialVelocityMagnitude = 25.0 + CGFloat.random(in: -5.0...5.0)
                let randomAngle = CGFloat.random(in: 0...(2 * .pi))
                let velocityVector = CGVector(dx: cos(randomAngle) * initialVelocityMagnitude, dy: sin(randomAngle) * initialVelocityMagnitude)
                if let mass = obstacleNode.physicsBody?.mass, mass > 0 {
                    let impulse = CGVector(dx: velocityVector.dx * mass, dy: velocityVector.dy * mass)
                    initialImpulsesToApply.append((node: obstacleNode, impulse: impulse))
                }
                
            case .gravity:
                statusSuffix = "Static"
                obstacleNode.physicsBody?.categoryBitMask = obstacleCategory
                obstacleNode.physicsBody?.fieldBitMask = 0
                let gravityFieldNode = SKFieldNode.radialGravityField()
                gravityFieldNode.strength = Float.random(in: 1.0...1.8)
                gravityFieldNode.falloff = Float.random(in: 0.5...1.2)
                gravityFieldNode.region = SKRegion(radius: Float(radius * Double.random(in: 4.0...6.0)))
                gravityFieldNode.categoryBitMask = gravityFieldAffectsRocketCategory
                obstacleNode.addChild(gravityFieldNode)
                if obstacleType == .gravity {
                     print(">>> [DEBUG] Configured GRAVITY obstacle: \(obstacleNode.name ?? "N/A")")
                }
            }
            
            obstacleNode.name = "\(OBSTACLE_NAME_PREFIX)\(obstacleType.uniqueNamePart)_\(statusSuffix)_\(obstaclesPlaced)"
            addChild(obstacleNode)
            
            existingObstacleFrames.append(obstacleFrame.insetBy(dx: -cellPadding, dy: -cellPadding))
            occupiedCells.insert(cellKey); obstaclesPlaced += 1
        }
        
        if obstaclesPlaced < min(2, obstacleCount) && obstacleCount > 0 {
            let numFallbacksToTry = min(max(0, min(2, obstacleCount) - obstaclesPlaced), 3)
            print(">>> [DEBUG] Attempting to place \(numFallbacksToTry) fallback obstacles.")
            let safePositions = [
                CGPoint(x: size.width * 0.3, y: size.height * 0.55),
                CGPoint(x: size.width * 0.7, y: size.height * 0.55),
                CGPoint(x: size.width * 0.5, y: size.height * 0.35)
            ]
            for i in 0..<numFallbacksToTry {
                if i >= safePositions.count { break }
                guard let fallbackUiImage = UIImage(named: "normal_obstacle") else {
                    print("⚠️ Fallback image 'normal_obstacle' missing.")
                    continue
                }
                let fallbackTexture = SKTexture(image: fallbackUiImage)
                let fallbackObstacle = SKSpriteNode(texture: fallbackTexture)
                let fallbackRadius: CGFloat = 39
                let fallbackImageOriginalSize = fallbackTexture.size()
                if fallbackImageOriginalSize.width == 0 || fallbackImageOriginalSize.height == 0 {
                    print("⚠️ Fallback texture 'normal_obstacle' loaded with zero size.")
                    continue
                }
                let fallbackTargetSize = CGSize(width: fallbackRadius * 2, height: fallbackRadius * 2)
                let fallbackTextureAspectRatio = fallbackImageOriginalSize.width / fallbackImageOriginalSize.height
                let fallbackTargetAspectRatio = fallbackTargetSize.width / fallbackTargetSize.height
                var newFallbackWidth: CGFloat
                var newFallbackHeight: CGFloat
                if fallbackTextureAspectRatio > fallbackTargetAspectRatio {
                    newFallbackHeight = fallbackTargetSize.height
                    newFallbackWidth = newFallbackHeight * fallbackTextureAspectRatio
                } else {
                    newFallbackWidth = fallbackTargetSize.width
                    newFallbackHeight = newFallbackWidth / fallbackTextureAspectRatio
                }
                fallbackObstacle.size = CGSize(width: newFallbackWidth, height: newFallbackHeight)
                let fallbackFrame = CGRect(origin: CGPoint(x: safePositions[i].x - fallbackRadius, y: safePositions[i].y - fallbackRadius), size: fallbackObstacle.size)
                var canPlaceFallback = true
                for frame in existingObstacleFrames { if frame.intersects(fallbackFrame) { canPlaceFallback = false; break } }
                if !canPlaceFallback {
                    print(">>> [DEBUG] Cannot place fallback obstacle \(i) at \(safePositions[i]) due to overlap.")
                    continue
                }
                fallbackObstacle.position = safePositions[i]
                fallbackObstacle.physicsBody = SKPhysicsBody(circleOfRadius: fallbackRadius)
                fallbackObstacle.physicsBody?.isDynamic = false
                fallbackObstacle.physicsBody?.affectedByGravity = false
                fallbackObstacle.physicsBody?.fieldBitMask = 0
                fallbackObstacle.physicsBody?.categoryBitMask = obstacleCategory
                fallbackObstacle.physicsBody?.collisionBitMask = obstacleCategory | rocketCategory
                fallbackObstacle.physicsBody?.friction = 0.4; fallbackObstacle.physicsBody?.restitution = 0.4
                fallbackObstacle.name = "\(OBSTACLE_NAME_PREFIX)Normal_Fallback_\(i)"
                fallbackObstacle.alpha = 0.0
                addChild(fallbackObstacle)
                print(">>> [DEBUG] Added fallback obstacle '\(fallbackObstacle.name ?? "N/A")' at \(fallbackObstacle.position)")
                existingObstacleFrames.append(fallbackFrame)
                obstaclesPlaced += 1
            }
        }
        print(">>> [DEBUG] Total obstacles placed after fallbacks: \(obstaclesPlaced) for level \(self.level).")
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        var newSize = CGRect(origin: .zero, size: self.size).applying(CGAffineTransform(rotationAngle: radians)).size
        newSize.width = floor(newSize.width); newSize.height = floor(newSize.height)
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { UIGraphicsEndImageContext(); return self }
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
}
