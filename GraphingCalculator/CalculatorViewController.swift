
import UIKit

class CalculatorViewController: UIViewController {
    @IBOutlet weak var display: UILabel!
    @IBOutlet weak var history: UILabel!
    
    fileprivate struct DefaultDisplayResult {
        static let Startup: Double = 0
        static let Error = "Error!"
    }
    
    fileprivate var userIsInTheMiddleOfTypingANumber = false
    fileprivate let defaultHistoryText = " "
    
    fileprivate var brain = CalculatorBrain()

    @IBAction func clear() {
        brain.clearStack()
        brain.variableValues.removeAll()
        displayResult = CalculatorBrainEvaluationResult.success(DefaultDisplayResult.Startup)
        history.text = defaultHistoryText
    }
    
    @IBAction func appendDigit(_ sender: UIButton) {
        let digit = sender.currentTitle!
        if userIsInTheMiddleOfTypingANumber {
            if digit != "." || display.text!.range(of: ".") == nil {
                display.text = display.text! + digit
            }
        } else {
            display.text = digit
            userIsInTheMiddleOfTypingANumber = true
        }
    }

    @IBAction func undo() {
        if userIsInTheMiddleOfTypingANumber == true {
            if display.text!.characters.count > 1 {
                display.text = String(display.text!.characters.dropLast())
            } else {
                displayResult = CalculatorBrainEvaluationResult.success(DefaultDisplayResult.Startup)
            }
        } else {
            brain.removeLastOpFromStack()
            displayResult = brain.evaluateAndReportErrors()
        }
    }
    
    @IBAction func changeSign() {
        if userIsInTheMiddleOfTypingANumber {
            if displayValue != nil {
                displayResult = CalculatorBrainEvaluationResult.success(displayValue! * -1)
                
                // set userIsInTheMiddleOfTypingANumber back to true as displayResult will set it to false
                userIsInTheMiddleOfTypingANumber = true
            }
        } else {
            displayResult = brain.performOperation("ᐩ/-")
        }
    }
    
    @IBAction func pi() {
        if userIsInTheMiddleOfTypingANumber {
            enter()
        }
        displayResult = brain.pushConstant("π")
    }
    
    @IBAction func setM() {
        userIsInTheMiddleOfTypingANumber = false
        if displayValue != nil {
            brain.variableValues["M"] = displayValue!
        }
        displayResult = brain.evaluateAndReportErrors()
    }
    
    @IBAction func getM() {
        if userIsInTheMiddleOfTypingANumber {
            enter()
        }
        displayResult = brain.pushOperand("M")
    }    
    
    @IBAction func operate(_ sender: UIButton) {
        if userIsInTheMiddleOfTypingANumber {
            enter()
        }
        if let operation = sender.currentTitle {
            displayResult = brain.performOperation(operation)
        }
    }
    
    @IBAction func enter() {
        userIsInTheMiddleOfTypingANumber = false
        if displayValue != nil {
            displayResult = brain.pushOperand(displayValue!)
        }
    }
    
    fileprivate var displayValue: Double? {
        if let displayValue = NumberFormatter().number(from: display.text!) {
            return displayValue.doubleValue
        }
        return nil
    }
    
    fileprivate var displayResult: CalculatorBrainEvaluationResult? {
        get {
            if let displayValue = displayValue {
                return .success(displayValue)
            }
            if display.text != nil {
                return .failure(display.text!)
            }
            return .failure("Error")
        }
        set {
            if newValue != nil {
                switch newValue! {
                case let .success(displayValue):
                    display.text = "\(displayValue)"
                case let .failure(error):
                    display.text = error
                }
            } else {
                display.text = DefaultDisplayResult.Error
            }
            userIsInTheMiddleOfTypingANumber = false
            
            if !brain.description.isEmpty {
                history.text = " \(brain.description.joined(separator: ", ")) ="
            } else {
                history.text = defaultHistoryText
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var destination: UIViewController? = segue.destination
        if let navCon = destination as? UINavigationController {
            destination = navCon.visibleViewController
        }
        if let gvc = destination as? GraphingViewController {
            gvc.program = brain.program
            if let graphLabel = brain.description.last {
                gvc.graphLabel = graphLabel
            }
        }
    }

}

