//
//  GameScene.swift
//  HordeRush
//
//  Created by Nathan Herr on 4/23/25.
//

import SpriteKit
// Remove GameplayKit import if not immediately needed
// import GameplayKit

// Define Physics Categories (outside the class)
struct PhysicsCategory {
    static let none     : UInt32 = 0
    static let player   : UInt32 = 0b1    // 1
    static let projectile: UInt32 = 0b10   // 2
    static let gate     : UInt32 = 0b100  // 4
    static let barrel   : UInt32 = 0b1000 // 8
    static let zombie   : UInt32 = 0b10000// 16
    static let crowdMember: UInt32 = 0b100000 // 32 (New)
    // Add more categories as needed
    static let all      : UInt32 = UInt32.max
}

// Global operator overload for adding CGPoints
func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // Player Properties
    private var player: SKSpriteNode?
    private var lastTouchLocation: CGPoint?

    // Projectile Properties
    private let projectileSize = CGSize(width: 5, height: 10)
    private let projectileColor = UIColor.yellow
    private let projectileSpeed: CGFloat = 600.0
    private let fireRate: TimeInterval = 0.2

    // Crowd Properties
    var crowdCount: Int = 1
    private var crowdMembers: [SKSpriteNode] = []
    private let followSpeedFactor: CGFloat = 8.0 // How quickly followers catch up
    private let crowdMemberSize = CGSize(width: 24, height: 24)
    private let crowdMemberColor = UIColor.cyan
    // Define relative positions for crowd members around the player
    private let crowdOffsets: [CGPoint] = [
        CGPoint(x: -30, y: -40), // Back-left
        CGPoint(x:  30, y: -40), // Back-right
        CGPoint(x:   0, y: -60), // Directly behind 
        CGPoint(x: -60, y: -80), // Further back-left
        CGPoint(x:  60, y: -80), // Further back-right
        CGPoint(x: -30, y: -100),// Even further back-left
        CGPoint(x:  30, y: -100),// Even further back-right
        // Add more for larger crowds if needed
    ]

    // World Properties
    private let worldNode = SKNode()
    private let objectLayer = SKNode()       // For gates, barrels, zombies
    private let projectileLayer = SKNode()   // For projectiles
    private var backgroundTiles: [SKSpriteNode] = []
    private let initialScrollSpeed: CGFloat = 150.0 // Renamed from scrollSpeed
    private var currentGameSpeed: CGFloat = 0 // Initialized in didMove
    private let maxScrollSpeed: CGFloat = 300.0 // Maximum speed cap
    private let scrollSpeedAcceleration: CGFloat = 2.0 // Points per second increase, per second
    private var lastUpdateTime: TimeInterval = 0
    private let spawnInterval: TimeInterval = 1.5 // Time between spawning rows
    // Define lanes for spawning
    private var lanePositions: [CGFloat] = []

    // UI Properties
    private var scoreLabel: SKLabelNode?
    private var crowdLabel: SKLabelNode?
    private var score: Int = 0
    private var distanceTraveled: CGFloat = 0 // Track distance for scoring
    
    override func didMove(to view: SKView) {
        // Setup scene
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .darkGray // Will be covered by background tiles

        // Add World Node (parent for scrolling elements)
        addChild(worldNode)
        // Add layers
        worldNode.addChild(objectLayer)
        addChild(projectileLayer) // Projectiles don't scroll with the world

        // Setup physics world
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.contactDelegate = self

        // Calculate lane positions based on scene size
        calculateLanePositions()

        // Setup background
        setupBackground()

        // Setup player (added directly to scene)
        setupPlayer()

        // Start the shooting timer
        setupShooting()

        // Start the object spawner
        setupObjectSpawner()

        // Setup UI elements
        setupUI()

        // Initialize current game speed
        currentGameSpeed = initialScrollSpeed
    }

    func calculateLanePositions() {
        // Example: 3 lanes
        let laneWidth = size.width / 3
        lanePositions = [
            -laneWidth, // Left
             0,         // Center
             laneWidth  // Right
        ]
        // Adjusting slightly to not be exactly on edge if needed:
        // lanePositions = [
        //     -size.width / 4,
        //      0,
        //      size.width / 4
        // ]
    }

    func setupBackground() {
        // Create a placeholder tile texture (replace with "background_tile.png" later)
        let tileSize = CGSize(width: size.width, height: size.height)
        let placeholderTexture = SKTexture(size: tileSize, color: .darkGray, darkerColor: .black)

        for i in 0...1 {
            let tile = SKSpriteNode(texture: placeholderTexture)
            tile.size = tileSize
            tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            tile.position = CGPoint(x: 0, y: CGFloat(i) * tileSize.height)
            tile.zPosition = -1 // Ensure background is behind everything
            worldNode.addChild(tile) // Add to worldNode so it scrolls
            backgroundTiles.append(tile)
        }
    }

    func setupPlayer() {
        player = SKSpriteNode(color: .blue, size: CGSize(width: 32, height: 32))
        player?.position = CGPoint(x: 0, y: -size.height / 2 + (player?.size.height ?? 0) + 50)
        player?.zPosition = 10
        player?.physicsBody = SKPhysicsBody(rectangleOf: player!.size)
        player?.physicsBody?.isDynamic = true
        player?.physicsBody?.affectedByGravity = false
        player?.physicsBody?.allowsRotation = false
        player?.physicsBody?.categoryBitMask = PhysicsCategory.player
        player?.physicsBody?.collisionBitMask = PhysicsCategory.none
        player?.physicsBody?.contactTestBitMask = PhysicsCategory.gate | PhysicsCategory.barrel | PhysicsCategory.zombie

        if let player = player {
            addChild(player)
            // Initially, the player IS the crowd of 1
            // We don't add to crowdMembers array until count > 1
        }
    }

    func setupShooting() {
        // Create the sequence: Wait, then Spawn
        let waitAction = SKAction.wait(forDuration: fireRate)
        let spawnAction = SKAction.run { [weak self] in // Use weak self to avoid retain cycles
            self?.spawnProjectile()
        }
        let sequenceAction = SKAction.sequence([waitAction, spawnAction])

        // Repeat the sequence forever
        let repeatAction = SKAction.repeatForever(sequenceAction)

        // Run the repeating action on the scene
        self.run(repeatAction, withKey: "shootingAction") // Add a key to potentially stop it later
    }

    func spawnProjectile() {
        // Spawn from Player (Leader)
        if let player = self.player {
            spawnProjectile(from: player.position, leadProjectile: true)
        }
        
        // Spawn from Crowd Members
        for member in crowdMembers {
            spawnProjectile(from: member.position, leadProjectile: false)
        }
    }
    
    // Helper for spawning projectiles from a specific position
    func spawnProjectile(from startPosition: CGPoint, leadProjectile: Bool) {
        let projectile = SKSpriteNode(color: projectileColor, size: projectileSize)
        // Offset starting Y slightly based on who is firing for visual clarity (optional)
        projectile.position = CGPoint(x: startPosition.x, y: startPosition.y + (leadProjectile ? player?.size.height ?? 32 : crowdMemberSize.height) / 2)
        projectile.zPosition = 9
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.allowsRotation = false
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.gate | PhysicsCategory.barrel | PhysicsCategory.zombie

        projectileLayer.addChild(projectile)

        let destinationY = size.height / 2 + projectile.size.height
        // Calculate distance relative to the scene, regardless of spawner position
        let sceneStartPosition = projectileLayer.convert(projectile.position, to: self)
        let distance = destinationY - sceneStartPosition.y 
        guard distance > 0 else { // Avoid issues if spawned too high
            projectile.removeFromParent()
            return
        }
        let duration = TimeInterval(distance / projectileSpeed)
        let moveAction = SKAction.moveTo(y: destinationY, duration: duration)
        let removeAction = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([moveAction, removeAction]))
    }

    func setupObjectSpawner() {
        let waitAction = SKAction.wait(forDuration: spawnInterval)
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnObjectRow()
        }
        let sequenceAction = SKAction.sequence([waitAction, spawnAction])
        let repeatAction = SKAction.repeatForever(sequenceAction)
        self.run(repeatAction, withKey: "objectSpawnerAction")
    }

    func spawnObjectRow() {
        let spawnY = (size.height / 2) - worldNode.position.y + 100 // Y pos relative to worldNode, above screen top
        guard lanePositions.count == 3 else { // Assumes 3 lanes are defined
            print("Error: Expected 3 lane positions, found \(lanePositions.count)")
            return
        }
        let leftLaneX = lanePositions[0]
        let centerLaneX = lanePositions[1]
        let rightLaneX = lanePositions[2]

        // --- Define Helper Functions for Creation & Adding ---
        func createGateOrBarrel() -> SKNode {
            let isGate = Bool.random() // 50/50 chance Gate vs Barrel
            if isGate {
                let initialValue = Int.random(in: -30 ... -5)
                let node = GateNode(initialValue: initialValue)
                // print("Creating Gate(value: \(initialValue))") // Keep print in addNodeToLayer
                return node
            } else {
                let initialValue = Int.random(in: 5 ... 25)
                let node = BarrelNode(initialValue: initialValue)
                // print("Creating Barrel(value: \(initialValue))") // Keep print in addNodeToLayer
                return node
            }
        }

        func createZombie() -> SKNode {
             // print("Creating Zombie") // Keep print in addNodeToLayer
             return ZombieNode()
        }

        func addNodeToLayer(_ node: SKNode, position: CGPoint, description: String) {
            node.position = position
            if node is ZombieNode {
                 node.zPosition = 6
            } else {
                 node.zPosition = 5
            }
            objectLayer.addChild(node)
             print("Spawning \(description) at (\(position.x.rounded()), \(position.y.rounded()))")
        }
        // ----------------------------------------------------

        // --- Define and Choose Spawn Pattern --- 
        enum SpawnPattern: CaseIterable {
            case zombieCenter
            case gateOrBarrelLeft
            case gateOrBarrelRight
            case zombieCenterGateOrBarrelLeft
            case zombieCenterGateOrBarrelRight
            case gateOrBarrelLeftGateOrBarrelRight
            // Could add weights here later if needed
        }

        let chosenPattern = SpawnPattern.allCases.randomElement()!
        // ---------------------------------------

        // --- Spawn Objects Based on Pattern ---
        switch chosenPattern {
        case .zombieCenter:
            let zombie = createZombie()
            addNodeToLayer(zombie, position: CGPoint(x: centerLaneX, y: spawnY), description: "Zombie")

        case .gateOrBarrelLeft:
            let node = createGateOrBarrel()
            let desc = node is GateNode ? "Gate" : "Barrel"
            addNodeToLayer(node, position: CGPoint(x: leftLaneX, y: spawnY), description: desc)

        case .gateOrBarrelRight:
            let node = createGateOrBarrel()
            let desc = node is GateNode ? "Gate" : "Barrel"
            addNodeToLayer(node, position: CGPoint(x: rightLaneX, y: spawnY), description: desc)

        case .zombieCenterGateOrBarrelLeft:
            let zombie = createZombie()
            addNodeToLayer(zombie, position: CGPoint(x: centerLaneX, y: spawnY), description: "Zombie")
            let node = createGateOrBarrel()
            let desc = node is GateNode ? "Gate" : "Barrel"
            addNodeToLayer(node, position: CGPoint(x: leftLaneX, y: spawnY), description: desc)

        case .zombieCenterGateOrBarrelRight:
            let zombie = createZombie()
            addNodeToLayer(zombie, position: CGPoint(x: centerLaneX, y: spawnY), description: "Zombie")
            let node = createGateOrBarrel()
            let desc = node is GateNode ? "Gate" : "Barrel"
            addNodeToLayer(node, position: CGPoint(x: rightLaneX, y: spawnY), description: desc)

        case .gateOrBarrelLeftGateOrBarrelRight:
            let nodeLeft = createGateOrBarrel()
            let descLeft = nodeLeft is GateNode ? "Gate" : "Barrel"
            addNodeToLayer(nodeLeft, position: CGPoint(x: leftLaneX, y: spawnY), description: descLeft)
            
            let nodeRight = createGateOrBarrel()
            let descRight = nodeRight is GateNode ? "Gate" : "Barrel"
            addNodeToLayer(nodeRight, position: CGPoint(x: rightLaneX, y: spawnY), description: descRight)
        }
        // ---------------------------------------
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle initial touch for dragging
        guard let touch = touches.first else { return }
        lastTouchLocation = touch.location(in: self)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle dragging movement
        guard let touch = touches.first, let player = player, let lastTouch = lastTouchLocation else { return }

        let currentLocation = touch.location(in: self)
        let dx = currentLocation.x - lastTouch.x // Calculate horizontal change

        // Calculate new X position
        var newX = player.position.x + dx

        // Calculate screen boundaries based on scene size and player size
        let halfWidth = size.width / 2
        let playerHalfWidth = player.size.width / 2
        let minX = -halfWidth + playerHalfWidth // Left boundary
        let maxX = halfWidth - playerHalfWidth  // Right boundary

        // Clamp position within screen bounds
        newX = max(minX, newX) // Ensure not less than minX
        newX = min(maxX, newX) // Ensure not more than maxX

        // Update player position
        player.position.x = newX

        // Update last touch location for the next move calculation
        lastTouchLocation = currentLocation
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle touch release (if needed)
        lastTouchLocation = nil // Reset tracking when touch ends
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle cancelled touch (if needed)
        lastTouchLocation = nil // Also reset if the touch is cancelled
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard deltaTime > 0, let player = player else { return } // Ensure player exists

        // --- Update Game Speed ---
        if currentGameSpeed < maxScrollSpeed {
            currentGameSpeed += scrollSpeedAcceleration * CGFloat(deltaTime)
            // Clamp to max speed in case of large deltaTime
            currentGameSpeed = min(currentGameSpeed, maxScrollSpeed)
        }
        // ------------------------

        // Scroll the world node using the current speed
        let distanceToScroll = currentGameSpeed * CGFloat(deltaTime)
        worldNode.position.y -= distanceToScroll
        distanceTraveled += distanceToScroll // Accumulate distance

        // --- Score Update --- 
        // Score = (distance traveled / factor) * crowd multiplier
        // Divide distance by a factor to make score grow slower
        let scoreFactor: CGFloat = 10.0 
        score = Int(distanceTraveled / scoreFactor) * crowdCount
        scoreLabel?.text = "Score: \(score)"
        // -------------------

        // --- Background Tile Repositioning --- 
        for tile in backgroundTiles {
            let tileScenePosition = convert(tile.position, from: worldNode)
            if tileScenePosition.y + tile.size.height / 2 < -self.size.height / 2 {
                tile.position.y += 2 * tile.size.height
            }
        }
        
        // --- Object Cleanup --- 
        for node in objectLayer.children {
            let nodeScenePosition = convert(node.position, from: objectLayer)
            let nodeTopY = nodeScenePosition.y + node.frame.size.height / 2
            if nodeTopY < -self.size.height / 2 {
                node.removeFromParent()
            }
        }

        // --- Crowd Following Logic (Cluster Formation) --- 
        for (index, member) in crowdMembers.enumerated() {
            // Target position: Offset relative to the player
            let offsetIndex = index % crowdOffsets.count
            let targetPosition = player.position + crowdOffsets[offsetIndex]
            
            // Calculate vector towards target
            let deltaX = targetPosition.x - member.position.x
            let deltaY = targetPosition.y - member.position.y
            
            // Move using lerp (scaled by deltaTime)
            member.position.x += deltaX * followSpeedFactor * CGFloat(deltaTime)
            member.position.y += deltaY * followSpeedFactor * CGFloat(deltaTime)
        }
        // ---------------------------------------------------
    }

    // MARK: - SKPhysicsContactDelegate Methods

    func didBegin(_ contact: SKPhysicsContact) {
        // This method is called when two physics bodies make contact.

        // Identify the two bodies involved in the contact
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB

        // Sort bodies by category to simplify checks (optional but helpful)
        let firstBody: SKPhysicsBody
        let secondBody: SKPhysicsBody

        // Ensure firstBody always has the lower category bitmask
        if bodyA.categoryBitMask < bodyB.categoryBitMask {
            firstBody = bodyA
            secondBody = bodyB
        } else {
            firstBody = bodyB
            secondBody = bodyA
        }

        // --- Projectile Collisions ---
        if firstBody.categoryBitMask == PhysicsCategory.projectile {
            if secondBody.categoryBitMask == PhysicsCategory.gate {
                if let projectileNode = firstBody.node, let gateNode = secondBody.node as? GateNode {
                    projectileDidCollideWithGate(projectile: projectileNode, gate: gateNode)
                }
            } else if secondBody.categoryBitMask == PhysicsCategory.barrel {
                if let projectileNode = firstBody.node, let barrelNode = secondBody.node as? BarrelNode {
                     projectileDidCollideWithBarrel(projectile: projectileNode, barrel: barrelNode)
                }
            } else if secondBody.categoryBitMask == PhysicsCategory.zombie {
                if let projectileNode = firstBody.node, let zombieNode = secondBody.node as? ZombieNode {
                     projectileDidCollideWithZombie(projectile: projectileNode, zombie: zombieNode)
                }
            }
        // --- Player Collisions ---
        } else if firstBody.categoryBitMask == PhysicsCategory.player {
            if secondBody.categoryBitMask == PhysicsCategory.gate {
                if let playerNode = firstBody.node, let gateNode = secondBody.node as? GateNode {
                    playerDidCollideWithGate(player: playerNode, gate: gateNode)
                }
            } else if secondBody.categoryBitMask == PhysicsCategory.barrel {
                 if let playerNode = firstBody.node, let barrelNode = secondBody.node as? BarrelNode {
                    playerDidCollideWithBarrel(player: playerNode, barrel: barrelNode)
                 }
            } else if secondBody.categoryBitMask == PhysicsCategory.zombie {
                 if let playerNode = firstBody.node, let zombieNode = secondBody.node as? ZombieNode {
                    playerDidCollideWithZombie(player: playerNode, zombie: zombieNode)
                 }
            }
        // --- Barrel Collisions (specifically with CrowdMember) ---
        // Barrel (8) vs CrowdMember (32) -> Barrel is firstBody
        } else if firstBody.categoryBitMask == PhysicsCategory.barrel && secondBody.categoryBitMask == PhysicsCategory.crowdMember {
            print("DEBUG: Entered Barrel vs CrowdMember collision branch") // Add logging
            if let barrelNode = firstBody.node as? BarrelNode, let memberNode = secondBody.node as? SKSpriteNode {
                 crowdMemberDidCollideWithBarrel(member: memberNode, barrel: barrelNode)
            }
        // --- Zombie Collisions (specifically with CrowdMember) ---
        // Zombie (16) vs CrowdMember (32) -> Zombie is firstBody
        } else if firstBody.categoryBitMask == PhysicsCategory.zombie && secondBody.categoryBitMask == PhysicsCategory.crowdMember {
             if let zombieNode = firstBody.node as? ZombieNode, let memberNode = secondBody.node as? SKSpriteNode {
                 crowdMemberDidCollideWithZombie(member: memberNode, zombie: zombieNode)
             }
        }
    }

    // Updated Collision Handling Functions
    func projectileDidCollideWithGate(projectile: SKNode, gate: GateNode) { // Note: GateNode type
        print("Handling Projectile-Gate collision")
        gate.hitByProjectile()       // Call the gate's method
        projectile.removeFromParent() // Remove projectile
    }

    func projectileDidCollideWithBarrel(projectile: SKNode, barrel: BarrelNode) { // Note: BarrelNode type
        print("Handling Projectile-Barrel collision")
        barrel.hitByProjectile() // Call the barrel's method
        projectile.removeFromParent() // Remove projectile
    }

    func projectileDidCollideWithZombie(projectile: SKNode, zombie: ZombieNode) { // Note: ZombieNode type
        print("Handling Projectile-Zombie collision")
        projectile.removeFromParent() // Remove projectile
        zombie.hitByProjectile()       // Call zombie's method (which removes it)
    }

    func playerDidCollideWithGate(player: SKNode, gate: GateNode) {
        print("Handling Player-Gate collision")
        let value = gate.playerContact()

        if value >= 0 {
            // Add members if value is 0 or positive
             if value > 0 { addCrowdMembers(count: value) }
        } else { // Value is negative
            let membersToRemove = abs(value)
            if membersToRemove >= crowdCount { // Removing more members than exist (including leader)
                print("Negative gate value \(value) exceeds crowd size \(crowdCount). GAME OVER.")
                // Game Over
                 gate.removeFromParent()
                 triggerGameOver()
            } else {
                // Remove members, leader survives
                removeCrowdMembers(count: membersToRemove)
                 gate.removeFromParent()
            }
        }
    }

    func playerDidCollideWithBarrel(player: SKNode, barrel: BarrelNode) {
        print("Handling Player-Barrel collision (Player Leader)")
        let isHazard = barrel.playerContact()
        
        if isHazard {
            print("Player leader hit active barrel!")
            if crowdMembers.isEmpty {
                print("Player leader hit barrel with no crowd left - GAME OVER")
                triggerGameOver()
                // Optionally remove barrel here too, though game over stops updates
                // barrel.removeFromParent()
            } else {
                print("Player leader hit barrel! Sacrificing one crowd member.")
                removeCrowdMembers(count: 1)
                // Do NOT remove the barrel here - let it potentially hit a member
            }
        } else {
             print("Player passed depleted barrel location.")
             // Depleted barrels are harmless and should already be gone or will be cleaned up
        }
    }

    func playerDidCollideWithZombie(player: SKNode, zombie: ZombieNode) {
        print("Handling Player-Zombie collision")
        zombie.playerContact() // Remove zombie

        if crowdMembers.isEmpty {
            print("Player hit zombie with no crowd left - GAME OVER")
            triggerGameOver()
        } else {
            print("Player hit zombie! Sacrificing one crowd member.")
            removeCrowdMembers(count: 1)
        }
    }

    func triggerGameOver() {
        guard let player = player else { return } // Don't trigger if already game over
        print("--- GAME OVER --- Triggered")
        player.removeFromParent() // Remove player node visually
        self.player = nil // Nil out player reference

        // Stop game actions immediately
        self.removeAllActions() // Stop shooting, spawning etc.
        projectileLayer.removeAllChildren() // Clear remaining projectiles
        objectLayer.isPaused = true // Stop objects scrolling further (optional, visual)
        
        // Transition after a short delay to see the destruction
        let wait = SKAction.wait(forDuration: 0.5)
        let transitionAction = SKAction.run { [weak self] in
            self?.transitionToGameOverScene()
        }
        self.run(SKAction.sequence([wait, transitionAction]))
    }

    func transitionToGameOverScene() {
        // Ensure view exists
        guard let view = self.view else { return }
        
        // --- High Score Logic ---
        let defaults = UserDefaults.standard
        let highScoreKey = "highScore" // Key for UserDefaults
        let currentHighScore = defaults.integer(forKey: highScoreKey) // Get current high score (defaults to 0)

        if score > currentHighScore {
            defaults.set(score, forKey: highScoreKey) // Save new high score
            print("New High Score! \(score) saved.")
            // defaults.synchronize() // Not strictly needed in modern iOS, but sometimes used
        } else {
            print("Score \(score) did not beat high score \(currentHighScore).")
        }
        // ------------------------

        // Create the Game Over Scene, passing the final score
        let gameOverScene = GameOverScene(size: view.bounds.size, score: self.score)
        gameOverScene.scaleMode = self.scaleMode // Match scale mode
        
        // Create a transition
        let transition = SKTransition.fade(withDuration: 1.0)
        
        // Present the scene
        view.presentScene(gameOverScene, transition: transition)
    }

    // Add custom methods for player setup, UI setup, spawning, etc. later
    // func setupPlayer() { ... }
    // func setupUI() { ... }
    // func spawnObjects() { ... }

    // --- Crowd Management --- 
    func addCrowdMembers(count: Int) {
        guard let player = player else { return }
        print("Adding \(count) members to crowd.")
        
        for i in 0..<count {
            let member = SKSpriteNode(color: crowdMemberColor, size: crowdMemberSize)
            member.zPosition = player.zPosition - 0.1
            
            // Calculate initial position based on the next available offset relative to the player
            let currentMemberCount = crowdMembers.count + i
            let offsetIndex = currentMemberCount % crowdOffsets.count
            member.position = player.position + crowdOffsets[offsetIndex]
            
            // Add physics body to crowd member
            member.physicsBody = SKPhysicsBody(rectangleOf: member.size)
            member.physicsBody?.isDynamic = true // Allow movement
            member.physicsBody?.affectedByGravity = false
            member.physicsBody?.allowsRotation = false
            member.physicsBody?.categoryBitMask = PhysicsCategory.crowdMember
            member.physicsBody?.collisionBitMask = PhysicsCategory.none
            // Detect collisions with zombies AND barrels
            member.physicsBody?.contactTestBitMask = PhysicsCategory.zombie | PhysicsCategory.barrel
            
            // Assign a unique name to identify specific members if needed later
            // member.name = "crowdMember_\(UUID().uuidString)" 
            
            crowdMembers.append(member)
            addChild(member)
        }
        crowdCount = 1 + crowdMembers.count
        print("Crowd count now: \(crowdCount)")
        updateCrowdLabel()
    }

    func removeCrowdMembers(count: Int) {
        print("Removing up to \(count) members from crowd.")
        let removalCount = min(count, crowdMembers.count)
        guard removalCount > 0 else { return }
        
        for _ in 0..<removalCount {
            if let memberToRemove = crowdMembers.popLast() {
                memberToRemove.removeFromParent()
            }
        }
        crowdCount = 1 + crowdMembers.count
         print("Crowd count now: \(crowdCount)")
        updateCrowdLabel() // Update UI
    }
    // -----------------------

    func setupUI() {
        let horizontalPadding: CGFloat = 30
        let verticalPadding: CGFloat = 30 // Distance from top edge

        // Score Label (Top Left)
        scoreLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        scoreLabel?.fontSize = 24
        scoreLabel?.fontColor = .white
        scoreLabel?.horizontalAlignmentMode = .left
        scoreLabel?.position = CGPoint(x: -size.width/2 + horizontalPadding, y: size.height/2 - verticalPadding)
        scoreLabel?.zPosition = 100 // Ensure UI is above everything
        scoreLabel?.text = "Score: 0"
        if let scoreLabel = scoreLabel {
            addChild(scoreLabel) // Add directly to scene
        }

        // Crowd Label (Top Right)
        crowdLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        crowdLabel?.fontSize = 24
        crowdLabel?.fontColor = .white
        crowdLabel?.horizontalAlignmentMode = .right
        crowdLabel?.position = CGPoint(x: size.width/2 - horizontalPadding, y: size.height/2 - verticalPadding)
        crowdLabel?.zPosition = 100
        updateCrowdLabel() // Set initial text
        if let crowdLabel = crowdLabel {
             addChild(crowdLabel) // Add directly to scene
        }
    }
    
    func updateCrowdLabel() {
        crowdLabel?.text = "Crowd: \(crowdCount)"
    }

    // New handler for crowd member vs zombie
    func crowdMemberDidCollideWithZombie(member: SKSpriteNode, zombie: ZombieNode) {
        print("Handling CrowdMember-Zombie collision")
        zombie.playerContact() // Remove zombie
        
        // Remove the specific crowd member
        if let index = crowdMembers.firstIndex(of: member) {
            crowdMembers.remove(at: index)
            crowdCount = 1 + crowdMembers.count
            updateCrowdLabel()
        }
        member.removeFromParent() 
        print("Crowd count now: \(crowdCount)")
    }

    // Add new handler for crowd member vs barrel
    func crowdMemberDidCollideWithBarrel(member: SKSpriteNode, barrel: BarrelNode) {
        print("Handling CrowdMember-Barrel collision")
        if !barrel.isDepleted { // Only active barrels hurt members
             print("Crowd member hit active barrel! Removing member.")
             // Remove the specific crowd member
             if let index = crowdMembers.firstIndex(of: member) {
                 crowdMembers.remove(at: index)
                 crowdCount = 1 + crowdMembers.count
                 updateCrowdLabel()
             }
             member.removeFromParent()
             print("Crowd count now: \(crowdCount)")
             
             // Remove the barrel after it hits the first crowd member
             barrel.removeFromParent()
             
        } else {
            // Member hit an already depleted barrel (which should be gone, but safety check)
            print("Crowd member hit depleted barrel.")
            // Might as well remove the depleted barrel if somehow still here
            barrel.removeFromParent()
        }
    }
}

// Extend GameScene to conform to SKPhysicsContactDelegate later
// extension GameScene: SKPhysicsContactDelegate {
//     func didBegin(_ contact: SKPhysicsContact) {
//         // Handle collisions
//     }
// }

// Helper extension to create a simple gradient texture (placeholder)
extension SKTexture {
    convenience init(size: CGSize, color: UIColor, darkerColor: UIColor) {
        let coreImageContext = CIContext(options: nil)
        let gradient = CIFilter(name: "CILinearGradient")!
        gradient.setValue(CIVector(x: size.width/2, y: 0), forKey: "inputPoint0")
        gradient.setValue(CIColor(color: darkerColor), forKey: "inputColor0")
        gradient.setValue(CIVector(x: size.width/2, y: size.height), forKey: "inputPoint1")
        gradient.setValue(CIColor(color: color), forKey: "inputColor1")
        let gradientImage = coreImageContext.createCGImage(gradient.outputImage!, from: CGRect(origin: .zero, size: size))
        self.init(cgImage: gradientImage!)
    }
}
