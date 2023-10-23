import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

void main() {
  final game = GameOfLife();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        floatingActionButton: PlayButton(game: game),
        body: GameWidget(game: game),
      ),
    ),
  );
}

class PlayButton extends HookWidget {
  const PlayButton({super.key, required this.game});

  final GameOfLife game;

  @override
  Widget build(BuildContext context) {
    final isRunning = useState(game.isRunning);

    useEffect(
      () {
        if (!game.isMounted) return;
        game.isRunning = !game.isRunning;
        return;
      },
      [isRunning.value],
    );

    return FloatingActionButton.extended(
      onPressed: () {
        isRunning.value = !isRunning.value;
      },
      label: Text(isRunning.value ? 'Reset' : 'Play'),
      icon: Icon(isRunning.value ? Icons.restore : Icons.play_arrow),
    );
  }
}

class GameOfLife extends FlameGame {
  final _grid = GameOfLifeGrid();
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  set isRunning(bool value) {
    _isRunning = value;
    _grid.resize();
  }

  @override
  Color backgroundColor() => Colors.white;

  @override
  Future<void> onLoad() async {
    add(_grid);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isMounted) return;
    _grid.resize();
  }
}

class GameOfLifeGrid extends PositionComponent with HasGameRef<GameOfLife> {
  final _livePaint = Paint()..color = Colors.black;
  final _deadPaint = Paint()..color = Colors.grey;
  final _cellSize = 40.0;

  int get _numCellsInX => size.x ~/ _cellSize;
  int get _numCellsInY => size.y ~/ _cellSize;

  late final Timer _timer;

  @override
  FutureOr<void> onLoad() async {
    super.onLoad();
    _timer = Timer(
      .2,
      onTick: _forwardLife,
      repeat: true,
    );
    resize();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer.update(dt);
  }

  void resize() {
    size = gameRef.size * .9;
    final padding = Vector2(
      (gameRef.size.x - (_numCellsInX * _cellSize)) / 2,
      (gameRef.size.y - (_numCellsInY * _cellSize)) / 2,
    );
    position = padding;

    if (gameRef.isRunning) return;
    removeWhere((component) => true);
    addAll(_createCells());
  }

  List<Cell> _createCells() {
    final cells = <Cell>[];
    for (var y = 0; y < _numCellsInY; y++) {
      for (var x = 0; x < _numCellsInX; x++) {
        cells.add(
          Cell(
            x: x * _cellSize,
            y: y * _cellSize,
            width: _cellSize,
            height: _cellSize,
            livePaint: _livePaint,
            deadPaint: _deadPaint,
          ),
        );
      }
    }
    return cells;
  }

  void _forwardLife() {
    if (!gameRef.isRunning) return;

    final List<List<Cell>> cellsMatrix = [
      for (var i = 0; i < _numCellsInY; i++)
        children
            .cast<Cell>()
            .toList()
            .sublist(i * _numCellsInX, (i + 1) * _numCellsInX)
    ];

    final List<List<bool>> cellStates = [];

    for (var i = 0; i < cellsMatrix.length; i++) {
      final row = cellsMatrix[i];
      cellStates.add([]);
      for (var j = 0; j < row.length; j++) {
        final aliveNeighbors = _getAliveNeighbors(cellsMatrix, i, j);

        if (aliveNeighbors < 2 || aliveNeighbors > 3) {
          cellStates[i].add(false);
        } else if (aliveNeighbors == 2) {
          cellStates[i].add(cellsMatrix[i][j].isAlive);
        } else if (aliveNeighbors == 3) {
          cellStates[i].add(true);
        }
      }
    }

    for (var i = 0; i < cellStates.length; i++) {
      final row = cellStates[i];
      for (var j = 0; j < row.length; j++) {
        cellsMatrix[i][j].isAlive = cellStates[i][j];
      }
    }
  }

  int _getAliveNeighbors(List<List<Cell>> cellsMatrix, int x, int y) {
    int aliveNeighbors = 0;
    for (var i = x - 1; i <= x + 1; i++) {
      if (i < 0 || i >= cellsMatrix.length) continue;
      final row = cellsMatrix[i];
      for (var j = y - 1; j <= y + 1; j++) {
        if (j < 0 || j >= row.length) continue;
        final cell = row[j];
        if (cell.isAlive) aliveNeighbors++;
      }
    }
    if (cellsMatrix[x][y].isAlive) aliveNeighbors--;
    return aliveNeighbors;
  }
}

class Cell extends RectangleComponent with TapCallbacks {
  Cell({
    required double x,
    required double y,
    required double width,
    required double height,
    required this.livePaint,
    required this.deadPaint,
  }) : super(
          position: Vector2(x, y),
          size: Vector2(width, height),
          scale: Vector2.all(.95),
        );

  final Paint livePaint;
  final Paint deadPaint;

  bool isAlive = false;

  @override
  Paint get paint => isAlive ? livePaint : deadPaint;

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    isAlive = !isAlive;
  }
}
