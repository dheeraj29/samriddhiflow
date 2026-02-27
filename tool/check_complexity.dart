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

  final dartFiles = libDir.listSync(recursive: true).whereType<File>().where(
      (file) =>
          file.path.endsWith('.dart') &&
          !file.path.endsWith('.g.dart') &&
          !file.path.endsWith('.freezed.dart'));

  for (final file in dartFiles) {
    try {
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

  void _analyzeNode(AstNode node, String name) {
    final visitor = _AstNodeComplexityVisitor();
    node.accept(visitor);

    bool hasViolation = false;

    if (visitor.cognitiveComplexity > cogThreshold) {
      print(
          '[$filePath] Function "$name" exceeds Cognitive Complexity: ${visitor.cognitiveComplexity} > $cogThreshold');
      hasViolation = true;
    }

    if (visitor.cyclomaticComplexity > cycThreshold) {
      print(
          '[$filePath] Function "$name" exceeds Cyclomatic Complexity: ${visitor.cyclomaticComplexity} > $cycThreshold');
      hasViolation = true;
    }

    if (visitor.maxNestingDepth > nestingThreshold) {
      print(
          '[$filePath] Function "$name" exceeds Max Nesting Depth: ${visitor.maxNestingDepth} > $nestingThreshold');
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
  void visitIfStatement(IfStatement node) {
    _increaseCognitive();
    _increaseCyclomatic();
    _enterNestingBlock();
    super.visitIfStatement(node);
    _exitNestingBlock();
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
    _increaseCyclomatic(); // Each case is a branch in Cyclomatic
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
    if (node.operator.lexeme == '&&' || node.operator.lexeme == '||') {
      cognitiveComplexity++;
      _increaseCyclomatic();
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
}
