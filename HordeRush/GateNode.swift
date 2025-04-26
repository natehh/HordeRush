import SpriteKit

class GateNode: SKSpriteNode {

    var currentValue: Int = 0
    let valueLabel: SKLabelNode

    // Constants for appearance (can be adjusted)
    private let gateSize = CGSize(width: 80, height: 40)
    private let initialColor = UIColor.red.withAlphaComponent(0.7)
    private let positiveColor = UIColor.green.withAlphaComponent(0.7)
    private let labelFontSize: CGFloat = 20.0

    init(initialValue: Int) {
        self.currentValue = initialValue
        self.valueLabel = SKLabelNode(fontNamed: "Arial-BoldMT") // Choose a suitable font

        // Initialize the SKSpriteNode part
        super.init(texture: nil, color: initialColor, size: gateSize)

        // Configure the label
        valueLabel.fontSize = labelFontSize
        valueLabel.fontColor = .white
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = CGPoint(x: 0, y: 0) // Centered within the gate sprite
        valueLabel.zPosition = 1 // Ensure label is above the gate background
        updateLabel() // Set initial text and color

        addChild(valueLabel)

        // Setup Physics Body
        setupPhysicsBody()
    }

    // Required initializer for SKSpriteNode subclasses
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysicsBody() {
        // Use the exact size of the node for the physics body
        physicsBody = SKPhysicsBody(rectangleOf: self.size)
        physicsBody?.isDynamic = false // Gates don't move due to collisions
        physicsBody?.categoryBitMask = PhysicsCategory.gate
        physicsBody?.collisionBitMask = PhysicsCategory.none // No physical collision response
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.player // Detect contacts
    }

    private func updateLabel() {
        valueLabel.text = "\(currentValue)"
        // Change gate color based on value (optional visual feedback)
        self.color = currentValue >= 0 ? positiveColor : initialColor
        // Could also change label color here if desired
    }

    // Called when a projectile hits the gate
    func hitByProjectile() {
        currentValue += 1
        updateLabel()

        // Optional: Add a visual effect like a quick scale pulse
        let pulseUp = SKAction.scale(to: 1.1, duration: 0.05)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.05)
        let pulseSequence = SKAction.sequence([pulseUp, pulseDown])
        self.run(pulseSequence)
    }

    // Called when the player passes through the gate
    func playerContact() -> Int {
        print("Player contacted gate with final value: \\(currentValue)")
        // Return the value so GameScene can handle the effect
        return currentValue
    }
} 