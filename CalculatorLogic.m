// CalculatorLogic.m

#import "CalculatorLogic.h"
#import <math.h>

@implementation CalculatorLogic

// Addition
- (double)add:(double)a with:(double)b {
    return a + b;
}

// Subtraction
- (double)subtract:(double)a with:(double)b {
    return a - b;
}

// Multiplication
- (double)multiply:(double)a with:(double)b {
    return a * b;
}

// Division (handling divide by zero case)
- (double)divide:(double)a with:(double)b {
    if (b == 0) {
        return NAN; // Return NaN to indicate an error
    }
    return a / b;
}

// Trigonometric functions
- (double)sine:(double)x {
    return sin(x);
}

- (double)cosine:(double)x {
    return cos(x);
}

- (double)tangent:(double)x {
    return tan(x);
}

@end
