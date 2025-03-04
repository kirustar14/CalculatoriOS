import SwiftUI

struct ContentView: View {
    @State private var currentInput = ""
    @State private var result = ""
    @State private var isLandscape = false
    // Reference to your Objective-C CalculatorLogic class.
    let calcLogic = CalculatorLogic()
    
    // MARK: - Button Handling
    func handleButtonPress(_ button: String) {
        if button == "=" {
            calculateResult()
        } else if button == "Clear" {
            currentInput = ""
            result = ""
        } else if button == "X" {
            if !currentInput.isEmpty {
                currentInput.removeLast()
            }
        } else if button == "sin" || button == "cos" || button == "tan" {
            // Append function name with an opening parenthesis.
            // The user must complete the argument and add a closing parenthesis.
            currentInput += "\(button)("
        } else if button == "(" || button == ")" {
            currentInput += button
        } else {
            currentInput += button
        }
    }
    
    // MARK: - Calculation Logic
    func calculateResult() {
        // Check for balanced parentheses.
        if !isBalanced(currentInput) {
            result = "Invalid Input"
            return
        }
        // First, simplify arithmetic inside parentheses.
        let simplified = evaluateExpression(currentInput)
        if simplified == "Invalid Input" {
            result = "Invalid Input"
            return
        }
        // Insert implicit multiplication where needed.
        let implicit = insertImplicitMultiplication(simplified)
        // Process trig functions.
        let finalExp = processTrigFunctions(implicit)
        if finalExp == "Invalid Input" {
            result = "Invalid Input"
            return
        }
        // Evaluate the final arithmetic expression.
        let expr = NSExpression(format: finalExp)
        if let output = expr.expressionValue(with: nil, context: nil) as? Double {
            result = String(output)
        } else {
            result = "Invalid Input"
        }
    }
    
    // Checks if parentheses are balanced.
    func isBalanced(_ input: String) -> Bool {
        var count = 0
        for char in input {
            if char == "(" { count += 1 }
            else if char == ")" { count -= 1; if count < 0 { return false } }
        }
        return count == 0
    }
    
    // Recursively simplifies arithmetic expressions inside parentheses.
    func evaluateExpression(_ input: String) -> String {
        var expression = input
        while let range = findInnermostParentheses(in: expression) {
            let inner = String(expression[range])  // e.g., "(2+3)" or "(2)"
            let content = String(inner.dropFirst().dropLast())  // e.g., "2+3" or "2"
            if content.contains("+") || content.contains("-") || content.contains("*") || content.contains("/") {
                let evaluatedInner = evaluateArithmeticExpression(content)
                expression.replaceSubrange(range, with: "(\(evaluatedInner))")
            } else {
                // For a lone number, check if these parentheses are part of a trig function.
                if range.lowerBound > expression.startIndex {
                    let precedingIndex = expression.index(before: range.lowerBound)
                    let precedingChar = expression[precedingIndex]
                    if precedingChar.isLetter {
                        // Likely the outer parentheses of a trig function; do not remove them.
                        break
                    }
                }
                // Otherwise, remove redundant parentheses.
                let evaluatedInner = evaluateArithmeticExpression(content)
                if evaluatedInner == "Invalid Input" {
                    return "Invalid Input"
                }
                expression.replaceSubrange(range, with: evaluatedInner)
            }
        }
        return expression
    }
    
    // Finds the innermost set of parentheses.
    func findInnermostParentheses(in expression: String) -> Range<String.Index>? {
        var lastOpen: String.Index? = nil
        var foundRange: Range<String.Index>? = nil
        for idx in expression.indices {
            if expression[idx] == "(" {
                lastOpen = idx
            } else if expression[idx] == ")" {
                if let open = lastOpen {
                    foundRange = open..<expression.index(after: idx)
                    break
                }
            }
        }
        return foundRange
    }
    
