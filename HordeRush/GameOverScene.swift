import SpriteKit

class GameOverScene: SKScene {

    let finalScore: Int

    // Custom initializer to accept the score
    init(size: CGSize, score: Int) {
        self.finalScore = score
        super.init(size: size)
        // Adjust anchor point if needed (default is 0,0)
        // self.anchorPoint = CGPoint(x: 0.5, y: 0.5) 
    }

    // Required initializer
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor.black

        // Game Over Label
        let gameOverLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        gameOverLabel.text = "Game Over"
        gameOverLabel.fontSize = 48
        gameOverLabel.fontColor = SKColor.red
        gameOverLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.7)
        addChild(gameOverLabel)

        // Final Score Label
        let scoreLabel = SKLabelNode(fontNamed: "ArialMT")
        scoreLabel.text = "Final Score: \(finalScore)"
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = SKColor.white
        scoreLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.55)
        addChild(scoreLabel)
        
        // TODO: Add High Score display later using UserDefaults

        // Retry Button
        let retryButton = SKLabelNode(fontNamed: "Arial-BoldMT")
        retryButton.text = "Retry"
        retryButton.fontSize = 30
        retryButton.fontColor = SKColor.green
        retryButton.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.4)
        retryButton.name = "retryButton"
        addChild(retryButton)

        // Main Menu Button
        let menuButton = SKLabelNode(fontNamed: "Arial-BoldMT")
        menuButton.text = "Main Menu"
        menuButton.fontSize = 24
        menuButton.fontColor = SKColor.lightGray
        menuButton.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.25)
        menuButton.name = "menuButton"
        addChild(menuButton)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = self.atPoint(location)

        if touchedNode.name == "retryButton" {
            print("Retry button tapped!")
            transitionToGameScene()
        } else if touchedNode.name == "menuButton" {
             print("Menu button tapped!")
            transitionToMainMenuScene()
        }
    }
    
    func transitionToGameScene() {
         guard let view = self.view else { return }
         let gameScene = GameScene(size: view.bounds.size)
         gameScene.scaleMode = self.scaleMode
         let transition = SKTransition.fade(withDuration: 0.5)
         view.presentScene(gameScene, transition: transition)
     }
     
     func transitionToMainMenuScene() {
         guard let view = self.view else { return }
         let mainMenuScene = MainMenuScene(size: view.bounds.size)
         mainMenuScene.scaleMode = self.scaleMode
         let transition = SKTransition.fade(withDuration: 0.5)
         view.presentScene(mainMenuScene, transition: transition)
     }
} 