import SpriteKit

class MainMenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.black // Dark theme for menu

        // Game Title
        let titleLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        titleLabel.text = "HordeRush"
        titleLabel.fontSize = 48
        titleLabel.fontColor = SKColor.white
        titleLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.7)
        // Adjust anchor point if using scene's default (0,0)
        // titleLabel.position = CGPoint(x: frame.midX, y: frame.maxY * 0.7)
        addChild(titleLabel)

        // Play Button
        let playButton = SKLabelNode(fontNamed: "Arial-BoldMT")
        playButton.text = "Play"
        playButton.fontSize = 36
        playButton.fontColor = SKColor.green
        playButton.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.4)
        // Adjust anchor point if using scene's default (0,0)
        // playButton.position = CGPoint(x: frame.midX, y: frame.midY)
        playButton.name = "playButton" // Assign name for touch detection
        addChild(playButton)
        
        // Optional: Add instructions or logo
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = self.atPoint(location)

        if touchedNode.name == "playButton" {
            print("Play button tapped!")
            // Transition to GameScene
            transitionToGameScene()
        }
    }
    
    func transitionToGameScene() {
         guard let view = self.view else { return }

         let gameScene = GameScene(size: view.bounds.size)
         gameScene.scaleMode = self.scaleMode // Use the same scale mode

         let transition = SKTransition.fade(withDuration: 1.0) // Example transition
         view.presentScene(gameScene, transition: transition)
     }
} 