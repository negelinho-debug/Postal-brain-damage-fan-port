import UIKit
import SceneKit

final class GameViewController: UIViewController {

    // MARK: - Scene

    private let sceneView = SCNView()
    private let gameScene = SCNScene()

    private let cameraNode = SCNNode()

    private var enemies: [SCNNode] = []

    // MARK: - Player

    private var yaw: Float = 0
    private var pitch: Float = 0

    private var verticalVelocity: Float = 0
    private var isOnGround = true

    private var moveVector = CGPoint.zero

    private var dashUntil: CFTimeInterval = 0

    private var playerHealth = 100

    private var damageTimer: Float = 0

    // MARK: - Time

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    // MARK: - UI

    private let movePad = UIView()
    private let moveKnob = UIView()

    private let lookPad = UIView()

    private let fireButton = UIButton(type: .system)
    private let jumpButton = UIButton(type: .system)
    private let dashButton = UIButton(type: .system)

    private let healthLabel = UILabel()
    private let enemiesLabel = UILabel()
    private let messageLabel = UILabel()

    private let crosshair = UILabel()

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        setupSceneView()
        setupWorld()
        setupPlayer()
        setupEnemies()
        setupInterface()

        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateGame(_:))
        )

        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: .main, forMode: .common)

        self.displayLink = displayLink
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        sceneView.frame = view.bounds

        let width = view.bounds.width
        let height = view.bounds.height

        lookPad.frame = CGRect(
            x: width * 0.32,
            y: 0,
            width: width * 0.68,
            height: height
        )

        movePad.frame = CGRect(
            x: 25,
            y: height - 185,
            width: 150,
            height: 150
        )

        moveKnob.bounds = CGRect(
            x: 0,
            y: 0,
            width: 62,
            height: 62
        )

        if moveVector == .zero {
            moveKnob.center = CGPoint(
                x: movePad.bounds.midX,
                y: movePad.bounds.midY
            )
        }

        fireButton.frame = CGRect(
            x: width - 120,
            y: height - 145,
            width: 92,
            height: 92
        )

        jumpButton.frame = CGRect(
            x: width - 215,
            y: height - 100,
            width: 72,
            height: 72
        )

        dashButton.frame = CGRect(
            x: width - 215,
            y: height - 185,
            width: 72,
            height: 72
        )

        healthLabel.frame = CGRect(
            x: 20,
            y: 15,
            width: 250,
            height: 40
        )

        enemiesLabel.frame = CGRect(
            x: width - 260,
            y: 15,
            width: 240,
            height: 40
        )

        messageLabel.frame = CGRect(
            x: width / 2 - 220,
            y: 15,
            width: 440,
            height: 50
        )

        crosshair.frame = CGRect(
            x: width / 2 - 20,
            y: height / 2 - 25,
            width: 40,
            height: 50
        )
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        .all
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Scene setup

    private func setupSceneView() {

        sceneView.scene = gameScene
        sceneView.backgroundColor = UIColor(
            red: 0.04,
            green: 0.02,
            blue: 0.07,
            alpha: 1
        )

        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60

        sceneView.isPlaying = true

        view.addSubview(sceneView)
    }

    private func setupWorld() {

        gameScene.background.contents = UIColor(
            red: 0.05,
            green: 0.01,
            blue: 0.08,
            alpha: 1
        )

        // Ambient light

        let ambientNode = SCNNode()

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 700
        ambient.color = UIColor(
            red: 0.65,
            green: 0.35,
            blue: 0.8,
            alpha: 1
        )

        ambientNode.light = ambient

        gameScene.rootNode.addChildNode(ambientNode)

        // Main light

        let lightNode = SCNNode()

        let light = SCNLight()
        light.type = .omni
        light.intensity = 1600
        light.color = UIColor(
            red: 1,
            green: 0.2,
            blue: 0.45,
            alpha: 1
        )

        lightNode.light = light
        lightNode.position = SCNVector3(0, 8, 0)

        gameScene.rootNode.addChildNode(lightNode)

        // Floor

        let floorGeometry = SCNFloor()

        floorGeometry.reflectivity = 0.05

        let floorMaterial = SCNMaterial()

        floorMaterial.diffuse.contents = UIColor(
            red: 0.11,
            green: 0.04,
            blue: 0.13,
            alpha: 1
        )

        floorMaterial.roughness.contents = 0.75
        floorMaterial.metalness.contents = 0.2

        floorGeometry.materials = [floorMaterial]

        let floorNode = SCNNode(geometry: floorGeometry)

        floorNode.position.y = 0

        gameScene.rootNode.addChildNode(floorNode)

        // Arena walls

        createWall(
            position: SCNVector3(0, 3, -22),
            size: SCNVector3(40, 6, 1)
        )

        createWall(
            position: SCNVector3(0, 3, 22),
            size: SCNVector3(40, 6, 1)
        )

        createWall(
            position: SCNVector3(-20, 3, 0),
            size: SCNVector3(1, 6, 44)
        )

        createWall(
            position: SCNVector3(20, 3, 0),
            size: SCNVector3(1, 6, 44)
        )

        // Arena objects

        for x in stride(from: -12, through: 12, by: 6) {

            let box = SCNBox(
                width: 2.5,
                height: 2.5,
                length: 2.5,
                chamferRadius: 0.15
            )

            let material = SCNMaterial()

            material.diffuse.contents = UIColor(
                red: 0.15,
                green: 0.08,
                blue: 0.20,
                alpha: 1
            )

            material.emission.contents = UIColor(
                red: 0.04,
                green: 0,
                blue: 0.07,
                alpha: 1
            )

            box.materials = [material]

            let node = SCNNode(geometry: box)

            node.position = SCNVector3(
                Float(x),
                1.25,
                -8
            )

            gameScene.rootNode.addChildNode(node)
        }
    }

    private func createWall(
        position: SCNVector3,
        size: SCNVector3
    ) {

        let geometry = SCNBox(
            width: CGFloat(size.x),
            height: CGFloat(size.y),
            length: CGFloat(size.z),
            chamferRadius: 0
        )

        let material = SCNMaterial()

        material.diffuse.contents = UIColor(
            red: 0.10,
            green: 0.02,
            blue: 0.13,
            alpha: 1
        )

        material.emission.contents = UIColor(
            red: 0.03,
            green: 0,
            blue: 0.05,
            alpha: 1
        )

        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)

        node.position = position

        gameScene.rootNode.addChildNode(node)
    }

    // MARK: - Player

    private func setupPlayer() {

        let camera = SCNCamera()

        camera.fieldOfView = 82
        camera.zNear = 0.05
        camera.zFar = 250

        cameraNode.camera = camera

        cameraNode.position = SCNVector3(
            0,
            1.65,
            12
        )

        gameScene.rootNode.addChildNode(cameraNode)

        sceneView.pointOfView = cameraNode
    }

    // MARK: - Enemies

    private func setupEnemies() {

        let positions: [SCNVector3] = [

            SCNVector3(0, 1.15, -12),

            SCNVector3(-8, 1.15, -15),

            SCNVector3(8, 1.15, -15),

            SCNVector3(-12, 1.15, 2),

            SCNVector3(12, 1.15, -3)
        ]

        for position in positions {
            spawnEnemy(at: position)
        }

        updateHUD()
    }

    private func spawnEnemy(at position: SCNVector3) {

        let body = SCNCapsule(
            capRadius: 0.65,
            height: 2.3
        )

        let material = SCNMaterial()

        material.diffuse.contents = UIColor.systemPink

        material.emission.contents = UIColor(
            red: 0.25,
            green: 0,
            blue: 0.1,
            alpha: 1
        )

        body.materials = [material]

        let enemy = SCNNode(geometry: body)

        enemy.name = "enemy"
        enemy.position = position

        enemy.userData = NSMutableDictionary()
        enemy.userData?["hp"] = 3

        gameScene.rootNode.addChildNode(enemy)

        enemies.append(enemy)
    }

    // MARK: - UI

    private func setupInterface() {

        // Look area

        lookPad.backgroundColor = .clear

        let lookGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handleLook(_:))
        )

        lookGesture.maximumNumberOfTouches = 1

        lookPad.addGestureRecognizer(lookGesture)

        view.addSubview(lookPad)

        // Movement pad

        movePad.backgroundColor = UIColor(
            white: 1,
            alpha: 0.08
        )

        movePad.layer.cornerRadius = 75
        movePad.layer.borderWidth = 2
        movePad.layer.borderColor = UIColor(
            white: 1,
            alpha: 0.18
        ).cgColor

        let moveGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handleMove(_:))
        )

        movePad.addGestureRecognizer(moveGesture)

        view.addSubview(movePad)

        moveKnob.backgroundColor = UIColor(
            white: 1,
            alpha: 0.25
        )

        moveKnob.layer.cornerRadius = 31

        movePad.addSubview(moveKnob)

        // Buttons

        configureButton(
            fireButton,
            title: "FIRE",
            fontSize: 22
        )

        configureButton(
            jumpButton,
            title: "JUMP",
            fontSize: 14
        )

        configureButton(
            dashButton,
            title: "DASH",
            fontSize: 14
        )

        fireButton.addTarget(
            self,
            action: #selector(fireWeapon),
            for: .touchDown
        )

        jumpButton.addTarget(
            self,
            action: #selector(jump),
            for: .touchDown
        )

        dashButton.addTarget(
            self,
            action: #selector(dash),
            for: .touchDown
        )

        view.addSubview(fireButton)
        view.addSubview(jumpButton)
        view.addSubview(dashButton)

        // HUD

        healthLabel.textColor = .white
        healthLabel.font = UIFont.monospacedSystemFont(
            ofSize: 20,
            weight: .black
        )

        healthLabel.shadowColor = .black
        healthLabel.shadowOffset = CGSize(
            width: 2,
            height: 2
        )

        view.addSubview(healthLabel)

        enemiesLabel.textColor = .white
        enemiesLabel.textAlignment = .right

        enemiesLabel.font = UIFont.monospacedSystemFont(
            ofSize: 18,
            weight: .bold
        )

        view.addSubview(enemiesLabel)

        messageLabel.textColor = UIColor.systemPink
        messageLabel.textAlignment = .center

        messageLabel.font = UIFont.systemFont(
            ofSize: 20,
            weight: .black
        )

        view.addSubview(messageLabel)

        // Crosshair

        crosshair.text = "+"
        crosshair.textAlignment = .center
        crosshair.textColor = .white

        crosshair.font = UIFont.monospacedSystemFont(
            ofSize: 34,
            weight: .black
        )

        view.addSubview(crosshair)

        updateHUD()
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        fontSize: CGFloat
    ) {

        button.setTitle(title, for: .normal)

        button.setTitleColor(
            .white,
            for: .normal
        )

        button.titleLabel?.font = UIFont.systemFont(
            ofSize: fontSize,
            weight: .black
        )

        button.backgroundColor = UIColor(
            red: 0.75,
            green: 0.05,
            blue: 0.25,
            alpha: 0.72
        )

        button.layer.cornerRadius = 36

        button.layer.borderWidth = 2

        button.layer.borderColor = UIColor(
            white: 1,
            alpha: 0.4
        ).cgColor
    }

    // MARK: - Touch input

    @objc
    private func handleMove(
        _ gesture: UIPanGestureRecognizer
    ) {

        let translation = gesture.translation(
            in: movePad
        )

        let maxDistance: CGFloat = 48

        var x = translation.x
        var y = translation.y

        let distance = sqrt(
            x * x + y * y
        )

        if distance > maxDistance {

            let scale = maxDistance / distance

            x *= scale
            y *= scale
        }

        if gesture.state == .ended ||
           gesture.state == .cancelled ||
           gesture.state == .failed {

            moveVector = .zero

            UIView.animate(
                withDuration: 0.12
            ) {

                self.moveKnob.center = CGPoint(
                    x: self.movePad.bounds.midX,
                    y: self.movePad.bounds.midY
                )
            }

            return
        }

        moveVector = CGPoint(
            x: x / maxDistance,
            y: y / maxDistance
        )

        moveKnob.center = CGPoint(
            x: movePad.bounds.midX + x,
            y: movePad.bounds.midY + y
        )
    }

    @objc
    private func handleLook(
        _ gesture: UIPanGestureRecognizer
    ) {

        let delta = gesture.translation(
            in: lookPad
        )

        gesture.setTranslation(
            .zero,
            in: lookPad
        )

        yaw -= Float(delta.x) * 0.0045
        pitch -= Float(delta.y) * 0.0045

        pitch = max(
            -1.25,
            min(1.25, pitch)
        )

        cameraNode.eulerAngles = SCNVector3(
            pitch,
            yaw,
            0
        )
    }

    // MARK: - Weapon

    @objc
    private func fireWeapon() {

        let center = CGPoint(
            x: sceneView.bounds.midX,
            y: sceneView.bounds.midY
        )

        let results = sceneView.hitTest(
            center,
            options: nil
        )

        guard let hit = results.first else {
            flashCrosshair(hit: false)
            return
        }

        var target: SCNNode? = hit.node

        while target != nil &&
              target?.name != "enemy" {

            target = target?.parent
        }

        guard let enemy = target,
              enemy.name == "enemy"
        else {

            flashCrosshair(hit: false)
            return
        }

        damage(enemy)

        flashCrosshair(hit: true)
    }

    private func damage(_ enemy: SCNNode) {

        let oldHP =
            enemy.userData?["hp"] as? Int ?? 3

        let newHP = oldHP - 1

        enemy.userData?["hp"] = newHP

        if let material =
            enemy.geometry?.firstMaterial {

            let oldEmission =
                material.emission.contents

            material.emission.contents =
                UIColor.white

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.07
            ) {

                material.emission.contents =
                    oldEmission
            }
        }

        if newHP <= 0 {

            killEnemy(enemy)
        }
    }

    private func killEnemy(
        _ enemy: SCNNode
    ) {

        guard let index =
            enemies.firstIndex(
                where: { $0 === enemy }
            )
        else {
            return
        }

        enemies.remove(at: index)

        let scaleOut =
            SCNAction.scale(
                to: 0.05,
                duration: 0.14
            )

        let spin =
            SCNAction.rotateBy(
                x: 0,
                y: CGFloat.pi * 2,
                z: CGFloat.pi,
                duration: 0.14
            )

        let group =
            SCNAction.group([
                scaleOut,
                spin
            ])

        enemy.runAction(group) {

            enemy.removeFromParentNode()
        }

        updateHUD()

        if enemies.isEmpty {

            messageLabel.text =
                "ARENA CLEAR"

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 3
            ) {

                self.messageLabel.text =
                    "ROUND 2"

                self.spawnSecondWave()
            }
        }
    }

    private func flashCrosshair(
        hit: Bool
    ) {

        crosshair.textColor =
            hit
            ? UIColor.systemPink
            : UIColor.white

        crosshair.transform =
            CGAffineTransform(
                scaleX: 1.5,
                y: 1.5
            )

        UIView.animate(
            withDuration: 0.09
        ) {

            self.crosshair.transform =
                .identity

            self.crosshair.textColor =
                .white
        }
    }

    // MARK: - Movement

    @objc
    private func jump() {

        guard isOnGround else {
            return
        }

        verticalVelocity = 5.8
        isOnGround = false
    }

    @objc
    private func dash() {

        dashUntil =
            CACurrentMediaTime() + 0.28
    }

    private func updateMovement(
        deltaTime: Float
    ) {

        let forwardInput =
            Float(-moveVector.y)

        let sideInput =
            Float(moveVector.x)

        let forward = SCNVector3(
            -sinf(yaw),
            0,
            -cosf(yaw)
        )

        let right = SCNVector3(
            cosf(yaw),
            0,
            -sinf(yaw)
        )

        let isDashing =
            CACurrentMediaTime()
            < dashUntil

        let speed: Float =
            isDashing ? 15 : 6.5

        var position =
            cameraNode.position

        position.x +=
            (
                forward.x * forwardInput +
                right.x * sideInput
            )
            * speed
            * deltaTime

        position.z +=
            (
                forward.z * forwardInput +
                right.z * sideInput
            )
            * speed
            * deltaTime

        // Arena bounds

        position.x = max(
            -18.5,
            min(18.5, position.x)
        )

        position.z = max(
            -20.5,
            min(20.5, position.z)
        )

        // Jump / gravity

        verticalVelocity -=
            12.5 * deltaTime

        position.y +=
            verticalVelocity * deltaTime

        if position.y <= 1.65 {

            position.y = 1.65

            verticalVelocity = 0

            isOnGround = true
        }

        cameraNode.position =
            position
    }

    // MARK: - Enemy AI

    private func updateEnemies(
        deltaTime: Float
    ) {

        guard !enemies.isEmpty else {
            return
        }

        var enemyIsClose = false

        for enemy in enemies {

            let dx =
                cameraNode.position.x
                - enemy.position.x

            let dz =
                cameraNode.position.z
                - enemy.position.z

            let distance =
                sqrt(dx * dx + dz * dz)

            if distance > 1.5 {

                let speed: Float = 1.55

                enemy.position.x +=
                    (dx / distance)
                    * speed
                    * deltaTime

                enemy.position.z +=
                    (dz / distance)
                    * speed
                    * deltaTime
            }
            else {

                enemyIsClose = true
            }

            enemy.look(
                at: SCNVector3(
                    cameraNode.position.x,
                    enemy.position.y,
                    cameraNode.position.z
                )
            )
        }

        damageTimer -= deltaTime

        if enemyIsClose &&
           damageTimer <= 0 {

            damageTimer = 0.55

            playerHealth -= 7

            if playerHealth <= 0 {

                playerHealth = 100

                cameraNode.position =
                    SCNVector3(
                        0,
                        1.65,
                        12
                    )

                messageLabel.text =
                    "YOU DIED"

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 1.4
                ) {

                    self.messageLabel.text = ""
                }
            }

            updateHUD()
        }
    }

    // MARK: - Round

    private func spawnSecondWave() {

        let positions: [SCNVector3] = [

            SCNVector3(-14, 1.15, -16),

            SCNVector3(-7, 1.15, -18),

            SCNVector3(0, 1.15, -19),

            SCNVector3(7, 1.15, -18),

            SCNVector3(14, 1.15, -16),

            SCNVector3(-15, 1.15, 8),

            SCNVector3(15, 1.15, 8)
        ]

        for position in positions {
            spawnEnemy(at: position)
        }

        messageLabel.text = ""

        updateHUD()
    }

    // MARK: - HUD

    private func updateHUD() {

        healthLabel.text =
            "HP \(playerHealth)"

        enemiesLabel.text =
            "ENEMIES \(enemies.count)"
    }

    // MARK: - Game loop

    @objc
    private func updateGame(
        _ link: CADisplayLink
    ) {

        if lastTimestamp == 0 {

            lastTimestamp =
                link.timestamp

            return
        }

        var dt =
            link.timestamp
            - lastTimestamp

        lastTimestamp =
            link.timestamp

        dt = min(dt, 0.05)

        let deltaTime =
            Float(dt)

        updateMovement(
            deltaTime: deltaTime
        )

        updateEnemies(
            deltaTime: deltaTime
        )
    }
}
