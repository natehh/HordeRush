import SpriteKit

// Enum to define barrel types
enum BarrelType {
    case hazard
    case fireRateUp
}

class BarrelNode: SKSpriteNode {

    let type: BarrelType
    var currentValue: Int // Health for hazard, maybe required hits for fireRateUp?
    let valueLabel: SKLabelNode
    var isDepleted: Bool = false

    // Constants for appearance
    private let barrelSize = CGSize(width: 40, height: 60) // Adjust as needed
    private let hazardColor = UIColor.brown
    private let fireRateUpColor = UIColor.purple // Different color for FR boost
    private let depletedColor = UIColor.gray
    private let labelFontSize: CGFloat = 18.0

    // Designated Initializer
    init(type: BarrelType, initialValue: Int) {
        self.type = type
        self.currentValue = max(1, initialValue) // For hazard, this is health. For FR+, maybe hits required?
        self.valueLabel = SKLabelNode(fontNamed: "Arial-BoldMT")

        let nodeColor = (type == .hazard) ? hazardColor : fireRateUpColor
        super.init(texture: nil, color: nodeColor, size: barrelSize)

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
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.player | PhysicsCategory.crowdMember
    }

    private func updateLabel() {
        switch type {
        case .hazard:
            valueLabel.text = "\(currentValue)"
        case .fireRateUp:
            // Display remaining hits for FR+ barrels
            valueLabel.text = "FR (\(currentValue))"
        }
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
        
        switch type {
        case .hazard:
            print("Hazard barrel depleted.")
            // This type just gets removed
        case .fireRateUp:
            print("Fire Rate Up barrel depleted! (Effect handled by GameScene)")
            // GameScene will detect this depletion and apply the effect
        }
        
        // Remove the barrel immediately when depleted
        // Note: GameScene needs to check the type *before* it gets removed in collision
        self.removeFromParent()
    }

    // Called when the player/crowd contacts the barrel
    // Returns true if the barrel is a hazard, false otherwise
    func playerContact() -> Bool {
        guard !isDepleted else {
            // print("Contacted depleted barrel.") // Less verbose logging
            return false // Not a hazard
        }
        
        // Only hazard barrels are dangerous on contact
        if type == .hazard {
            print("Contacted ACTIVE hazard barrel! Hazard!")
            return true
        } else {
            // print("Contacted active Fire Rate Up barrel (not a hazard).") // Less verbose logging
            return false // Fire rate barrels aren't contact hazards
        }
    }
} 