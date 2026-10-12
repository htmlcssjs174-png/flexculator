import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculator',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Arial',
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _display = '0';
  String _expression = '';

  double? _storedValue;
  String? _pendingOperator;

  bool _waitingForOperand = false;
  bool _justEvaluated = false;
  bool _error = false;
  bool _hasEntered = false;

  static const Color numberColor = Color(0xFF333333);
  static const Color functionColor = Color(0xFFA5A5A5);
  static const Color operatorColor = Color(0xFFFF9F0A);

  // ------------------------------------------------------------
  // NUMBER INPUT
  // ------------------------------------------------------------

  void _inputNumber(String number) {
    setState(() {
      if (_error || _justEvaluated) {
        _resetCalculator();
      }

      if (_waitingForOperand) {
        _display = number;
        _waitingForOperand = false;
      } else {
        // Maximum of approximately 12 digits.
        final digitCount = _display.replaceAll(RegExp(r'[-.]'), '').length;

        if (digitCount >= 12) {
          return;
        }

        if (_display == '0') {
          _display = number;
        } else if (_display == '-0') {
          _display = '-$number';
        } else {
          _display += number;
        }
      }

      _hasEntered = true;
      _updateExpression();
    });
  }

  // ------------------------------------------------------------
  // DECIMAL
  // ------------------------------------------------------------

  void _inputDecimal() {
    setState(() {
      if (_error || _justEvaluated) {
        _resetCalculator();
      }

      if (_waitingForOperand) {
        _display = '0.';
        _waitingForOperand = false;
        _hasEntered = true;
        _updateExpression();
        return;
      }

      if (!_display.contains('.')) {
        _display += '.';
      }

      _hasEntered = true;
      _updateExpression();
    });
  }

  // ------------------------------------------------------------
  // OPERATOR
  // ------------------------------------------------------------

  void _inputOperator(String operator) {
    setState(() {
      if (_error) return;

      final currentValue = double.tryParse(_display) ?? 0;

      // First operator.
      if (_storedValue == null) {
        _storedValue = currentValue;
        _pendingOperator = operator;
        _waitingForOperand = true;
        _justEvaluated = false;

        _updateExpression();
        return;
      }

      // Pressing another operator immediately:
      // change the selected operator without calculating yet.
      if (_waitingForOperand) {
        _pendingOperator = operator;
        _updateExpression();
        return;
      }

      // Chained calculation.
      final result = _calculate(_storedValue!, currentValue, _pendingOperator!);

      if (result == null) {
        _showError();
        return;
      }

      _storedValue = result;
      _pendingOperator = operator;
      _display = _formatNumber(result);
      _waitingForOperand = true;

      _updateExpression();
    });
  }

  // ------------------------------------------------------------
  // EQUALS
  // ------------------------------------------------------------

  void _equals() {
    setState(() {
      if (_error) return;

      if (_storedValue == null || _pendingOperator == null) {
        return;
      }

      final currentValue = double.tryParse(_display) ?? 0;

      final leftSide = _formatNumber(_storedValue!);
      final rightSide = _formatNumber(currentValue);
      final operator = _pendingOperator!;

      final result = _calculate(_storedValue!, currentValue, operator);

      if (result == null) {
        _showError();
        return;
      }

      _expression = '$leftSide $operator $rightSide';
      _display = _formatNumber(result);

      _storedValue = null;
      _pendingOperator = null;
      _waitingForOperand = false;
      _justEvaluated = true;
      _hasEntered = true;
    });
  }

  // ------------------------------------------------------------
  // CALCULATION
  // ------------------------------------------------------------

  double? _calculate(double first, double second, String operator) {
    switch (operator) {
      case '+':
        return first + second;

      case '−':
        return first - second;

      case '×':
        return first * second;

      case '÷':
        if (second == 0) {
          return null;
        }
        return first / second;

      default:
        return second;
    }
  }

  // ------------------------------------------------------------
  // PLUS / MINUS
  // ------------------------------------------------------------

  void _toggleSign() {
    setState(() {
      if (_error) return;

      if (_display == '0') return;

      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }

      _hasEntered = true;
      _updateExpression();
    });
  }

  // ------------------------------------------------------------
  // PERCENT
  // ------------------------------------------------------------

  void _percentage() {
    setState(() {
      if (_error) return;

      final value = double.tryParse(_display);

      if (value == null) return;

      _display = _formatNumber(value / 100);
      _hasEntered = true;

      _updateExpression();
    });
  }

  // ------------------------------------------------------------
  // BACKSPACE
  // ------------------------------------------------------------

  void _backspace() {
    setState(() {
      if (_error || _justEvaluated) {
        _resetCalculator();
        return;
      }

      if (_waitingForOperand) {
        return;
      }

      if (_display.length <= 1 ||
          (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);

        if (_display == '-' || _display.isEmpty) {
          _display = '0';
        }
      }

      _hasEntered = _display != '0';
      _updateExpression();
    });
  }

  // ------------------------------------------------------------
  // AC / C
  // ------------------------------------------------------------

  void _clear() {
    setState(() {
      // If something has been entered, first press acts as C.
      if (_hasEntered && !_error) {
        _display = '0';
        _hasEntered = false;
        _waitingForOperand = false;

        // Keep the running operation.
        if (_storedValue != null && _pendingOperator != null) {
          _expression = '${_formatNumber(_storedValue!)} $_pendingOperator';
        } else {
          _expression = '';
        }

        return;
      }

      _resetCalculator();
    });
  }

  // ------------------------------------------------------------
  // RESET
  // ------------------------------------------------------------

  void _resetCalculator() {
    _display = '0';
    _expression = '';

    _storedValue = null;
    _pendingOperator = null;

    _waitingForOperand = false;
    _justEvaluated = false;
    _error = false;
    _hasEntered = false;
  }

  // ------------------------------------------------------------
  // ERROR
  // ------------------------------------------------------------

  void _showError() {
    _display = 'Error';
    _expression = '';

    _storedValue = null;
    _pendingOperator = null;

    _waitingForOperand = false;
    _justEvaluated = false;
    _error = true;
    _hasEntered = false;
  }

  // ------------------------------------------------------------
  // EXPRESSION
  // ------------------------------------------------------------

  void _updateExpression() {
    if (_storedValue != null && _pendingOperator != null) {
      final first = _formatNumber(_storedValue!);

      if (_waitingForOperand) {
        _expression = '$first $_pendingOperator';
      } else {
        _expression =
            '$first $_pendingOperator ${_formatNumberString(_display)}';
      }
    } else {
      _expression = '';
    }
  }

  // ------------------------------------------------------------
  // FORMAT DISPLAY NUMBER
  // ------------------------------------------------------------

 String _formatNumberString(String value) {
  if (value == 'Error') return value;

  // Remove any existing commas first.
  final unformatted = value.replaceAll(',', '');

  final negative = unformatted.startsWith('-');
  String clean = negative ? unformatted.substring(1) : unformatted;

  String decimalPart = '';

  if (clean.contains('.')) {
    final parts = clean.split('.');
    clean = parts[0];
    decimalPart = '.${parts[1]}';
  }

  if (clean.isEmpty) {
    clean = '0';
  }

  final formatted = _addCommas(clean);

  return '${negative ? '-' : ''}$formatted$decimalPart';
}
  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) {
      return 'Error';
    }

    if (value == 0) {
      return '0';
    }

    // Keep enough precision while removing unnecessary zeros.
    String text;

    if (value.abs() >= 1e12 || value.abs() < 1e-9) {
      text = value.toStringAsPrecision(12);
    } else {
      text = value.toStringAsFixed(12);
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }

    if (text.contains('e') || text.contains('E')) {
      return text;
    }

    return _formatNumberString(text);
  }

  String _addCommas(String number) {
    if (number.length <= 3) {
      return number;
    }

    final buffer = StringBuffer();

    int firstGroup = number.length % 3;

    if (firstGroup == 0) {
      firstGroup = 3;
    }

    buffer.write(number.substring(0, firstGroup));

    for (int i = firstGroup; i < number.length; i += 3) {
      buffer.write(',');
      buffer.write(number.substring(i, i + 3));
    }

    return buffer.toString();
  }

  // ------------------------------------------------------------
  // BUTTON
  // ------------------------------------------------------------

  Widget _button({
    required String text,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool isOperator = false,
    bool isZero = false,
  }) {
    return Expanded(
      flex: isZero ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: AspectRatio(
          aspectRatio: isZero ? 2.0 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onPressed,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: isZero ? Alignment.centerLeft : Alignment.center,
                padding: isZero
                    ? const EdgeInsets.only(left: 28)
                    : EdgeInsets.zero,
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isZero ? 28 : 29,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _operatorButton(String operator) {
    final bool armed =
        _pendingOperator == operator && _waitingForOperand && !_error;

    return _button(
      text: operator,
      onPressed: () => _inputOperator(operator),
      backgroundColor: armed ? Colors.white : operatorColor,
      textColor: armed ? operatorColor : Colors.white,
      isOperator: true,
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [

            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Running expression
                    if (_expression.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _expression,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 25,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Main result
                    Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatNumberString(_display),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w300,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Buttons
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 12),
                child: Column(
                  children: [
                    // Row 1
                    Expanded(
                      child: Row(
                        children: [
                          _button(
                            text: '⌫',
                            onPressed: _backspace,
                            backgroundColor: functionColor,
                            textColor: Colors.black,
                          ),
                          _button(
                            text: _hasEntered ? 'C' : 'AC',
                            onPressed: _clear,
                            backgroundColor: functionColor,
                            textColor: Colors.black,
                          ),
                          _button(
                            text: '%',
                            onPressed: _percentage,
                            backgroundColor: functionColor,
                            textColor: Colors.black,
                          ),
                          _operatorButton('÷'),
                        ],
                      ),
                    ),

                    // Row 2
                    Expanded(
                      child: Row(
                        children: [
                          _button(
                            text: '7',
                            onPressed: () => _inputNumber('7'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '8',
                            onPressed: () => _inputNumber('8'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '9',
                            onPressed: () => _inputNumber('9'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _operatorButton('×'),
                        ],
                      ),
                    ),

                    // Row 3
                    Expanded(
                      child: Row(
                        children: [
                          _button(
                            text: '4',
                            onPressed: () => _inputNumber('4'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '5',
                            onPressed: () => _inputNumber('5'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '6',
                            onPressed: () => _inputNumber('6'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _operatorButton('−'),
                        ],
                      ),
                    ),

                    // Row 4
                    Expanded(
                      child: Row(
                        children: [
                          _button(
                            text: '1',
                            onPressed: () => _inputNumber('1'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '2',
                            onPressed: () => _inputNumber('2'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '3',
                            onPressed: () => _inputNumber('3'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _operatorButton('+'),
                        ],
                      ),
                    ),

                    // Row 5
                    Expanded(
                      child: Row(
                        children: [
                          _button(
                            text: '+/−',
                            onPressed: _toggleSign,
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '0',
                            onPressed: () => _inputNumber('0'),
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                            isZero: true,
                          ),
                          _button(
                            text: '.',
                            onPressed: _inputDecimal,
                            backgroundColor: numberColor,
                            textColor: Colors.white,
                          ),
                          _button(
                            text: '=',
                            onPressed: _equals,
                            backgroundColor: operatorColor,
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
