import SpriteKit

class GateNode: SKSpriteNode {

    var currentValue: Int
    let valueLabel: SKLabelNode

    // Textures & Animations (passed in from GameScene)
    private let greenClosedTexture: SKTexture?
    private let redClosedTexture: SKTexture?
    private let greenOpenAnimation: SKAction?
    private let redOpenAnimation: SKAction?

    // Constants for appearance (can be adjusted)
    // private let gateSize = CGSize(width: 80, height: 40) // Size will now come from texture
    // private let initialColor = UIColor.red.withAlphaComponent(0.7) // Color will be from texture
    // private let positiveColor = UIColor.green.withAlphaComponent(0.7)
    private let labelFontSize: CGFloat = 20.0

    init(initialValue: Int, 
         greenClosed: SKTexture?, redClosed: SKTexture?, 
         greenOpenAnim: SKAction?, redOpenAnim: SKAction?, 
         defaultSize: CGSize) {
            
        self.currentValue = initialValue
        self.valueLabel = SKLabelNode(fontNamed: "Arial-BoldMT") 

        self.greenClosedTexture = greenClosed
        self.redClosedTexture = redClosed
        self.greenOpenAnimation = greenOpenAnim
        self.redOpenAnimation = redOpenAnim

        // Determine initial texture and size
        let initialTexture = currentValue >= 1 ? greenClosedTexture : redClosedTexture
        let nodeSize = initialTexture?.size() ?? defaultSize

        super.init(texture: initialTexture, color: .clear, size: nodeSize) // Use .clear color if texture is primary

        // Configure the label
        valueLabel.fontSize = labelFontSize
        valueLabel.fontColor = .white
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = CGPoint(x: 0, y: -5) // Move label 5 points down from center
        valueLabel.zPosition = 1 
        addChild(valueLabel)
        
        updateLabel() // Set initial text and texture based on value

        setupPhysicsBody()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPhysicsBody() {
        physicsBody = SKPhysicsBody(rectangleOf: self.size)
        physicsBody?.isDynamic = false 
        physicsBody?.categoryBitMask = PhysicsCategory.gate
        physicsBody?.collisionBitMask = PhysicsCategory.none 
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.player 
    }

    private func updateLabel() {
        valueLabel.text = "\(currentValue)"
        // Change gate texture based on value
        if currentValue >= 1 {
            if self.texture != greenClosedTexture {
                self.texture = greenClosedTexture
                if greenClosedTexture == nil { print("Warning: greenClosedTexture is nil in updateLabel") }
            }
        } else {
            if self.texture != redClosedTexture {
                self.texture = redClosedTexture
                if redClosedTexture == nil { print("Warning: redClosedTexture is nil in updateLabel") }
            }
        }
        // Adjust size if texture changed and new texture has a different size
        if let newTexture = self.texture, newTexture.size() != self.size && newTexture.size() != .zero {
            self.size = newTexture.size()
            // Re-setup physics body if size changes, to match new visuals
            // This might be too expensive if called frequently. Consider if size changes are expected.
            // setupPhysicsBody() 
        }
    }

    func hitByProjectile() {
        currentValue += 1
        updateLabel()
        let pulseUp = SKAction.scale(to: 1.1, duration: 0.05)
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.05)
        let pulseSequence = SKAction.sequence([pulseUp, pulseDown])
        self.run(pulseSequence)
    }

    // Modified to play animation and then call completion with its value
    func playerContact(completion: @escaping (Int) -> Void) {
        print("Player contacted gate. Final value: \(currentValue). Playing animation.")
        
        // Call completion handler immediately with the gate's value
        // GameScene will use this to update crowd count *before* animation starts
        completion(currentValue)

        // Determine which animation to play
        let openAnimation: SKAction?
        if currentValue >= 1 {
            openAnimation = greenOpenAnimation
        } else {
            openAnimation = redOpenAnimation
        }

        if let anim = openAnimation {
            let sequence = SKAction.sequence([anim, SKAction.removeFromParent()])
            self.run(sequence)
        } else {
            // Fallback: if no animation, remove immediately
            print("Warning: No open animation found for gate. Removing directly.")
            self.removeFromParent()
        }
    }
} 