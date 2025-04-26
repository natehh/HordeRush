import SpriteKit

class BarrelNode: SKSpriteNode {

    var currentValue: Int
    let valueLabel: SKLabelNode
    var isDepleted: Bool = false

    // Constants for appearance
    private let barrelSize = CGSize(width: 40, height: 60) // Adjust as needed
    private let activeColor = UIColor.brown
    private let depletedColor = UIColor.gray
    private let labelFontSize: CGFloat = 18.0

    init(initialValue: Int) {
        self.currentValue = max(1, initialValue) // Ensure barrels start with at least 1 health
        self.valueLabel = SKLabelNode(fontNamed: "Arial-BoldMT")

        super.init(texture: nil, color: activeColor, size: barrelSize)

        // Configure the label
        valueLabel.fontSize = labelFontSize
        valueLabel.fontColor = .white
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = CGPoint(x: 0, y: 0)
        valueLabel.zPosition = 1
        updateLabel()

        addChild(valueLabel)

        setupPhysicsBody()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysicsBody() {
        physicsBody = SKPhysicsBody(rectangleOf: self.size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.barrel
        physicsBody?.collisionBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.player
    }

    private func updateLabel() {
        valueLabel.text = "\(currentValue)"
        // Could add visual changes based on value here if needed
    }

    // Called when a projectile hits the barrel
    func hitByProjectile() {
        guard !isDepleted else { return } // Don't do anything if already depleted

        currentValue -= 1
        updateLabel()

        if currentValue <= 0 {
            depleteBarrel()
        }
        
        // Optional: Add a hit effect
        let pulseUp = SKAction.scale(to: 1.1, duration: 0.05)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.05)
        self.run(SKAction.sequence([pulseUp, pulseDown]))
    }

    private func depleteBarrel() {
        isDepleted = true
        // Trigger weapon upgrade effect (placeholder)
        print("*** Weapon Upgrade Granted! (Placeholder) ***")
        
        // Remove the barrel immediately when depleted
        self.removeFromParent()
    }

    // Called when the player passes through the barrel
    // Returns true if the barrel is a hazard, false otherwise
    func playerContact() -> Bool {
        if isDepleted {
            print("Player contacted depleted barrel.")
            return false // Not a hazard
        } else {
            print("Player contacted ACTIVE barrel! Hazard!")
            return true // Still active, it's a hazard
        }
    }
} 