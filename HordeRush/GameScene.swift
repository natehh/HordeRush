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
    private var lastTouchLocation: CGPoint? // Stores the last position of the touch

    // Projectile Properties
    private let projectileSize = CGSize(width: 5, height: 10)
    private let projectileColor = UIColor.yellow // Use yellow for visibility
    private let projectileSpeed: CGFloat = 600.0 // Points per second
    private let fireRate: TimeInterval = 0.2 // Seconds between shots (5 shots/sec)

    override func didMove(to view: SKView) {
        // Setup scene
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .darkGray

        // Setup physics world
        physicsWorld.gravity = CGVector(dx: 0, dy: 0) // No gravity
        physicsWorld.contactDelegate = self // Set contact delegate

        // Setup player
        setupPlayer()

        // Start the shooting timer
        setupShooting()

        // setupUI()
    }

    func setupPlayer() {
        // Create Player sprite (placeholder)
        player = SKSpriteNode(color: .blue, size: CGSize(width: 32, height: 32)) // Use 32x32 as per plan
        // Position near the bottom-center
        player?.position = CGPoint(x: 0, y: -size.height / 2 + (player?.size.height ?? 0) + 50)
        player?.zPosition = 10 // Ensure player is visually above other elements later

        // Add physics body to player
        player?.physicsBody = SKPhysicsBody(rectangleOf: player!.size)
        player?.physicsBody?.isDynamic = true
        player?.physicsBody?.affectedByGravity = false
        player?.physicsBody?.allowsRotation = false
        player?.physicsBody?.categoryBitMask = PhysicsCategory.player
        player?.physicsBody?.collisionBitMask = PhysicsCategory.none // No physical collisions for now
        // Define what player contacts should be detected
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
        // Ensure player exists and get its position
        guard let player = self.player else { return }
        let startPosition = player.position

        // Create the projectile node
        let projectile = SKSpriteNode(color: projectileColor, size: projectileSize)
        projectile.position = CGPoint(x: startPosition.x, y: startPosition.y + player.size.height / 2) // Start slightly ahead of player
        projectile.zPosition = 9 // Behind player, but above background/other layers

        // Add physics body to projectile
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.allowsRotation = false
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none // No physical collisions
        // Define what projectile contacts should be detected
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.gate | PhysicsCategory.barrel | PhysicsCategory.zombie

        // Add to scene
        addChild(projectile)

        // --- Calculate movement --- 
        // Destination y-coordinate (well off the top screen edge)
        let destinationY = size.height / 2 + projectile.size.height
        // Distance to travel
        let distance = destinationY - projectile.position.y
        // Time = Distance / Speed
        let duration = TimeInterval(distance / projectileSpeed)

        // Create actions
        let moveAction = SKAction.moveTo(y: destinationY, duration: duration)
        let removeAction = SKAction.removeFromParent() // Action to remove the node

        // Combine actions into a sequence
        let sequenceAction = SKAction.sequence([moveAction, removeAction])

        // Run the sequence on the projectile
        projectile.run(sequenceAction)
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
        // Called before each frame is rendered
        // Game logic updates (scrolling, spawning, movement) will go here
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

        // Check for specific collision pairs
        if (firstBody.categoryBitMask == PhysicsCategory.projectile) && (secondBody.categoryBitMask == PhysicsCategory.gate) {
            // Projectile hit Gate
            print("Projectile hit Gate")
            // Logic to increment gate value and destroy projectile will go here
            if let projectileNode = firstBody.node {
                 projectileDidCollideWithGate(projectile: projectileNode, gate: secondBody.node)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.projectile) && (secondBody.categoryBitMask == PhysicsCategory.barrel) {
            // Projectile hit Barrel
            print("Projectile hit Barrel")
            // Logic to decrement barrel value and destroy projectile will go here
            if let projectileNode = firstBody.node {
                 projectileDidCollideWithBarrel(projectile: projectileNode, barrel: secondBody.node)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.projectile) && (secondBody.categoryBitMask == PhysicsCategory.zombie) {
            // Projectile hit Zombie
            print("Projectile hit Zombie")
            // Logic to damage/destroy zombie and destroy projectile will go here
            if let projectileNode = firstBody.node {
                 projectileDidCollideWithZombie(projectile: projectileNode, zombie: secondBody.node)
            }
        } else if (firstBody.categoryBitMask == PhysicsCategory.player) && (secondBody.categoryBitMask == PhysicsCategory.gate) {
            // Player hit Gate
            print("Player hit Gate")
            // Logic to apply gate effect (+/- crowd) will go here
            playerDidCollideWithGate(player: firstBody.node, gate: secondBody.node)
        } else if (firstBody.categoryBitMask == PhysicsCategory.player) && (secondBody.categoryBitMask == PhysicsCategory.barrel) {
            // Player hit Barrel
            print("Player hit Barrel")
            // Logic to handle barrel hazard will go here
             playerDidCollideWithBarrel(player: firstBody.node, barrel: secondBody.node)
        } else if (firstBody.categoryBitMask == PhysicsCategory.player) && (secondBody.categoryBitMask == PhysicsCategory.zombie) {
            // Player hit Zombie
            print("Player hit Zombie")
            // Logic for game over or player damage will go here
            playerDidCollideWithZombie(player: firstBody.node, zombie: secondBody.node)
        }
        // Add more collision checks as needed
    }

    // Placeholder collision handling functions
    func projectileDidCollideWithGate(projectile: SKNode?, gate: SKNode?) {
        print("Handling Projectile-Gate collision")
        projectile?.removeFromParent() // Example: Remove projectile
        // Add logic to update gate value here later
    }

    func projectileDidCollideWithBarrel(projectile: SKNode?, barrel: SKNode?) {
        print("Handling Projectile-Barrel collision")
        projectile?.removeFromParent() // Example: Remove projectile
        // Add logic to update barrel value here later
    }

    func projectileDidCollideWithZombie(projectile: SKNode?, zombie: SKNode?) {
        print("Handling Projectile-Zombie collision")
        projectile?.removeFromParent() // Example: Remove projectile
        zombie?.removeFromParent()     // Example: Remove zombie
        // Add score update etc. here later
    }

    func playerDidCollideWithGate(player: SKNode?, gate: SKNode?) {
        print("Handling Player-Gate collision")
        // Logic to check gate value and adjust crowd count later
        gate?.removeFromParent() // Example: Remove gate after interaction
    }

    func playerDidCollideWithBarrel(player: SKNode?, barrel: SKNode?) {
        print("Handling Player-Barrel collision")
        // Logic to check barrel state (hazard?) and apply effect later
        // Possibly remove player/crowd members or trigger game over
        barrel?.removeFromParent() // Example: Remove barrel
    }

    func playerDidCollideWithZombie(player: SKNode?, zombie: SKNode?) {
        print("Handling Player-Zombie collision - GAME OVER (placeholder)")
        // Game Over logic will go here
        player?.removeFromParent() // Example: Remove player
        zombie?.removeFromParent() // Example: Remove zombie
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
