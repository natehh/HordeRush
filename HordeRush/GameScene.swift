//
//  GameScene.swift
//  HordeRush
//
//  Created by Nathan Herr on 4/23/25.
//

import SpriteKit
// Remove GameplayKit import if not immediately needed
// import GameplayKit

class GameScene: SKScene {

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

        // Setup player
        setupPlayer()

        // Start the shooting timer
        setupShooting()

        // Setup physics world contact delegate
        // physicsWorld.contactDelegate = self

        // setupUI()
    }

    func setupPlayer() {
        // Create Player sprite (placeholder)
        player = SKSpriteNode(color: .blue, size: CGSize(width: 32, height: 32)) // Use 32x32 as per plan
        // Position near the bottom-center
        player?.position = CGPoint(x: 0, y: -size.height / 2 + (player?.size.height ?? 0) + 50)
        player?.zPosition = 10 // Ensure player is visually above other elements later

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