    // Evaluates a simple arithmetic expression (e.g., "2+3") using NSExpression.
    func evaluateArithmeticExpression(_ expression: String) -> String {
        let nsExpr = NSExpression(format: expression)
        if let value = nsExpr.expressionValue(with: nil, context: nil) as? Double {
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return String(Int(value))
            }
            return String(value)
        }
        return "Invalid Input"
    }
    
    // Inserts an implicit multiplication operator where needed.
    // For example, "cos(5)tan(5)" becomes "cos(5)*tan(5)".
    func insertImplicitMultiplication(_ input: String) -> String {
        var output = ""
        let chars = Array(input)
        for i in 0..<chars.count {
            output.append(chars[i])
            if i < chars.count - 1 {
                let current = chars[i]
                let next = chars[i + 1]
                if ((current.isNumber || current == "." || current == ")") &&
                    (next.isLetter || next == "(")) {
                    output.append("*")
                }
            }
        }
        return output
    }
    
    // Processes trig functions by replacing calls like sin(x), cos(x), tan(x) with computed values.
    func processTrigFunctions(_ expression: String) -> String {
        var exp = expression
        // Regex matches sin(...), cos(...), tan(...) with no nested parentheses.
        let pattern = "(sin|cos|tan)\\(([^()]*)\\)"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        while true {
            let nsRange = NSRange(location: 0, length: exp.utf16.count)
            let matches = regex.matches(in: exp, options: [], range: nsRange)
            if matches.isEmpty { break }
            let match = matches[0]
            let funcName = (exp as NSString).substring(with: match.range(at: 1))
            var argStr = (exp as NSString).substring(with: match.range(at: 2))
            argStr = cleanTrigArgument(argStr)
            // If the argument is empty or still contains any parentheses, it's invalid.
            if argStr.isEmpty || argStr.contains("(") || argStr.contains(")") {
                return "Invalid Input"
            }
            let argExpr = NSExpression(format: argStr)
            guard let argValue = argExpr.expressionValue(with: nil, context: nil) as? Double else {
                return "Invalid Input"
            }
            var computed: Double = 0.0
            if funcName == "sin" {
                computed = calcLogic.sine(argValue)
            } else if funcName == "cos" {
                computed = calcLogic.cosine(argValue)
            } else if funcName == "tan" {
                computed = calcLogic.tangent(argValue)
            }
            exp = (exp as NSString).replacingCharacters(in: match.range, with: String(computed))
        }
        // If any unresolved trig calls remain, flag as invalid.
        if exp.contains("sin(") || exp.contains("cos(") || exp.contains("tan(") {
            return "Invalid Input"
        }
        return exp
    }
    
    // Removes redundant outer parentheses from a trig argument.
    // For example, "((2))" becomes "2".
    func cleanTrigArgument(_ arg: String) -> String {
        var s = arg.trimmingCharacters(in: .whitespaces)
        while s.hasPrefix("(") && s.hasSuffix(")") {
            let trimmed = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            let expr = NSExpression(format: trimmed)
            if expr.expressionValue(with: nil, context: nil) != nil {
                s = trimmed
            } else {
                break
            }
        }
        return s
    }
    
    private func backgroundColor(for button: String) -> Color {
        if button == "X" {
            return Color.red // Background color for "X"
        }
        return Color.black // Default background color
    }

    
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    var body: some View {
        if verticalSizeClass == .regular {
            VStack(spacing: 20) {
                // Input Display
                Text(currentInput)
                    .font(.largeTitle)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .cornerRadius(10)
                
                // Result Display
                Text(result)
                    .font(.title)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .cornerRadius(10)
                
                // Calculator Buttons Grid
                VStack(spacing: 10) {
                    ForEach([["7", "8", "9", "+"],
                             ["4", "5", "6", "-"],
                             ["1", "2", "3", "*"],
                             ["0", ".", "=", "/"]], id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { button in
                                Button(action: { self.handleButtonPress(button) }) {
                                    Text(button)
                                        .font(.title)
                                        .frame(width: 50, height: 50)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    
                    // Additional row for trig functions and backspace.
                    HStack(spacing: 10) {
                        Button(action: { self.handleButtonPress("sin") }) {
                            Text("sin")
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Button(action: { self.handleButtonPress("cos") }) {
                            Text("cos")
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Button(action: { self.handleButtonPress("tan") }) {
                            Text("tan")
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Button(action: { self.handleButtonPress("X") }) {
                            Text("X")
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    // Row for parentheses.
                    HStack(spacing: 10) {
                        Button(action: { self.handleButtonPress("(") }) {
                            Text("(")
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Button(action: { self.handleButtonPress(")") }) {
                            Text(")")
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        Button(action: { self.handleButtonPress("Clear") }) {
                            Text("Clear")
                                .font(.title)
                                .frame(width: 100, height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }

                    }
                }
                .padding()
            }
            .background(Color.white)
            .edgesIgnoringSafeArea(.all)
        }
        else {
            VStack(spacing: 20) {
                // Input Display
                Text(currentInput)
                    .font(.largeTitle)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .cornerRadius(10)
                
                // Result Display
                Text(result)
                    .font(.title)
                    .foregroundColor(.black)
                    .background(Color.white)
                    .cornerRadius(10)
                
                // Calculator Buttons Grid
                VStack(spacing: 10) {
                    ForEach([
                        ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."], [ "sin", "cos", "tan", "(", ")", "+", "-", "*", "/", "=", "X"]], id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { button in
                                Button(action: { self.handleButtonPress(button) }) {
                                    Text(button)
                                        .font(.title)
                                        .frame(width: 50, height: 50)
                                        .background(self.backgroundColor(for: button))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }

                        }
                .padding()
            }
                HStack(spacing: 10) {
                    Button(action: { self.handleButtonPress("Clear") }) {
                        Text("Clear")
                            .font(.title)
                            .frame(width: 100, height: 30)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            .background(Color.white)
            .edgesIgnoringSafeArea(.all)
        }
        }
    }
}
