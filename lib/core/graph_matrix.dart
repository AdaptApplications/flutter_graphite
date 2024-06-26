import 'dart:math';

import 'graph_basic.dart';
import 'matrix.dart';
import 'traverse_queue.dart';
import 'typings.dart';

class State {
  final Matrix mtx;
  TraverseQueue queue;
  int x;
  int y;
  int iterations;
  State({
    required this.mtx,
    required this.queue,
    this.x = 0,
    this.y = 0,
    this.iterations = 0,
  });
}

class HorizontalCollisionCheck {
  int? untilX;
}

class GraphMatrix extends GraphBasic {
  GraphMatrix({required super.list, required super.centred});

  bool joinHasUnresolvedIncomes(NodeOutput item) {
    return item.passedIncomes.length != incomes(item.id).length;
  }

  void insertNodeOnMatrix(NodeOutput item, State state, bool checkCollision) {
    var mtx = state.mtx;
    // check occupied here
    if (checkCollision && (mtx.hasHorizontalCollision(state.x, state.y) || mtx.cellBusyForItem(item, state.x, state.y))) {
      mtx.insertRowBefore(state.y);
    }
    mtx.insert(state.x, state.y, item);
    markIncomesAsPassed(mtx, item);
    return;
  }

  int getCenterYAmongIncomes(NodeOutput item, Matrix mtx) {
    final incomes = item.passedIncomes.map((e) => e).toList();
    if (incomes.isEmpty) {
      return 0;
    }
    incomes.sort((keyA, keyB) {
      List<int>? coordsA = mtx.find((NodeOutput itm) {
        return itm.id == keyA;
      });
      List<int>? coordsB = mtx.find((NodeOutput itm) {
        return itm.id == keyB;
      });
      if (coordsA?.length != 2) throw "cannot find coordinates for passed income: $keyA";
      if (coordsB?.length != 2) throw "cannot find coordinates for passed income: $keyB";

      return coordsA![1] > coordsB![1] ? 1 : -1;
    });
    int centerIndex = (incomes.length.toDouble() / 2).ceil() - 1;
    String centerKey = incomes[centerIndex];
    List<int>? coords = mtx.find((NodeOutput itm) {
      return itm.id == centerKey;
    });
    if (coords?.length != 2) throw "cannot find coordinates for passed center income: $centerKey";
    return coords![1];
  }

  int getLowestYAmongIncomes(NodeOutput item, Matrix mtx) {
    final incomes = item.passedIncomes;
    if (incomes.isEmpty) {
      return 0;
    }
    return incomes.map((String id) {
      List<int>? coords = mtx.find((NodeOutput itm) {
        return itm.id == id;
      });
      if (coords?.length != 2) throw "cannot find coordinates for passed income: $id";
      return coords![1];
    }).reduce(min);
  }

  bool processOrSkipNodeOnMatrix(NodeOutput item, State state) {
    var mtx = state.mtx;
    var queue = state.queue;
    if (item.passedIncomes.isNotEmpty) {
      state.y = centred ? getCenterYAmongIncomes(item, mtx) : getLowestYAmongIncomes(item, mtx);
    }
    bool hasLoops = this.hasLoops(item);
    List<LoopNode> loopNodes = [];
    if (hasLoops) {
      loopNodes = handleLoopEdges(item, state);
    }
    bool needsLoopSkip = hasLoops && loopNodes.isEmpty;
    if (mtx.hasVerticalCollision(state.x, state.y) || needsLoopSkip) {
      queue.push(item);
      return false;
    }
    insertNodeOnMatrix(item, state, false);

    if (loopNodes.isNotEmpty) {
      loopNodes.sort((a, b) => a.isSelfLoop ? -1 : 1); // process self-loop first
      insertLoopEdges(item, state, loopNodes);
    }
    return true;
  }

