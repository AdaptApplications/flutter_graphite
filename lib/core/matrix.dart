import 'typings.dart';

class FindNodeResult {
  FindNodeResult({
    required this.coords,
    required this.item,
  });
  List<int> coords;
  NodeOutput item;
}

String fillWithSpaces(String str, int l) {
  while (str.length < l) {
    str += " ";
  }
  return str;
}

class Matrix {
  Matrix()
      : s = [],
        orientation = MatrixOrientation.Horizontal;

  int width() {
    return s.fold(0, (w, row) => row.length > w ? row.length : w);
  }

  int height() {
    return s.length;
  }

  bool hasHorizontalCollision(int x, int y) {
    if (s.isEmpty || y >= s.length) {
      return false;
    }
    var row = s[y];
    return row.any((MatrixCell? point) {
      if (point != null && !isAllChildrenOnMatrix(point)) {
        return true;
      }
      return false;
    });
  }

  bool hasLoopAnchorCollision(int x, int y, int toX, String id) {
    if (s.isEmpty || y >= s.length) {
      return false;
    }
    if (x == 0) return false;
    final row = s[y];
    for (int dx = x - 1; dx >= toX + 1; dx--) {
      final cell = row[dx];
      if (cell == null) continue;
      return true;
    }
    // check last
    final cell = s[y][toX];
    if (cell == null) return false;
    if (!cell.isFull && cell.margin != null && cell.margin == AnchorMargin.start) return false;
    return true;
  }

  bool cellBusyForItem(NodeOutput item, int x, int y) {
    if (s.isEmpty || y >= s.length) {
      return false;
    }
    final cell = s[y][x];
    if (cell == null) return false;
    if (!cell.isFull && item.isAnchor && cell.margin != null && cell.margin != item.anchorMargin) return false;
    return true;
  }

  bool hasVerticalCollision(int x, int y) {
    if (x >= width()) {
      return false;
    }
    return s.asMap().entries.any((data) {
      var index = data.key;
      var row = data.value;
      return index >= y && x < row.length && row[x] != null;
    });
  }

  int getFreeRowForColumn(int x) {
    if (height() == 0) {
      return 0;
    }
    final entries = s.asMap().entries.toList();
    final idx = entries.indexWhere((data) {
      var row = data.value;
      return row.isEmpty || x >= row.length || row[x] == null;
    });
    var y = idx == -1 ? height() : entries[idx].key;
    return y;
  }

  void extendHeight(int toValue) {
    while (height() < toValue) {
      s.add(List.filled(width(), null, growable: true));
    }
  }

  void extendWidth(int toValue) {
    for (var i = 0; i < height(); i++) {
      while (s[i].length < toValue) {
        s[i].add(null);
      }
    }
  }

  void insertRowBefore(int y) {
    List<MatrixCell?> row = List.filled(width(), null, growable: true);
    s.insert(y, row);
  }

  void insertColumnBefore(int x) {
    for (var row in s) {
      row.insert(x, null);
    }
  }

  List<int>? find(bool Function(NodeOutput) f) {
    List<int>? result;
    s.asMap().entries.any((rowEntry) {
      var y = rowEntry.key;
      var row = rowEntry.value;
      return row.asMap().entries.any((columnEntry) {
        var x = columnEntry.key;
        var cell = columnEntry.value;
        if (cell == null) return false;
        if (cell.all.any((c) => f(c))) {
          result = [x, y];
          return true;
        }
        return false;
      });
    });
    return result;
  }

  FindNodeResult? findNode(bool Function(NodeOutput) f) {
    FindNodeResult? result;
    s.asMap().entries.any((rowEntry) {
      var y = rowEntry.key;
      var row = rowEntry.value;
      return row.asMap().entries.any((columnEntry) {
        var x = columnEntry.key;
        var cell = columnEntry.value;
        if (cell == null) return false;
        final i = cell.all.indexWhere((c) => f(c));
        if (i != -1) {
          result = FindNodeResult(coords: [x, y], item: cell.all[i]);
          return true;
        }
        return false;
      });
    });
    return result;
  }

