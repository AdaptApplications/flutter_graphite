import 'typings.dart';

bool isMultiple(Map<String, List<String>> m, String id) {
  return m.containsKey(id) && m[id]!.length > 1;
}

void addUniqueRelation(Map<String, List<String>> rm, String key, String value) {
  var ok = rm.containsKey(key);
  if (!ok) {
    rm[key] = [value];
  }
  if (!rm[key]!.contains(value)) {
    rm[key]!.add(value);
  }
}

class GraphBasic {
  GraphBasic({required List<NodeInput> list, required bool centred}) {
    this.centred = centred;
    this.list = list;
    nodesMap = this.list.fold(<String, NodeInput>{}, (m, node) {
      if (m.containsKey(node.id)) {
        throw 'Duplicate node ${node.id}';
      }
      m[node.id] = node;
      return m;
    });

    detectIncomesAndOutcomes();
  }

  void detectIncomesAndOutcomes() {
    Set<String> totalSet = {};
    for (var node in list) {
      if (totalSet.contains(node.id)) {
        continue;
      }
      Set<String> branchSet = {};
      traverseVertically(node, branchSet, totalSet);
    }
  }

  Set<String> traverseVertically(NodeInput node, Set<String> branchSet, Set<String> totalSet) {
    if (branchSet.contains(node.id)) {
      throw 'duplicate incomes for node id ${node.id}';
    }
    branchSet.add(node.id);
    totalSet.add(node.id);
    for (var out in node.next) {
      if (isLoopEdge(node.id, out.outcome)) {
        continue;
      }
      if (branchSet.contains((out.outcome))) {
        addUniqueRelation(loopsByNodeIdMap, node.id, out.outcome);
        continue;
      }
      addUniqueRelation(incomesByNodeIdMap, out.outcome, node.id);
      addUniqueRelation(outcomesByNodeIdMap, node.id, out.outcome);
      final nextNode = nodesMap[out.outcome];
      if (nextNode == null) {
        throw 'node ${out.outcome} not found';
      }
      if (totalSet.contains(out.outcome)) continue;
      totalSet = traverseVertically(nextNode, Set.from(branchSet), totalSet);
    }
    return totalSet;
  }

  bool isLoopEdge(String nodeId, String outcomeId) {
    if (!loopsByNodeIdMap.containsKey(nodeId)) {
      return false;
    }
    return loopsByNodeIdMap[nodeId]?.contains(outcomeId) ?? false;
  }

  List<NodeInput> roots() {
    return list.where((NodeInput node) {
      return isRoot(node.id);
    }).toList();
  }

  bool isRoot(String id) {
    return !incomesByNodeIdMap.containsKey(id) || (incomesByNodeIdMap[id]?.isEmpty ?? false);
  }

  bool isSplit(String id) {
    return isMultiple(outcomesByNodeIdMap, id);
  }

  bool isJoin(String id) {
    return isMultiple(incomesByNodeIdMap, id);
  }

  List<String> loops(String id) {
    return loopsByNodeIdMap[id] ?? [];
  }

  List<String> outcomes(String id) {
    return outcomesByNodeIdMap[id] ?? [];
  }

  List<String> incomes(String id) {
    return incomesByNodeIdMap[id] ?? [];
  }

  NodeInput node(String id) {
    return nodesMap[id]!;
  }

  NodeType nodeType(String id) {
    if (isRoot(id) && isSplit(id)) return NodeType.rootSplit;
    if (isRoot(id)) return NodeType.rootSimple;
    if (isSplit(id) && isJoin(id)) return NodeType.splitJoin;
    if (isSplit(id)) return NodeType.split;
    if (isJoin(id)) return NodeType.join;
    return NodeType.simple;
  }

  List<NodeInput> getOutcomesArray(String itemId) {
    List<String> outcomes = this.outcomes(itemId);
    if (outcomes.isEmpty) return [];
    return outcomes.map((String id) {
      return node(id);
    }).toList(growable: true);
  }

  List<NodeInput> list = [];
  Map<String, NodeInput> nodesMap = {};
  Map<String, List<String>> incomesByNodeIdMap = {};
  Map<String, List<String>> outcomesByNodeIdMap = {};
  Map<String, List<String>> loopsByNodeIdMap = {};
  bool centred = false;
}