  List<LoopNode> handleLoopEdges(NodeOutput item, State state) {
    var mtx = state.mtx;
    var loops = this.loops(item.id);
    if (loops.isEmpty) throw "no loops found for node ${item.id}";
    List<LoopNode> loopNodes = loops.map((String incomeId) {
      if (item.id == incomeId) {
        return LoopNode(id: incomeId, node: item, x: state.x, y: state.y, isSelfLoop: true);
      }
      List<int>? coords = mtx.find((NodeOutput n) {
        return n.id == incomeId;
      });
      if (coords?.length != 2) throw "loop target $incomeId not found on matrix";
      MatrixCell? cell = mtx.getByCoords(coords![0], coords[1]);
      if (cell == null) throw "loop target cell $incomeId not found on matrix";
      NodeOutput? node = cell.getById(incomeId);
      if (node == null) throw "loop target node $incomeId not found on matrix";
      return LoopNode(id: incomeId, node: node, x: coords[0], y: coords[1], isSelfLoop: false);
    }).toList();
    bool skip = loopNodes.any((LoopNode income) {
      int checkY = income.y != 0 ? income.y - 1 : 0;
      return mtx.hasVerticalCollision(state.x, checkY);
    });
    return skip ? [] : loopNodes;
  }

  bool hasLoops(NodeOutput item) {
    return loops(item.id).isNotEmpty;
  }

  void insertLoopEdges(NodeOutput item, State state, List<LoopNode> loopNodes) {
    var mtx = state.mtx, initialX = state.x, initialY = state.y;
    for (var income in loopNodes) {
      var id = income.id, node = income.node, renderIncomeId = item.id;
      if (income.isSelfLoop) {
        state.x = initialX + 1;
        state.y = initialY;
        String selfLoopId = "$id-self";
        renderIncomeId = selfLoopId;
        insertNodeOnMatrix(
            NodeOutput(
              id: selfLoopId,
              next: [EdgeInput(outcome: id)],
              anchorType: AnchorType.loop,
              anchorMargin: AnchorMargin.start,
              orientation: AnchorOrientation.bottomRight,
              from: item.id,
              to: id,
              isAnchor: true,
              renderIncomes: [node.id],
              passedIncomes: [item.id],
              childrenOnMatrix: 1,
            ),
            state,
            false);
      }
      state.y = min(income.y, state.y);
      int initialHeight = mtx.height();
      String fromId = "$id-${item.id}-from";
      String toId = "$id-${item.id}-to";
      node.renderIncomes.add(fromId);
      if (state.y == 0 || mtx.hasLoopAnchorCollision(state.x, state.y - 1, income.x, toId)) {
        mtx.insertRowBefore(state.y);
      } else {
        state.y--;
      }
      insertNodeOnMatrix(
        NodeOutput(
          id: toId,
          next: [EdgeInput(outcome: id)],
          anchorMargin: AnchorMargin.start,
          anchorType: AnchorType.loop,
          orientation: AnchorOrientation.topRight,
          from: item.id,
          to: id,
          isAnchor: true,
          renderIncomes: [renderIncomeId],
          passedIncomes: [item.id],
          childrenOnMatrix: 1,
        ),
        state,
        true,
      );
      if (initialHeight != mtx.height()) {
        initialY++;
      }
      state.x = income.x;
      insertNodeOnMatrix(
        NodeOutput(
          id: fromId,
          next: [EdgeInput(outcome: id)],
          anchorType: AnchorType.loop,
          anchorMargin: AnchorMargin.end,
          orientation: AnchorOrientation.topLeft,
          from: item.id,
          to: id,
          isAnchor: true,
          renderIncomes: [toId],
          passedIncomes: [item.id],
          childrenOnMatrix: 1,
        ),
        state,
        false,
      );
      state.x = initialX;
    }
    state.y = initialY;
    return;
  }

