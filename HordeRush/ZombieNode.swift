import SpriteKit

class ZombieNode: SKSpriteNode {

    // Constants for appearance (adjust later with actual art)
    // private let zombieSize = CGSize(width: 30, height: 30) // Size will now come from texture
    private let placeholderColor = UIColor.green // Fallback if texture fails

    // Textures and Animation Actions
    private var walkTextures: [SKTexture] = []
    private var dieAnimation: SKAction? // Keep die action as is

    // Initializer now takes textures for walking and action for dying
    init(walkTextures: [SKTexture], dieAction: SKAction) {
        self.walkTextures = walkTextures
        self.dieAnimation = dieAction

        // Use the first texture from the walk sequence for initialization
        let texture = walkTextures.first
        
        let size = texture?.size() ?? CGSize(width: 30, height: 30) // Use texture size or fallback

        super.init(texture: texture, color: placeholderColor, size: size)

        // Setup Physics Body
        setupPhysicsBody()

        // Create and run the walking animation internally
        if !walkTextures.isEmpty {
            let walkAnimationAction = SKAction.animate(with: walkTextures, timePerFrame: 0.1) // Adjust time as needed
            let repeatWalk = SKAction.repeatForever(walkAnimationAction)
            self.run(repeatWalk, withKey: "walking")
        } else {
             print("Warning: ZombieNode initialized with no walk textures.")
        }
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
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.player | PhysicsCategory.crowdMember // Detect hits from player, projectiles, AND crowd
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
    
    // Called when hit by projectile or contacts player/crowd (triggers death)
    func die() {
        print("Zombie died")
        physicsBody = nil // Prevent further physics interactions during death animation
        removeAction(forKey: "walking")

        if let deathSequence = dieAnimation {
             // Run death animation then remove the node
            let sequence = SKAction.sequence([deathSequence, SKAction.removeFromParent()])
            run(sequence)
        } else {
            // Fallback if animation fails
            removeFromParent()
        }
    }
    
    // Called when hit by projectile (basic version, just gets removed)
    // func hitByProjectile() {
    //     print("Zombie hit by projectile")
    //     // Could add health logic here later
    //     // removeFromParent() // Replaced by die()
    //     die()
    // }
    
    // Called when player contacts (basic version, just gets removed)
    // func playerContact() {
    //      print("Zombie contacted player")
    //     // Could trigger damage effects here later
    //     // removeFromParent() // Replaced by die()
    //      die()
    // }
} 