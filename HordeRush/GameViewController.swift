//
//  GameViewController.swift
//  HordeRush
//
//  Created by Nathan Herr on 4/23/25.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as! SKView? {
            // Create the scene programmatically - START WITH MAIN MENU
            let scene = MainMenuScene(size: view.bounds.size)

            // Set the scale mode (adjust if needed, .resizeFill is also common)
            scene.scaleMode = .aspectFill

            // Present the scene
            view.presentScene(scene)

            // Optimisation
            view.ignoresSiblingOrder = true

            // Remove debug flags for production builds (can be re-enabled for debugging)
            // view.showsFPS = true
            // view.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Enforce portrait orientation as per the plan
        return .portrait
    }

    // Keep prefersStatusBarHidden for immersive gameplay
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