  void insertSplitOutcomes(NodeOutput item, State state, TraverseQueue levelQueue) {
    var queue = state.queue, outcomes = this.outcomes(item.id);
    if (outcomes.isEmpty) throw "split ${item.id} has no outcomes";
    outcomes = List.from(outcomes);
    if (centred) {
      int initialY = state.y;
      List<String> topOutcomes = [];
      int half = (outcomes.length.toDouble() / 2).ceil() - 1;

      while (half != 0) {
        half--;
        if (state.y == 0 || state.mtx.hasHorizontalCollision(state.x, state.y - 1)) {
          state.mtx.insertRowBefore(state.y);
          initialY++;
        } else {
          state.y--;
        }

        topOutcomes.add(outcomes.removeAt(0));
      }
      for (var outcomeId in topOutcomes) {
        String id = "${item.id}-$outcomeId";
        insertNodeOnMatrix(
          NodeOutput(
            id: id,
            next: [EdgeInput(outcome: outcomeId)],
            anchorType: AnchorType.split,
            anchorMargin: AnchorMargin.end,
            orientation: AnchorOrientation.topLeft,
            from: item.id,
            to: outcomeId,
            isAnchor: true,
            renderIncomes: [item.id],
            passedIncomes: [item.id],
            childrenOnMatrix: 0,
          ),
          state,
          true,
        );
        NodeInput v = node(outcomeId);
        queue.add(incomeId: id, bufferQueue: levelQueue, items: [v]);
        state.y++;
      }
      state.y = initialY;
    }
    String directOutcomeId = outcomes.removeAt(0);
    NodeInput direct = node(directOutcomeId);
    queue.add(incomeId: item.id, bufferQueue: levelQueue, items: [
      NodeInput(
        id: direct.id,
        next: direct.next,
        size: direct.size,
      )
    ]);
    for (var outcomeId in outcomes) {
      state.y++;
      String id = "${item.id}-$outcomeId";
      insertNodeOnMatrix(
        NodeOutput(
          id: id,
          next: [EdgeInput(outcome: outcomeId)],
          anchorType: AnchorType.split,
          anchorMargin: AnchorMargin.end,
          orientation: AnchorOrientation.bottomLeft,
          from: item.id,
          to: outcomeId,
          isAnchor: true,
          renderIncomes: [item.id],
          passedIncomes: [item.id],
          childrenOnMatrix: 0,
        ),
        state,
        true,
      );
      NodeInput v = node(outcomeId);
      queue.add(incomeId: id, bufferQueue: levelQueue, items: [v]);
    }
  }

  void insertJoinIncomes(NodeOutput item, State state, TraverseQueue levelQueue, bool addItemToQueue) {
    final mtx = state.mtx, queue = state.queue, incomes = item.passedIncomes;
    final directY = centred ? getCenterYAmongIncomes(item, mtx) : getLowestYAmongIncomes(item, mtx);
    for (var incomeId in incomes) {
      final found = mtx.findNode((NodeOutput n) {
        return n.id == incomeId;
      });
      if (found == null) throw "income $incomeId was not found";
      final y = found.coords[1], income = found.item;
      if (directY == y) {
        item.renderIncomes.add(incomeId);
        income.childrenOnMatrix = min((income.childrenOnMatrix ?? 0) + 1, income.next.length);
        continue;
      }
      state.y = y;
      String id = "$incomeId-${item.id}";
      item.renderIncomes.add(id);
      insertNodeOnMatrix(
        NodeOutput(
          id: id,
          next: [EdgeInput(outcome: item.id)],
          anchorType: AnchorType.join,
          anchorMargin: AnchorMargin.start,
          orientation: y > directY ? AnchorOrientation.bottomRight : AnchorOrientation.topRight,
          from: incomeId,
          to: item.id,
          isAnchor: true,
          renderIncomes: [incomeId],
          passedIncomes: [incomeId],
          childrenOnMatrix: 1,
        ),
        state,
        false,
      );
    }
    if (addItemToQueue) {
      queue.add(incomeId: item.id, bufferQueue: levelQueue, items: getOutcomesArray(item.id));
    }
    return;
  }

  void markIncomesAsPassed(Matrix mtx, NodeOutput item) {
    for (var incomeId in item.renderIncomes) {
      var found = mtx.findNode((NodeOutput n) {
        return n.id == incomeId;
      });
      if (found == null) throw "income $incomeId not found on matrix";
      var coords = found.coords, income = found.item;
      income.childrenOnMatrix = min((income.childrenOnMatrix ?? 0) + 1, income.next.length);
      mtx.insert(coords[0], coords[1], income);
    }
    return;
  }

  void resolveCurrentJoinIncomes(Matrix mtx, NodeOutput join) {
    markIncomesAsPassed(mtx, join);
    join.renderIncomes = [];
    return;
  }
}
