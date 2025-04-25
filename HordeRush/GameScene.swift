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
    static let player   : UInt32 = 0b1   // 1
    static let projectile: UInt32 = 0b10  // 2
    static let gate     : UInt32 = 0b100 // 4
    static let barrel   : UInt32 = 0b1000// 8
    static let zombie   : UInt32 = 0b10000// 16
    // Add more categories as needed
    static let all      : UInt32 = UInt32.max
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

    // Crowd Properties (Placeholder)
    var crowdCount: Int = 1

    // World Properties
    private let worldNode = SKNode()
    private let objectLayer = SKNode()       // For gates, barrels, zombies
    private let projectileLayer = SKNode()   // For projectiles
    private var backgroundTiles: [SKSpriteNode] = []
    private let scrollSpeed: CGFloat = 150.0 // Points per second for world scroll
    private var lastUpdateTime: TimeInterval = 0

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

        // Setup background
        setupBackground()

        // Setup player (added directly to scene)
        setupPlayer()

        // Start the shooting timer
        setupShooting()

        // Spawn test objects (added to objectLayer within worldNode)
        spawnTestGate()
        spawnTestBarrel()

        // setupUI()
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
        guard let player = self.player else { return }
        let startPosition = player.position

        let projectile = SKSpriteNode(color: projectileColor, size: projectileSize)
        projectile.position = CGPoint(x: startPosition.x, y: startPosition.y + player.size.height / 2)
        projectile.zPosition = 9
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.allowsRotation = false
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.gate | PhysicsCategory.barrel | PhysicsCategory.zombie

        projectileLayer.addChild(projectile)

        // Movement action remains the same, as its target Y is absolute
        let destinationY = size.height / 2 + projectile.size.height
        let distance = destinationY - projectile.position.y // Position relative to scene
        let duration = TimeInterval(distance / projectileSpeed)
        let moveAction = SKAction.moveTo(y: destinationY, duration: duration)
        let removeAction = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([moveAction, removeAction]))
    }

    func spawnTestGate() {
        let testGate = GateNode(initialValue: -50)
        // Position relative to worldNode's origin
        testGate.position = CGPoint(x: 0, y: size.height * 0.75) // Position higher up initially
        testGate.zPosition = 5
        // Add gate to the objectLayer within worldNode
        objectLayer.addChild(testGate)

        let testGate2 = GateNode(initialValue: -20)
        testGate2.position = CGPoint(x: -size.width / 4, y: size.height * 1.25) // Position even higher
        testGate2.zPosition = 5
        objectLayer.addChild(testGate2)
    }

    func spawnTestBarrel() {
        let testBarrel = BarrelNode(initialValue: 10)
        // Position relative to worldNode's origin
        testBarrel.position = CGPoint(x: size.width / 4, y: size.height * 1.0) // Position high up
        testBarrel.zPosition = 5
        // Add barrel to the objectLayer within worldNode
        objectLayer.addChild(testBarrel)
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
        // Initialize lastUpdateTime on the first frame
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        // Calculate time elapsed since last frame
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Scroll the world node
        let distanceToScroll = scrollSpeed * CGFloat(deltaTime)
        worldNode.position.y -= distanceToScroll

        // Check and reposition background tiles
        for tile in backgroundTiles {
            // Get position of the tile relative to the scene
            let tileScenePosition = convert(tile.position, from: worldNode)

            // Check if the tile's top edge is completely below the screen's bottom edge
            if tileScenePosition.y + tile.size.height / 2 < -self.size.height / 2 {
                // Move the tile up by twice its height (within worldNode coordinates)
                // so it's positioned directly above the other tile
                tile.position.y += 2 * tile.size.height
                print("Repositioned background tile") // Debug log
            }
        }
        
        // TODO: Add logic later to remove objects in objectLayer that scroll off the bottom of the screen
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

        if bodyA.categoryBitMask < bodyB.categoryBitMask {
            firstBody = bodyA
            secondBody = bodyB
        } else {
            firstBody = bodyB
            secondBody = bodyA
        }

        // Updated Collision Checks
        if (firstBody.categoryBitMask == PhysicsCategory.projectile) && (secondBody.categoryBitMask == PhysicsCategory.gate) {
            // Projectile hit Gate
            if let projectileNode = firstBody.node, let gateNode = secondBody.node as? GateNode {
                projectileDidCollideWithGate(projectile: projectileNode, gate: gateNode)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.projectile) && (secondBody.categoryBitMask == PhysicsCategory.barrel) {
            // Projectile hit Barrel 
            if let projectileNode = firstBody.node, let barrelNode = secondBody.node as? BarrelNode {
                 projectileDidCollideWithBarrel(projectile: projectileNode, barrel: barrelNode)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.projectile) && (secondBody.categoryBitMask == PhysicsCategory.zombie) {
            // Projectile hit Zombie (Keep placeholder for now)
            if let projectileNode = firstBody.node {
                 projectileDidCollideWithZombie(projectile: projectileNode, zombie: secondBody.node)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.player) && (secondBody.categoryBitMask == PhysicsCategory.gate) {
            // Player hit Gate
            if let playerNode = firstBody.node, let gateNode = secondBody.node as? GateNode {
                playerDidCollideWithGate(player: playerNode, gate: gateNode)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.player) && (secondBody.categoryBitMask == PhysicsCategory.barrel) {
            // Player hit Barrel
             if let playerNode = firstBody.node, let barrelNode = secondBody.node as? BarrelNode {
                playerDidCollideWithBarrel(player: playerNode, barrel: barrelNode)
             }
        } else if (firstBody.categoryBitMask == PhysicsCategory.player) && (secondBody.categoryBitMask == PhysicsCategory.zombie) {
            // Player hit Zombie (Keep placeholder for now)
            playerDidCollideWithZombie(player: firstBody.node, zombie: secondBody.node)
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

    func projectileDidCollideWithZombie(projectile: SKNode?, zombie: SKNode?) {
        print("Handling Projectile-Zombie collision")
        projectile?.removeFromParent()
        zombie?.removeFromParent()
        // Zombie logic later
    }

    func playerDidCollideWithGate(player: SKNode, gate: GateNode) { // Note: GateNode type
        print("Handling Player-Gate collision")
        let value = gate.playerContact() // Get the final value from the gate

        // Apply crowd effect (Placeholder logic)
        if value > 0 {
            print("Adding \(value) to crowd")
            crowdCount += value
        } else {
            // Only subtract if the value is still negative AND non-zero
            // (Could refine this rule - e.g., always subtract if negative?)
            if value < 0 {
                 print("Subtracting \(abs(value)) from crowd")
                 crowdCount = max(1, crowdCount + value) // Ensure crowd count doesn't go below 1 (the leader)
            }
        }
        print("New crowd count (placeholder): \(crowdCount)")
        // Update UI later

        gate.removeFromParent() // Remove gate after interaction
    }

    func playerDidCollideWithBarrel(player: SKNode, barrel: BarrelNode) { // Note: BarrelNode type
        print("Handling Player-Barrel collision")
        let isHazard = barrel.playerContact() // Check if barrel is hazardous

        if isHazard {
            // Apply hazard effect (Placeholder)
            print("*** HAZARD! Player hit active barrel. (Placeholder damage/effect) ***")
            // Implement actual effect later (e.g., lose crowd members, game over)
        } else {
            // Player passed a depleted barrel, no negative effect
             print("Player passed depleted barrel safely.")
        }

        barrel.removeFromParent() // Remove barrel after interaction
    }

    func playerDidCollideWithZombie(player: SKNode?, zombie: SKNode?) {
        print("Handling Player-Zombie collision - GAME OVER (placeholder)")
        player?.removeFromParent()
        zombie?.removeFromParent()
        // Game Over logic later
    }

    // Add custom methods for player setup, UI setup, spawning, etc. later
    // func setupPlayer() { ... }
    // func setupUI() { ... }
    // func spawnObjects() { ... }
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