  MatrixCell? getByCoords(int x, int y) {
    if (x >= width() || y >= height()) {
      return null;
    }
    return s[y][x];
  }

  void insert(int x, int y, NodeOutput item) {
    if (height() <= y) {
      extendHeight(y + 1);
    }
    if (width() <= x) {
      extendWidth(x + 1);
    }
    final current = s[y][x];
    if (current == null) {
      s[y][x] = !item.isAnchor ? MatrixCell(full: item) : (item.anchorMargin! == AnchorMargin.end ? MatrixCell(end: item) : MatrixCell(start: item));
      return;
    }
    if (!current.isFull && current.margin != null && current.margin != item.anchorMargin) {
      current.add(item);
    }
  }

  void put(int x, int y, MatrixCell? item) {
    if (height() <= y) {
      extendHeight(y + 1);
    }
    if (width() <= x) {
      extendWidth(x + 1);
    }
    s[y][x] = item;
  }

  bool isAllChildrenOnMatrix(MatrixCell cell) {
    return cell.all.every((item) => item.next.length == item.childrenOnMatrix);
  }

  Map<String, MatrixNode> normalize() {
    Map<String, MatrixNode> acc = {};
    s.asMap().entries.forEach((rowEntry) {
      var y = rowEntry.key;
      var row = rowEntry.value;
      row.asMap().entries.forEach((columnEntry) {
        var x = columnEntry.key;
        var cell = columnEntry.value;
        if (cell != null) {
          for (var item in cell.all) {
            acc[item.id] = MatrixNode.fromNodeOutput(x: x, y: y, nodeOutput: item);
          }
        }
      });
    });
    return acc;
  }

  Matrix rotate() {
    var newMtx = Matrix();
    s.asMap().forEach((y, row) {
      row.asMap().forEach((x, cell) {
        newMtx.put(y, x, cell);
      });
    });
    newMtx.orientation = orientation == MatrixOrientation.Horizontal ? MatrixOrientation.Vertical : MatrixOrientation.Horizontal;
    return newMtx;
  }

  @override
  String toString() {
    var result = "", max = 0;
    for (var row in s) {
      for (var cell in row) {
        if (cell == null) continue;
        if (cell.displayId.length > max) {
          max = cell.displayId.length;
        }
      }
    }
    for (var row in s) {
      for (var cell in row) {
        if (cell == null) {
          result += fillWithSpaces(" ", max);
          result += "│";
          continue;
        }
        result += fillWithSpaces(cell.displayId, max);
        result += "│";
      }
      result += "\n";
    }
    return result;
  }

  MatrixOrientation orientation;
  List<List<MatrixCell?>> s;
}

class MatrixCell {
  NodeOutput? start;
  NodeOutput? end;
  NodeOutput? full;
  MatrixCell({this.full, this.start, this.end})
      : assert((full != null && start == null && end == null) ||
            (full == null && start != null && end == null) ||
            (full == null && start == null && end != null) ||
            (full == null && start != null && end != null));

  bool get isFull => full != null;

  String get displayId => isFull ? full!.id : (start != null && end != null ? "${start!.id}+${end!.id}" : (start ?? end)!.id);

  AnchorMargin? get margin => isFull ? null : (start != null && end != null ? null : (start ?? end)!.anchorMargin);

  List<NodeOutput> get all => isFull ? [full!] : (start != null && end != null ? [start!, end!] : [(start ?? end)!]);

  void add(NodeOutput item) {
    if (item.anchorMargin == AnchorMargin.end) {
      if (end != null) {
        throw "end is occupied";
      }
      end = item;
    }
    if (item.anchorMargin == AnchorMargin.start) {
      if (start != null) {
        throw "start is occupied";
      }
      start = item;
    }
  }

  NodeOutput? getById(String id) {
    if (full != null && full!.id == id) {
      return full!;
    }
    if (start != null && start!.id == id) {
      return start!;
    }
    if (end != null && end!.id == id) {
      return end!;
    }
    return null;
  }
}
