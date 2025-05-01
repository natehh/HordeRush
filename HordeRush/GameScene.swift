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
    private let fireRate: TimeInterval = 0.8
    private var currentFireRate: TimeInterval = 0.8
    private let minFireRate: TimeInterval = 0.1 // Fastest possible fire rate
    private let fireRateIncreaseAmount: TimeInterval = 0.05 // How much faster each upgrade makes it
    // Need a reference to the shooting action sequence to modify its speed
    private var shootingAction: SKAction?

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
    
    // Difficulty Properties
    private var difficultyFactor: CGFloat = 1.0 // Starts at 1.0, increases over time
    private let maxDifficultyFactor: CGFloat = 3.0 // Max multiplier for values/counts
    private let difficultyIncreaseRate: CGFloat = 0.01 // How much factor increases per second
    // Removed timeSinceLastDifficultyIncrease and difficultyUpdateInterval, will update continuously
    
    private var lastUpdateTime: TimeInterval = 0
    private let spawnInterval: TimeInterval = 1.5 // Time between spawning GATE/BARREL rows
    
    // Zombie Spawn Properties (New)
    private let zombieSpawnTickInterval: TimeInterval = 0.2 // How often we *try* to spawn
    private let zombieSpawnBaseProbability: Double = 0.10 // Initial chance per tick
    private let zombieSpawnMaxProbability: Double = 0.60 // Max chance per tick at max difficulty
    
    // Define lanes for spawning
    private var lanePositions: [CGFloat] = []

    // UI Properties
    private var scoreLabel: SKLabelNode?
    private var crowdLabel: SKLabelNode?
    private var score: Int = 0
    private var distanceTraveled: CGFloat = 0 // Track distance for scoring
    
    // Zombie Animation Assets
    private var zombieAtlas: SKTextureAtlas?
    private var zombieWalkTextures: [SKTexture] = []
    private var zombieDieTextures: [SKTexture] = []
    private var zombieWalkAction: SKAction?
    private var zombieDieAction: SKAction?

    override func didMove(to view: SKView) {
        // Setup scene
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .darkGray // Will be covered by background tiles

        // Preload Assets (including new zombie assets)
        preloadZombieAssets() // Call this early

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

        // Start the object spawner (Gates/Barrels)
        setupObjectSpawner()

        // Start the zombie spawner (New)
        setupZombieSpawner()

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
        let waitAction = SKAction.wait(forDuration: currentFireRate) // Use currentFireRate
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnProjectile()
        }
        // Store the sequence itself
        let sequenceAction = SKAction.sequence([waitAction, spawnAction])

        // Repeat the sequence forever
        shootingAction = SKAction.repeatForever(sequenceAction)

        // Run the repeating action on the scene
        if let action = shootingAction {
            self.run(action, withKey: "shootingAction") 
        }
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
        let rightLaneX = lanePositions[2]

        // --- Define and Choose Spawn Pattern (Gates/Barrels Only) ---
        enum SpawnPattern: CaseIterable {
            case gateOrBarrelLeft
            case gateOrBarrelRight
            case gateOrBarrelLeftGateOrBarrelRight
            case empty // Add chance for no gate/barrel to spawn
        }

        // Adjust weights if desired (e.g., higher chance of empty)
        let patternWeights: [SpawnPattern: Double] = [
            .gateOrBarrelLeft: 1.0,
            .gateOrBarrelRight: 1.0,
            .gateOrBarrelLeftGateOrBarrelRight: 0.5, // Less likely to get two
            .empty: 1.5 // More likely to get empty row
        ]
        let totalWeight = patternWeights.values.reduce(0, +)
        var randomValue = Double.random(in: 0...totalWeight)
        var chosenPattern: SpawnPattern = .empty // Default

        for (pattern, weight) in patternWeights {
            if randomValue < weight {
                chosenPattern = pattern
                break
            }
            randomValue -= weight
        }
        // --------------------------------------------------------

        // --- Spawn Objects Based on Pattern ---
        switch chosenPattern {
        case .gateOrBarrelLeft:
            let node = createGateOrBarrel()
            let desc = node is GateNode ? "Gate(\((node as! GateNode).currentValue))" : "Barrel(\((node as! BarrelNode).currentValue))"
            addNodeToLayer(node, position: CGPoint(x: leftLaneX, y: spawnY), description: desc)

        case .gateOrBarrelRight:
            let node = createGateOrBarrel()
            let desc = node is GateNode ? "Gate(\((node as! GateNode).currentValue))" : "Barrel(\((node as! BarrelNode).currentValue))"
            addNodeToLayer(node, position: CGPoint(x: rightLaneX, y: spawnY), description: desc)

        case .gateOrBarrelLeftGateOrBarrelRight:
            let nodeLeft = createGateOrBarrel()
            let descLeft = nodeLeft is GateNode ? "Gate(\((nodeLeft as! GateNode).currentValue))" : "Barrel(\((nodeLeft as! BarrelNode).currentValue))"
            addNodeToLayer(nodeLeft, position: CGPoint(x: leftLaneX, y: spawnY), description: descLeft)
            
            let nodeRight = createGateOrBarrel()
            let descRight = nodeRight is GateNode ? "Gate(\((nodeRight as! GateNode).currentValue))" : "Barrel(\((nodeRight as! BarrelNode).currentValue))"
            addNodeToLayer(nodeRight, position: CGPoint(x: rightLaneX, y: spawnY), description: descRight)
        
        case .empty:
            // Do nothing, spawn no gates/barrels this interval
            break
        }
        // ---------------------------------------
    }

    // --- Helper Methods for Spawning ---
    private func createGateOrBarrel() -> SKNode {
        // Determine type: e.g., 40% Gate, 40% Hazard Barrel, 20% Fire Rate Barrel
        let typeRoll = Double.random(in: 0...1)

        if typeRoll < 0.4 { // 40% chance Gate
            // Scale gate values (more negative) with difficulty - SLOWER SCALING
            let baseMinGate: CGFloat = -5.0 // Start less negative
            let baseMaxGate: CGFloat = -2.0  // Start less negative
            // Use sqrt for slower scaling. Ensure max is always <= -1 and >= min
            let scaledMin = Int(baseMinGate * sqrt(difficultyFactor))
            let scaledMax = min(-1, Int(baseMaxGate * sqrt(difficultyFactor)))
            let minGate = scaledMin
            let maxGate = max(minGate, scaledMax) // Ensure max >= min
            
            let initialValue = Int.random(in: minGate ... maxGate)
            let node = GateNode(initialValue: initialValue)
            return node
        } else if typeRoll < 0.8 { // 40% chance Hazard Barrel (0.4 to 0.8)
            // Scale hazard barrel values (more positive) with difficulty (Using sqrt for consistency)
            let baseMinBarrel: CGFloat = 5.0
            let baseMaxBarrel: CGFloat = 15.0 // Lowered base max slightly
            let minBarrel = Int(baseMinBarrel * sqrt(difficultyFactor))
            let maxBarrel = max(minBarrel + 1, Int(baseMaxBarrel * sqrt(difficultyFactor)))
            let initialValue = Int.random(in: minBarrel ... maxBarrel)
            let node = BarrelNode(type: .hazard, initialValue: initialValue)
            return node
        } else { // 20% chance Fire Rate Barrel (0.8 to 1.0)
            // Randomize required hits within a range that scales slowly with difficulty
            let baseMinHits: CGFloat = 2.0
            let baseMaxHits: CGFloat = 5.0 // Base range for hits needed
            
            let minHits = max(1, Int(baseMinHits * sqrt(difficultyFactor)))
            let maxHits = max(minHits + 1, Int(baseMaxHits * sqrt(difficultyFactor)))
            
            let requiredHits = Int.random(in: minHits...maxHits)
            
            let node = BarrelNode(type: .fireRateUp, initialValue: requiredHits)
            return node
        }
    }

    private func addNodeToLayer(_ node: SKNode, position: CGPoint, description: String) {
        node.position = position
        if node is ZombieNode {
             node.zPosition = 6
        } else {
             node.zPosition = 5
        }
        objectLayer.addChild(node)
         print("Spawning \(description) at (\(position.x.rounded()), \(position.y.rounded()))")
    }
    // -------------------------------------------------------------------

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

        // --- Update Difficulty Factor ---
        if difficultyFactor < maxDifficultyFactor {
            difficultyFactor += difficultyIncreaseRate * CGFloat(deltaTime)
            difficultyFactor = min(difficultyFactor, maxDifficultyFactor)
            // Optional: print("Difficulty Factor: \(String(format: "%.2f", difficultyFactor))")
        }
        // -----------------------------

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

    // MARK: - Gameplay Modifiers

    func increaseFireRate() { 
        // Decrease the delay, but not below the minimum
        currentFireRate = max(minFireRate, currentFireRate - fireRateIncreaseAmount)
        print("Fire Rate Increased! New Delay: \(String(format: "%.2f", currentFireRate))")

        // Update the existing shooting action timer
        self.removeAction(forKey: "shootingAction") // Stop the old timer
        setupShooting() // Restart with the new currentFireRate
    }

    // MARK: - SKPhysicsContactDelegate Methods

    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody

        // Ensure bodies are ordered by category bitmask
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }

        // Projectile vs Gate
        if firstBody.categoryBitMask == PhysicsCategory.projectile && secondBody.categoryBitMask == PhysicsCategory.gate {
            if let projectile = firstBody.node as? SKSpriteNode, let gate = secondBody.node as? GateNode {
                projectileDidCollideWithGate(projectile: projectile, gate: gate)
            }
        }
        // Projectile vs Barrel
        else if firstBody.categoryBitMask == PhysicsCategory.projectile && secondBody.categoryBitMask == PhysicsCategory.barrel {
            if let projectile = firstBody.node as? SKSpriteNode, let barrel = secondBody.node as? BarrelNode {
                projectileDidCollideWithBarrel(projectile: projectile, barrel: barrel)
            }
        }
        // Projectile vs Zombie
        else if firstBody.categoryBitMask == PhysicsCategory.projectile && secondBody.categoryBitMask == PhysicsCategory.zombie {
            if let projectile = firstBody.node as? SKSpriteNode, let zombie = secondBody.node as? ZombieNode {
                projectileDidCollideWithZombie(projectile: projectile, zombie: zombie)
            }
        }
        // Player vs Gate
        else if firstBody.categoryBitMask == PhysicsCategory.player && secondBody.categoryBitMask == PhysicsCategory.gate {
            if let player = firstBody.node as? SKSpriteNode, let gate = secondBody.node as? GateNode {
                playerDidCollideWithGate(player: player, gate: gate)
            }
        }
        // Player vs Barrel
        else if firstBody.categoryBitMask == PhysicsCategory.player && secondBody.categoryBitMask == PhysicsCategory.barrel {
            if let player = firstBody.node as? SKSpriteNode, let barrel = secondBody.node as? BarrelNode {
                playerDidCollideWithBarrel(player: player, barrel: barrel)
            }
        }
        // Player vs Zombie
        else if firstBody.categoryBitMask == PhysicsCategory.player && secondBody.categoryBitMask == PhysicsCategory.zombie {
            if let player = firstBody.node as? SKSpriteNode, let zombie = secondBody.node as? ZombieNode {
                playerDidCollideWithZombie(player: player, zombie: zombie)
            }
        }
         // Crowd Member vs Barrel (Handle per-member hit)
        else if firstBody.categoryBitMask == PhysicsCategory.barrel && secondBody.categoryBitMask == PhysicsCategory.crowdMember {
            if let barrel = firstBody.node as? BarrelNode, let member = secondBody.node as? SKSpriteNode {
                crowdMemberDidCollideWithBarrel(member: member, barrel: barrel)
            }
        } 
        // Crowd Member vs Zombie (Sacrifice)
        else if firstBody.categoryBitMask == PhysicsCategory.zombie && secondBody.categoryBitMask == PhysicsCategory.crowdMember {
            if let zombie = firstBody.node as? ZombieNode, let member = secondBody.node as? SKSpriteNode {
                 crowdMemberDidCollideWithZombie(member: member, zombie: zombie)
            }
        }
    }

    // MARK: - Collision Handling Functions

    func projectileDidCollideWithGate(projectile: SKSpriteNode, gate: GateNode) {
        print("Projectile hit Gate")
        projectile.removeFromParent() // Remove projectile
        gate.hitByProjectile()
    }

    func projectileDidCollideWithBarrel(projectile: SKSpriteNode, barrel: BarrelNode) {
        print("Projectile hit Barrel (Type: \(barrel.type), Before Hit Value: \(barrel.currentValue))")
        projectile.removeFromParent() // Remove projectile
        
        let wasDepletedBeforeHit = barrel.isDepleted
        barrel.hitByProjectile() // Barrel handles its own value/depletion
        let isDepletedAfterHit = barrel.isDepleted // Check status *after* hit

        // Check if the barrel was *just* depleted by this hit AND is a fire rate barrel
        if !wasDepletedBeforeHit && isDepletedAfterHit && barrel.type == .fireRateUp {
            print("Fire Rate Barrel Depleted by Projectile - Increasing Fire Rate!")
            self.increaseFireRate() // Call the fire rate increase function
        }
        // Note: The barrel removes itself in its depleteBarrel method if currentValue <= 0
    }

    func projectileDidCollideWithZombie(projectile: SKSpriteNode, zombie: ZombieNode) {
        print("Projectile hit Zombie")
        projectile.removeFromParent() // Remove projectile
        // zombie.removeFromParent() // Remove zombie
        zombie.die() // Trigger death animation sequence
    }

    func playerDidCollideWithGate(player: SKSpriteNode, gate: GateNode) {
        print("Player hit Gate")
        let valueChange = gate.playerContact() // Get value directly
        
        if valueChange > 0 {
            addCrowdMembers(count: valueChange)
        } else if valueChange < 0 {
            removeCrowdMembers(count: abs(valueChange))
        }
        
        // Gate should be removed immediately after player contact regardless of value
        // It might manage its own removal in some cases, but let's ensure it here.
        gate.removeFromParent() 
    }

    func playerDidCollideWithBarrel(player: SKSpriteNode, barrel: BarrelNode) {
        print("Player hit Barrel")
        // Check if contact is hazardous (returns true if active hazard barrel)
        let isHazard = barrel.playerContact()
        
        if isHazard {
            print("Player hit ACTIVE Hazard Barrel - GAME OVER!")
            gameOver()
        } else {
            // Player contacted a non-hazard barrel (FR+) or a depleted one.
            // Do nothing specific here, barrel removal is handled by depletion logic.
            print("Player contacted non-hazard or depleted barrel.")
            // Check if it was depleted just now (though player contact doesn't deplete FR+ barrels)
            if barrel.isDepleted {
                 // Already handled by depleteBarrel
            }
        }
    }

    func playerDidCollideWithZombie(player: SKSpriteNode, zombie: ZombieNode) {
        print("Player hit Zombie")
        // zombie.removeFromParent() // Remove zombie
        zombie.die() // Trigger death animation
        gameOver() // Player hitting zombie is game over
    }
    
    func crowdMemberDidCollideWithBarrel(member: SKSpriteNode, barrel: BarrelNode) {
        print("Crowd member hit Barrel")
        // Check if contact is hazardous
        let isHazard = barrel.playerContact()

        if isHazard {
            print("Crowd member hit ACTIVE Hazard Barrel - removing member.")
            removeSpecificCrowdMember(member: member) // Remove the specific member
            // Barrel persists if it's a hazard, to hit more members potentially
        } else {
             // Crowd member contacted a non-hazard barrel (FR+) or a depleted one.
             // Do nothing specific, barrel removal handled by depletion.
             print("Crowd member contacted non-hazard or depleted barrel.")
        }
    }

    func crowdMemberDidCollideWithZombie(member: SKSpriteNode, zombie: ZombieNode) {
        print("Crowd member sacrificed for Zombie")
        removeSpecificCrowdMember(member: member) // Remove the crowd member
        // zombie.removeFromParent() // Remove the zombie
        zombie.die() // Zombie dies when it takes out a crowd member
    }

    // ... other functions (addCrowdMembers, removeCrowdMembers, gameOver etc.) ...
    
    // MARK: - Object Creation Helpers

    // ... createGate, createBarrel ...

    func createZombie() -> ZombieNode {
        // Ensure the animation assets have been loaded
        guard !zombieWalkTextures.isEmpty, let dieAction = zombieDieAction else {
            // Fallback: Create a basic node if animations failed to load
            print("CRITICAL ERROR: Zombie animation assets not ready! Returning basic node.")
            // Correct SKTexture initializer and UIColor reference
            let fallbackPixelData = Data([0xFF, 0x00, 0x00, 0xFF]) // Red pixel RGBA
            let fallbackSize = CGSize(width: 1, height: 1)
            let placeholderTexture = SKTexture(data: fallbackPixelData, size: fallbackSize)
            let basicZombie = ZombieNode(walkTextures: [placeholderTexture], dieAction: SKAction()) // Pass dummy assets
            basicZombie.colorBlendFactor = 1.0 // Ensure color is visible
            basicZombie.color = UIColor.red // Correct UIColor reference
            basicZombie.size = CGSize(width: 10, height: 10)
            return basicZombie
        }
        // Use the initializer that takes the preloaded walk textures and die action
        return ZombieNode(walkTextures: zombieWalkTextures, dieAction: dieAction)
    }

    // ... spawnObjectRow ...

    func preloadZombieAssets() {
        zombieAtlas = SKTextureAtlas(named: "Zombie") // Ensure 'Zombie.atlas' exists in Assets.xcassets

        guard let atlas = zombieAtlas else {
            print("Error: Could not load Zombie texture atlas")
            return
        }

        // Load walking textures (tile130.png to tile138.png)
        for i in 130...138 {
            let textureName = "tile\(i).png"
            zombieWalkTextures.append(atlas.textureNamed(textureName))
        }

        // Load dying textures (tile260.png to tile265.png)
        for i in 260...265 {
            let textureName = "tile\(i).png"
            zombieDieTextures.append(atlas.textureNamed(textureName))
        }

        // Create animation actions
        if !zombieWalkTextures.isEmpty {
            let walkAnimation = SKAction.animate(with: zombieWalkTextures, timePerFrame: 0.1) // Adjust timePerFrame as needed
            zombieWalkAction = SKAction.repeatForever(walkAnimation)
        }

        if !zombieDieTextures.isEmpty {
            // Create the die animation *without* repeating
            zombieDieAction = SKAction.animate(with: zombieDieTextures, timePerFrame: 0.1) // Adjust timePerFrame as needed
        }
        
        print("Zombie assets loaded: Walk frames: \(zombieWalkTextures.count), Die frames: \(zombieDieTextures.count)")
        if zombieWalkAction == nil { print("Warning: Zombie walk action not created.") }
        if zombieDieAction == nil { print("Warning: Zombie die action not created.") }
    }

    // ... other functions (addCrowdMembers, removeCrowdMembers, gameOver etc.) ...

    // MARK: - UI Setup & Updates (Re-added)
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

    // MARK: - Crowd Management (Re-added)
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
        let actualRemovalCount = min(count, crowdMembers.count) // Don't remove more than exist
        
        guard actualRemovalCount > 0 else {
             if count > 0 && crowdMembers.isEmpty {
                 // Tried to remove members, but only player leader remains - GAME OVER
                 print("Removal request exceeds crowd size (only player leader left). Game Over.")
                 gameOver()
             }
             return
        }
        
        for _ in 0..<actualRemovalCount {
            if let memberToRemove = crowdMembers.popLast() {
                memberToRemove.removeFromParent()
            }
        }
        crowdCount = 1 + crowdMembers.count
         print("Crowd count now: \(crowdCount)")
        updateCrowdLabel() // Update UI
    }
    
    // Remove a specific member (used in collisions)
    func removeSpecificCrowdMember(member: SKSpriteNode) {
        guard let index = crowdMembers.firstIndex(of: member) else {
            print("Warning: Tried to remove a specific crowd member not found in array.")
            member.removeFromParent() // Still try to remove it from scene just in case
            return
        }
        
        crowdMembers.remove(at: index)
        member.removeFromParent()
        crowdCount = 1 + crowdMembers.count
        print("Removed specific member. Crowd count now: \(crowdCount)")
        updateCrowdLabel()
    }
    
    // MARK: - Zombie Spawner (Re-added)
    func setupZombieSpawner() {
        let waitAction = SKAction.wait(forDuration: zombieSpawnTickInterval)
        let spawnAttemptAction = SKAction.run { [weak self] in
            self?.attemptToSpawnZombie()
        }
        let sequenceAction = SKAction.sequence([waitAction, spawnAttemptAction])
        let repeatAction = SKAction.repeatForever(sequenceAction)
        self.run(repeatAction, withKey: "zombieSpawnerAction")
    }

    func attemptToSpawnZombie() {
        // Calculate current probability based on difficulty (linear interpolation)
        let difficultyProgress = max(0, min(1, (difficultyFactor - 1.0) / (maxDifficultyFactor - 1.0))) // Clamp progress 0-1
        let currentProbability = zombieSpawnBaseProbability + (zombieSpawnMaxProbability - zombieSpawnBaseProbability) * Double(difficultyProgress)
        
        if Double.random(in: 0...1) < currentProbability {
            // Spawn a zombie!
            guard lanePositions.count == 3 else { 
                 print("Error: Lane positions not set up correctly for zombie spawn.")
                 return 
            }
            let centerLaneX = lanePositions[1]
            let laneWidth = abs(lanePositions[0] - lanePositions[1]) // Assuming equal lanes
            let halfLaneWidth = laneWidth / 2
            // Add padding so zombies don't spawn exactly on the lane edge
            let padding: CGFloat = 20.0 
            let randomOffsetX = CGFloat.random(in: -(halfLaneWidth - padding)...(halfLaneWidth - padding))
            
            let spawnX = centerLaneX + randomOffsetX
            let spawnY = (size.height / 2) - worldNode.position.y + 100 // Above screen top, relative to world
            
            let zombie = createZombie() // Use updated helper
            addNodeToLayer(zombie, position: CGPoint(x: spawnX, y: spawnY), description: "Zombie")
        }
    }

    // MARK: - Game Over (Re-added)
    func gameOver() {
        // Prevent multiple calls
        guard player != nil else { return }
        
        print("--- GAME OVER --- Triggered")
        
        // Stop game actions
        self.isPaused = true // Pause the scene itself is simpler
        self.removeAllActions() // Stop scene-level actions like spawners
        objectLayer.isPaused = true
        projectileLayer.removeAllChildren()

        // Visual feedback (optional)
        player?.removeFromParent()
        player = nil // Nil out player reference
        for member in crowdMembers {
            member.removeFromParent()
        }
        crowdMembers.removeAll()
        crowdCount = 0
        updateCrowdLabel() // Show 0 crowd
        
        // --- High Score Logic ---
        let defaults = UserDefaults.standard
        let highScoreKey = "highScore"
        let currentHighScore = defaults.integer(forKey: highScoreKey)

        if score > currentHighScore {
            defaults.set(score, forKey: highScoreKey)
            print("New High Score! \(score) saved.")
        } else {
            print("Score \(score) did not beat high score \(currentHighScore).")
        }
        // ------------------------

        // Transition after a short delay
        let wait = SKAction.wait(forDuration: 1.5) // Longer delay to see effect
        let transitionAction = SKAction.run { [weak self] in
            self?.transitionToGameOverScene()
        }
        // Run the transition sequence on the view's scene (which might be self, but safer this way)
        self.view?.scene?.run(SKAction.sequence([wait, transitionAction]))
    }

    func transitionToGameOverScene() {
        guard let view = self.view else { return }
        
        let gameOverScene = GameOverScene(size: view.bounds.size, score: self.score)
        gameOverScene.scaleMode = self.scaleMode
        
        let transition = SKTransition.fade(withDuration: 1.0)
        view.presentScene(gameOverScene, transition: transition)
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
