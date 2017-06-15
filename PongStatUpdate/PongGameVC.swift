//
//  ViewController.swift
//  PongStatUpdate
//
//  Created by Cowboy Lynk on 6/13/17.
//  Copyright © 2017 Cowboy Lynk. All rights reserved.
//

import UIKit
import Charts

class PongGameVC: UIViewController {
    //Variables
    var activeGame: PongGame!
    var cup: Cup!
    var numInitialCups = 10
    var initialArrangement: [[Bool]]!
    var initialReRackArrangement: [[Bool]]!
    var numBase: Int!
    var turns = [(Int, PongGame)]()
    let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.light))
    
    //Outlets
    @IBOutlet weak var tableView: UIView!
    @IBOutlet var reRackView: UIView!
    @IBOutlet weak var missedButton: UIButton!
    @IBOutlet weak var currentScoreLabel: UILabel!
    @IBOutlet weak var chartView: LineChartView!
    @IBOutlet weak var noDataLabel: UILabel!
    //Winner View Outlets
    @IBOutlet var winnersView: UIView!
    @IBOutlet weak var finalScoreLabel: UILabel!
    
    //Actions
    @IBAction func undoButtonTapped(_ sender: Any) {
        if turns.count > 1{
            turns.removeLast()
            clearView(view: tableView)
            activeGame = turns.last?.1.copy() as! PongGame
            setTable(cupConfig: activeGame.cupConfig)
            updateVisuals()
        }
    }
    @IBAction func reRackButtonTapped(_ sender: Any) {
        activeGame.reRackConfig = initialReRackArrangement
        Animations.springAnimateIn(viewToAnimate: reRackView, blurView: blurEffectView, view: self.view)
        setReRackView()
    }
    @IBAction func resetButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Reset table?", message: "Are you sure that you want to reset the table? Your scores will be deleted.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive, handler: { action in
            // Resets table
            self.clearView(view: self.tableView)
            self.setTable(cupConfig: self.initialArrangement)
            self.activeGame = PongGame(config: self.initialArrangement)  // creates a new game
            self.turns.removeAll()
            self.turns.append((4, self.activeGame.copy() as! PongGame))
            self.updateVisuals()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    @IBAction func setRackButtonTapped(_ sender: Any) {
        if activeGame.getCount(array: activeGame.reRackConfig) == activeGame.getCount(array: activeGame.cupConfig){
            activeGame.cupConfig = activeGame.reRackConfig
            clearView(view: tableView)
            setTable(cupConfig: activeGame.cupConfig)
            activeGame.reRackConfig = initialReRackArrangement
            turns.append((3, activeGame.copy() as! PongGame))
            Animations.animateOut(viewToAnimate: reRackView, blurView: blurEffectView)
        }
        else {
            let alert = UIAlertController(title: "Invalid Re-rack", message: "The number of cups you set for the re-rack doesn't match the number of cups on the table. Cups on table: \(self.activeGame.cupsRemaining())", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Okay", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    @IBAction func closeReRackButtonTapped(_ sender: Any) {
        Animations.animateOut(viewToAnimate: reRackView, blurView: blurEffectView)
    }
    func reRackSelectorTapped(sender:reRackSwitch!){
        sender.isPressed()
        let location = sender.location
        activeGame.reRackConfig[location.0][location.1] = sender.switchState
    }
    //Winner View Actions
    @IBAction func wvUndoButtonPressed(_ sender: Any) {
        turns.removeLast()
        clearView(view: tableView)
        activeGame = turns.last?.1.copy() as! PongGame
        setTable(cupConfig: activeGame.cupConfig)
        updateVisuals()
        Animations.animateOut(viewToAnimate: self.winnersView, blurView: blurEffectView)
    }
    @IBAction func wvPlayAgainButtonPressed(_ sender: Any) {
        clearView(view: tableView)
        setTable(cupConfig: initialArrangement)
        activeGame = PongGame(config: initialArrangement)  // creates a new game
        turns.removeAll()
        turns.append((4, activeGame.copy() as! PongGame))
        updateVisuals()
        Animations.animateOut(viewToAnimate: self.winnersView, blurView: blurEffectView)
    }
    
    //Functions
    func takeTurn(turnType: Int, playedCup: Any) {
        switch turnType{  // the switch is used for shared
        case 1:  // User missed the cup
            activeGame.missedCounter += 1
        case 0, 2:  // Made by user or someone else
            let playedCup = playedCup as! Cup
            playedCup.removeCup()
            activeGame.cupConfig[playedCup.location.0][playedCup.location.1] = false
            if turnType == 0{ // Made by user
                let multiplier = 1 + 0.1 * Double(6 - activeGame.calcCupsAround(cup: playedCup))
                activeGame.madeCounter += multiplier
            }
        default:
            print("default")
        }
        activeGame.updateScore()
        turns.append((turnType, activeGame.copy() as! PongGame)) // Adds the current cup config to turns
        updateVisuals()
        if activeGame.cupsRemaining() == 0{
            finalScoreLabel.text = "Final Score: \(String(Int(activeGame.score)))"
            Animations.springAnimateIn(viewToAnimate: winnersView, blurView: blurEffectView, view: self.view)
        }
    }
    func updateVisuals(){
        activeGame.updateScore()
        missedButton.setTitle("MISSED: \(activeGame.missedCounter)", for: .normal)
        currentScoreLabel.text = "WEIGHTED SCORE: \(Int(activeGame.score))"
        ChartSetup.updateChart(chartView: chartView, noDataLabel: noDataLabel, turnNodes: getTurnNodes())
    }
    func clearView(view: UIView){
        for subView in view.subviews{
            subView.removeFromSuperview()
        }
    }
    func setTable(cupConfig: [[Bool]]){
        var i = 0
        let dimension = Double(Int(tableView.bounds.width)/(numBase))
        
        //position variables
        var xPos = 0.0
        var yPos = 0.0
        
        for row in 0..<numBase{
            xPos = dimension/2 * Double(i)
            for col in 0..<numBase-i {
                cup = Cup(frame: CGRect(x: xPos, y: yPos, width: dimension, height: dimension))
                if cupConfig[row][col] == false{
                    cup.removeCup()
                }
                cup.location = (row, col)
                cup.delegate = self
                tableView.addSubview(cup)
                xPos += dimension
            }
            yPos += dimension * 0.88
            i += 1
        }
    }
    func setReRackView(){
        var i = 0
        let spacing = 1.0/Double(numBase)
        let dimension = Double((reRackView.bounds.width-60))/(Double(numBase) + spacing*Double(numBase-1))
        var reRackSelector: reRackSwitch!
        
        //position variables
        var xPos = 0.0
        var yPos = 50.0
        
        for row in 0..<numBase{
            xPos = (dimension*(1.0+spacing))/2 * Double(i) + 30
            for col in 0..<numBase-i {
                reRackSelector = reRackSwitch(frame: CGRect(x: xPos, y: yPos, width: dimension, height: dimension))
                reRackSelector.location = (row, col)
                reRackSelector.layer.cornerRadius = CGFloat(dimension/2)
                reRackSelector.addTarget(self, action: #selector(reRackSelectorTapped(sender:)), for: .touchUpInside)
                reRackView.addSubview(reRackSelector)
                xPos += dimension*(1+spacing)
            }
            yPos += dimension
            i += 1
        }
    }
    func getTurnNodes() -> [(Int, PongGame)]{
        var turnNodes = [(Int, PongGame)]()
        for turn in turns{
            if turn.0 == 0 || turn.0 == 1{
                turnNodes.append(turn)
            }
        }
        return turnNodes
    }

    override func viewDidLoad() {
        
        // Initializes variables needed to start the game
        numBase = Int(-1/2*(1 - (8.0*Double(numInitialCups) + 1.0).squareRoot())) // sets num cups on base of pyramid
        initialArrangement = Array(repeating: Array(repeating: true, count: numBase), count: numBase) // place cups everywhere, so all true
        initialReRackArrangement = Array(repeating: Array(repeating: false, count: numBase), count: numBase) // place cups nowherer, so all fals
        
        // Sets the initial in arrangement so that cups NOT in the pyramid arrangement are set to false
        var i = 0
        for row in 0..<numBase{
            for col in 0..<numBase {
                if col > numBase - i - 1{
                    initialArrangement[row][col] = false
                }
            }
            i += 1
        }
        
        // Starts the game
        activeGame = PongGame(config: initialArrangement)  // creates a new game with a given amount of cups
        setTable(cupConfig: initialArrangement)
        ChartSetup.setUpChart(chartView: chartView)
        turns.append((4, activeGame.copy() as! PongGame))
        
        // Whole screen blur view (used in many pop-ups)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = 0
        
        // Nav bar
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 38, height: 20))
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        let image = UIImage(named: "Title")
        imageView.image = image
        navigationItem.titleView = imageView
        self.navigationController?.navigationBar.tintColor = UIColor.white
        
        // Custon missed button appearance
        missedButton.layer.shadowColor = UIColor(red:0.80, green:0.20, blue:0.10, alpha:1.0).cgColor
        missedButton.layer.shadowOpacity = 1
        missedButton.layer.shadowRadius = 0
        missedButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        missedButton.layer.cornerRadius = 15
        
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func missedButtonTapped(_ sender: Any) {
        takeTurn(turnType: 1, playedCup: false)
    }
    
}

extension PongGameVC: CupDelegate {
    func didTap(cup: Cup) {
        takeTurn(turnType: 0, playedCup: cup)
    }
    
    func didLongPress(cup: Cup, longPressGesture: UILongPressGestureRecognizer) {
        if longPressGesture.state == .began {
            takeTurn(turnType: 2, playedCup: cup)
        }
    }
}

