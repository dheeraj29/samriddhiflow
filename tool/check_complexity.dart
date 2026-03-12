// ignore_for_file: avoid_print
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void main(List<String> args) {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found.');
    exit(1);
  }

  // Thresholds
  int cogThreshold = 15;
  int cycThreshold = 10;
  int nestingThreshold = 4;

  if (args.isNotEmpty) {
    cogThreshold = int.tryParse(args[0]) ?? 15;
  }

  int totalViolations = 0;

  String? filterPath;
  if (args.length > 1) {
    filterPath = args[1].replaceAll('\\', '/');
  }

  final dartFiles =
      libDir.listSync(recursive: true).whereType<File>().where((file) {
    final path = file.path.replaceAll('\\', '/');
    final isMatch = filterPath == null || path.contains(filterPath);
    return isMatch &&
        path.endsWith('.dart') &&
        !path.endsWith('.g.dart') &&
        !path.endsWith('.freezed.dart');
  });

  for (final file in dartFiles) {
    try {
      print('Analyzing ${file.path}...');
      final result = parseFile(
        path: file.path,
        featureSet: FeatureSet.latestLanguageVersion(),
      );

      final visitor = _ComplexityVisitor(
          file.path, cogThreshold, cycThreshold, nestingThreshold);
      result.unit.accept(visitor);

      totalViolations += visitor.violations;
    } catch (e) {
      print('Failed to analyze ${file.path}: $e');
    }
  }

  if (totalViolations > 0) {
    print('\nFound $totalViolations complexity violations.');
    exit(1);
  } else {
    print('\nNo complexity violations found. Codebase is healthy!');
    exit(0);
  }
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final int cogThreshold;
  final int cycThreshold;
  final int nestingThreshold;

  int violations = 0;

  _ComplexityVisitor(this.filePath, this.cogThreshold, this.cycThreshold,
      this.nestingThreshold);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _analyzeNode(node, node.name.lexeme);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _analyzeNode(node, node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // We only want to analyze anonymous functions (closures), not ones attached to declarations
    // that we already visited in visitMethodDeclaration or visitFunctionDeclaration.
    if (node.parent is! FunctionDeclaration &&
        node.parent is! MethodDeclaration) {
      _analyzeNode(node, '<anonymous closure>');
    }
    super.visitFunctionExpression(node);
  }

  void _analyzeNode(AstNode node, String name) {
    final visitor = _AstNodeComplexityVisitor();
    node.accept(visitor);

    bool hasViolation = false;

    if (visitor.cognitiveComplexity > cogThreshold) {
      print(
          '[$filePath] Cognitive Complexity for "$name" is ${visitor.cognitiveComplexity} (threshold $cogThreshold)');
      hasViolation = true;
    }

    if (visitor.cyclomaticComplexity > cycThreshold) {
      print(
          '[$filePath] Cyclomatic Complexity for "$name" is ${visitor.cyclomaticComplexity} (threshold $cycThreshold)');
      hasViolation = true;
    }

    if (visitor.maxNestingDepth > nestingThreshold) {
      print(
          '[$filePath] Nesting Depth for "$name" is ${visitor.maxNestingDepth} (threshold $nestingThreshold)');
      hasViolation = true;
    }

    if (hasViolation) violations++;
  }
}

class _AstNodeComplexityVisitor extends RecursiveAstVisitor<void> {
  int cognitiveComplexity = 0;
  int cyclomaticComplexity = 1; // Base path is 1
  int maxNestingDepth = 0;

  int _currentNestingLevel = 0;
  String? _currentFunctionName;

  void _enterNestingBlock() {
    _currentNestingLevel++;
    if (_currentNestingLevel > maxNestingDepth) {
      maxNestingDepth = _currentNestingLevel;
    }
  }

  void _exitNestingBlock() {
    _currentNestingLevel--;
  }

  void _increaseCognitive() {
    cognitiveComplexity += 1 + _currentNestingLevel;
  }

  void _increaseCyclomatic() {
    cyclomaticComplexity++;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _currentFunctionName = node.name.lexeme;
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _currentFunctionName = node.name.lexeme;
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _enterNestingBlock();
    super.visitFunctionExpression(node);
    _exitNestingBlock();
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_currentFunctionName != null &&
        node.methodName.name == _currentFunctionName) {
      cognitiveComplexity++;
    }
    if (node.isNullAware) {
      cognitiveComplexity++;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    bool isElseIf = node.parent is IfStatement &&
        (node.parent as IfStatement).elseStatement == node;

    if (!isElseIf) {
      _increaseCognitive();
    } else {
      cognitiveComplexity++; // else if contributes 1, but doesn't add nesting
    }

    _increaseCyclomatic();

    _enterNestingBlock();
    node.expression.accept(this);
    node.thenStatement.accept(this);
    _exitNestingBlock();

    if (node.elseStatement != null) {
      if (node.elseStatement is! IfStatement) {
        cognitiveComplexity++; // +1 for 'else'
        _enterNestingBlock();
        node.elseStatement!.accept(this);
        _exitNestingBlock();
      } else {
        node.elseStatement!.accept(this);
      }
    }
  }

  @override
  void visitIfElement(IfElement node) {
    _increaseCognitive();
    _increaseCyclomatic();

    _enterNestingBlock();
    node.expression.accept(this);
    node.thenElement.accept(this);
    _exitNestingBlock();

    if (node.elseElement != null) {
      if (node.elseElement is! IfElement) {
        cognitiveComplexity++; // +1 for 'else'
        _enterNestingBlock();
        node.elseElement!.accept(this);
        _exitNestingBlock();
      } else {
        node.elseElement!.accept(this);
      }
    }
  }

  @override
  void visitForStatement(ForStatement node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitForStatement(node);
    _exitNestingBlock();
  }

  @override
  void visitForElement(ForElement node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitForElement(node);
    _exitNestingBlock();
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitWhileStatement(node);
    _exitNestingBlock();
  }

  @override
  void visitDoStatement(DoStatement node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitDoStatement(node);
    _exitNestingBlock();
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _increaseCognitive();
    _enterNestingBlock();
    super.visitSwitchStatement(node);
    _exitNestingBlock();
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    _increaseCyclomatic();
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    _increaseCyclomatic();
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitCatchClause(node);
    _exitNestingBlock();
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||') {
      _increaseCyclomatic();
      bool isSequence = false;
      if (node.parent is BinaryExpression) {
        final parent = node.parent as BinaryExpression;
        if (parent.operator.lexeme == op) {
          isSequence = true;
        }
      }
      if (!isSequence) {
        cognitiveComplexity++;
      }
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitConditionalExpression(node);
    _exitNestingBlock();
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.isNullAware) {
      cognitiveComplexity++;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    if (node.isNullAware) {
      cognitiveComplexity++;
    }
    super.visitIndexExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final op = node.operator.lexeme;
    if (op == '??=' || op == '&&=' || op == '||=') {
      cognitiveComplexity++;
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.lexeme == '!') {
      cognitiveComplexity++;
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    if (node.label != null) {
      cognitiveComplexity++;
    }
    super.visitBreakStatement(node);
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    if (node.label != null) {
      cognitiveComplexity++;
    }
    super.visitContinueStatement(node);
  }
}
