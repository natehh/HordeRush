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

    // Properties for player, score, etc. will go here later

    override func didMove(to view: SKView) {
        // Setup scene (anchor point, background color, physics world)
        anchorPoint = CGPoint(x: 0.5, y: 0.5) // Center anchor
        backgroundColor = .darkGray // Placeholder background

        // Setup physics world contact delegate
        // physicsWorld.contactDelegate = self // Uncomment when physics bodies are added

        // Add initial game elements (player, UI)
        // setupPlayer()
        // setupUI()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle initial touch for dragging
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle dragging movement
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle touch release (if needed)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle cancelled touch (if needed)
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
