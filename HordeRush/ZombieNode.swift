import SpriteKit

class ZombieNode: SKSpriteNode {

    // Constants for appearance (adjust later with actual art)
    private let zombieSize = CGSize(width: 30, height: 30) // Similar to player size
    private let zombieColor = UIColor.green // Placeholder color

    init() {
        // Initialize the SKSpriteNode part
        super.init(texture: nil, color: zombieColor, size: zombieSize)

        // Setup Physics Body
        setupPhysicsBody()
        
        // Basic animation (optional placeholder)
        // addWiggleAnimation()
    }

    // Required initializer
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysicsBody() {
        physicsBody = SKPhysicsBody(rectangleOf: self.size)
        physicsBody?.isDynamic = false // Zombies move only due to world scroll
        physicsBody?.categoryBitMask = PhysicsCategory.zombie
        physicsBody?.collisionBitMask = PhysicsCategory.none // No physical collisions
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.player // Detect hits
    }
    
    // Optional: Add a simple animation for visual feedback
    /*
    private func addWiggleAnimation() {
        let wiggleLeft = SKAction.rotate(byAngle: .pi / 16, duration: 0.2)
        let wiggleRight = SKAction.rotate(byAngle: -.pi / 16, duration: 0.2)
        let sequence = SKAction.sequence([wiggleLeft, wiggleRight, wiggleRight.reversed(), wiggleLeft.reversed()])
        let repeatWiggle = SKAction.repeatForever(sequence)
        self.run(repeatWiggle)
    }
    */
    
    // Called when hit by projectile (basic version, just gets removed)
    func hitByProjectile() {
        print("Zombie hit by projectile")
        // Could add health logic here later
        removeFromParent()
    }
    
    // Called when player contacts (basic version, just gets removed)
    func playerContact() {
         print("Zombie contacted player")
        // Could trigger damage effects here later
        removeFromParent()
    }
} 