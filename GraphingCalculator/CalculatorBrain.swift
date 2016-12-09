
import Foundation

enum CalculatorBrainEvaluationResult {
    case success(Double)
    case failure(String)
}

class CalculatorBrain {
    
    fileprivate enum Op: CustomStringConvertible {
        case operand(Double)
        case variable(String)
        case constant(String, Double)
        case unaryOperation(String, (Double) -> Double)
        case binaryOperation(String, (Double, Double) -> Double)
        
        var description: String {
            switch self {
            case .operand(let operand):
                let intValue = Int(operand)
                if Double(intValue) == operand {
                    return "\(intValue)"
                } else {
                    return "\(operand)"
                }
            case .variable(let symbol):
                return "\(symbol)"
            case .constant(let symbol, _):
                return "\(symbol)"
            case .unaryOperation(let symbol, _):
                return symbol
            case .binaryOperation(let symbol, _):
                return symbol
            }
        }
        
        var precedence: Int {
            switch self {
            case .operand(_), .variable(_), .constant(_, _), .unaryOperation(_, _):
                return Int.max
            case .binaryOperation(_, _):
                return Int.min
            }
        }
    }
    
    fileprivate var opStack = [Op]()
    fileprivate var knownOps = [String:Op]()
    var variableValues = [String:Double]()
    fileprivate var error: String?
    
    typealias PropertyList = AnyObject
    var program: PropertyList { // guaranteed to be a PropertyList
        get {
            return opStack.map{$0.description as AnyObject}
        }
        set {
            if let opSymbols = newValue as? [String] {
                var newOpStack = [Op]()
                for opSymbol in opSymbols {
                    if let op = knownOps[opSymbol] {
                        newOpStack.append(op)
                    } else if let operand = NumberFormatter().number(from: opSymbol)?.doubleValue {
                        newOpStack.append(.operand(operand))
//                    } else if variableValues[opSymbol] != nil {
                    } else {
                        newOpStack.append(.variable(opSymbol))
                    }
                }
                opStack = newOpStack
            }
        }
    }
    
    // Describes contents of the brain (var opStack)
    var description: [String] {
        let (descriptionArray, _) = description([String](), ops: opStack)
        return descriptionArray
    }
    
    init() {
        func learnOp(_ op: Op) {
            knownOps[op.description] = op
        }
        learnOp(Op.unaryOperation("√", sqrt))
        learnOp(Op.unaryOperation("sin", sin))
        learnOp(Op.unaryOperation("cos", cos))
        learnOp(Op.unaryOperation("tan", tan))
        learnOp(Op.unaryOperation("log₁₀", log10))
        learnOp(Op.unaryOperation("ln", log))
        learnOp(Op.unaryOperation("ᐩ/-") { -$0 })
        learnOp(Op.binaryOperation("×", *))
        learnOp(Op.binaryOperation("+", +))
        learnOp(Op.binaryOperation("÷") { $1 / $0 })
        learnOp(Op.binaryOperation("−") { $1 - $0 })
        learnOp(Op.binaryOperation("pow") { pow($1, $0) })
        learnOp(Op.constant("π", M_PI))
    }
    
    fileprivate func description(_ currentDescription: [String], ops: [Op]) -> (accumulatedDescription: [String], remainingOps: [Op]) {
        var accumulatedDescription = currentDescription
        if !ops.isEmpty {
            var remainingOps = ops
            let op = remainingOps.removeFirst()
            switch op {
            case .operand(_), .variable(_), .constant(_, _):
                accumulatedDescription.append(op.description)
                return description(accumulatedDescription, ops: remainingOps)
            case .unaryOperation(let symbol, _):
                if !accumulatedDescription.isEmpty {
                    let unaryOperand = accumulatedDescription.removeLast()
                    accumulatedDescription.append(symbol + "(\(unaryOperand))")
                    let (newDescription, remainingOps) = description(accumulatedDescription, ops: remainingOps)
                    return (newDescription, remainingOps)
                }
            case .binaryOperation(let symbol, _):
                if !accumulatedDescription.isEmpty {
                    let binaryOperandLast = accumulatedDescription.removeLast()
                    if !accumulatedDescription.isEmpty {
                        let binaryOperandFirst = accumulatedDescription.removeLast()                        
                        if op.description == remainingOps.first?.description || op.precedence == remainingOps.first?.precedence {
                            accumulatedDescription.append("(\(binaryOperandFirst)" + symbol + "\(binaryOperandLast))")
                        } else {
                            accumulatedDescription.append("\(binaryOperandFirst)" + symbol + "\(binaryOperandLast)")
                        }
                        return description(accumulatedDescription, ops: remainingOps)
                    } else {
                        accumulatedDescription.append("?" + symbol + "\(binaryOperandLast)")
                        return description(accumulatedDescription, ops: remainingOps)
                    }
                } else {
                    accumulatedDescription.append("?" + symbol + "?")
                    return description(accumulatedDescription, ops: remainingOps)
                }
            }
        }
        return (accumulatedDescription, ops)
    }
    
    fileprivate func evaluate(_ ops: [Op]) -> (result: Double?, remainingOps: [Op]) {
        if !ops.isEmpty {
            var remainingOps = ops
            let op = remainingOps.removeLast()
            switch op {
            case .operand(let operand):
                return (operand, remainingOps)
            case .variable(let symbol):
                if let variableValue = variableValues[symbol] {
                    return (variableValue, remainingOps)
                } else {
                    error = "\(symbol) is not set"
                    return (nil, remainingOps)
                }
            case .constant(_, let constantValue):
                return (constantValue, remainingOps)
            case .unaryOperation(_, let operation):
                let operandEvaluation = evaluate(remainingOps)
                if let operand = operandEvaluation.result {
                    return (operation(operand), operandEvaluation.remainingOps)
                } else {
                    error = "Missing unary operand"
                }
            case .binaryOperation(_, let operation):
                let op1Evaluation = evaluate(remainingOps)
                if let operand1 = op1Evaluation.result {
                    let op2Evaluation = evaluate(op1Evaluation.remainingOps)
                    if let operand2 = op2Evaluation.result {
                        return (operation(operand1, operand2), op2Evaluation.remainingOps)
                    } else {
                        error = "Missing binary operand"
                    }
                } else {
                    error = "Missing binary operand"
                }
            }
        }
        return (nil, ops)
    }
    
    fileprivate func evaluate() -> Double? {
        let (result, _) = evaluate(opStack)
        
//        let (result, remainder) = evaluate(opStack)
//        print("\(opStack) = \(result) with \(remainder) left over")
        
        return result
    }
    
    func evaluateAndReportErrors() -> CalculatorBrainEvaluationResult {
        if let evaluationResult = evaluate() {
            if evaluationResult.isInfinite {
                return CalculatorBrainEvaluationResult.failure("Infinite value")
            } else if evaluationResult.isNaN {
                return CalculatorBrainEvaluationResult.failure("Not a number")
            } else {
                return CalculatorBrainEvaluationResult.success(evaluationResult)
            }
        } else {
            if let returnError = error {
                // We consumed the error, now set error back to nil
                error = nil
                return CalculatorBrainEvaluationResult.failure(returnError)
            } else {
                return CalculatorBrainEvaluationResult.failure("Error")
            }
        }
    }
    
    func clearStack() {
        opStack = [Op]()
    }
    
    func removeLastOpFromStack() {
        if opStack.last != nil {
            opStack.removeLast()
        }
    }
    
    func pushOperand(_ operand: Double) -> CalculatorBrainEvaluationResult? {
        opStack.append(Op.operand(operand))
        return evaluateAndReportErrors()
    }
    
    func pushOperand(_ symbol: String) -> CalculatorBrainEvaluationResult? {
        opStack.append(Op.variable(symbol))
        return evaluateAndReportErrors()
    }
    
    func pushConstant(_ symbol: String) -> CalculatorBrainEvaluationResult? {
        if let constant = knownOps[symbol] {
            opStack.append(constant)
        }        
        return evaluateAndReportErrors()
    }
    
    func performOperation(_ symbol: String) -> CalculatorBrainEvaluationResult? {
        if let operation = knownOps[symbol] {
            opStack.append(operation)
        }
        return evaluateAndReportErrors()
    }
    
}
