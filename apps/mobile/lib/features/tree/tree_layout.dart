import 'dart:math' as math;
import 'dart:ui';

import '../../services/api_models.dart';

/// A person's position on the relationship canvas.
class TreePersonPlacement {
  const TreePersonPlacement({
    required this.person,
    required this.rect,
    required this.generation,
    required this.compact,
  });

  final ApiPerson person;
  final Rect rect;
  final int generation;
  final bool compact;

  Offset get center => rect.center;
}

/// Computed geometry for one family tree.
///
/// The layout is intentionally data-driven: generations come from the API and
/// every visible box belongs to a real person. No demo coordinates or names are
/// involved.
class TreeLayout {
  const TreeLayout({
    required this.placements,
    required this.edges,
    required this.marriageBridges,
    required this.unionNodes,
    required this.branchNodes,
    required this.generations,
    required this.generationLabels,
    required this.focusPoints,
    required this.width,
    required this.height,
  });

  final List<TreePersonPlacement> placements;
  final List<List<Offset>> edges;
  final List<(Offset, Offset)> marriageBridges;
  final List<Offset> unionNodes;
  final List<Offset> branchNodes;
  final List<int> generations;
  final List<(int, double)> generationLabels;
  final Map<int, Offset> focusPoints;
  final double width;
  final double height;

  int get personCount => placements.length;

  TreePersonPlacement? placementFor(String personId) {
    for (final placement in placements) {
      if (placement.person.id == personId) return placement;
    }
    return null;
  }

  static TreeLayout? fromTree(ApiTree? tree) {
    if (tree == null || tree.persons.isEmpty) return null;
    return _TreeLayoutBuilder(tree).build();
  }
}

class _Unit {
  _Unit({required this.members, required this.generation});

  final List<ApiPerson> members;
  final int generation;
  final Set<String> parentIds = {};
  final Set<_Unit> parents = {};
  final Set<_Unit> children = {};

  double left = 0;
  double width = 0;
  double get center => left + width / 2;
}

class _TreeLayoutBuilder {
  _TreeLayoutBuilder(this.tree)
    : persons = {for (final person in tree.persons) person.id: person};

  final ApiTree tree;
  final Map<String, ApiPerson> persons;
  final Map<int, List<_Unit>> unitsByGeneration = {};
  final List<int> generations = [];
  final Map<int, bool> compactByGeneration = {};
  final Map<int, double> topByGeneration = {};
  final Map<int, double> rowHeightByGeneration = {};
  final Map<String, TreePersonPlacement> placementsById = {};

  static const double _contentLeft = 80;
  static const double _top = 30;
  static const double _right = 28;
  static const double _bottom = 34;
  static const double _memberGap = 14;
  static const double _unitGap = 38;
  static const double _familyGap = 92;
  static const double _generationGap = 78;
  static const double _wideWidth = 150;
  static const double _wideHeight = 82;
  static const double _compactWidth = 96;
  static const double _compactHeight = 128;

  TreeLayout build() {
    final rawGenerations =
        tree.persons.map((person) => person.generationNo).toSet().toList()
          ..sort();
    generations.addAll(rawGenerations);

    for (final generation in generations) {
      final people =
          tree.persons
              .where((person) => person.generationNo == generation)
              .toList()
            ..sort(_comparePeople);
      compactByGeneration[generation] =
          people.length > 3 || tree.persons.length > 22;
      rowHeightByGeneration[generation] = compactByGeneration[generation]!
          ? _compactHeight
          : _wideHeight;
    }

    _buildUnits();
    _initializeOrder();
    for (var pass = 0; pass < 5; pass++) {
      _alignToParents();
      _alignToChildren();
    }
    _finalizeHorizontal();
    _buildPlacements();
    final geometry = _buildConnections();
    return TreeLayout(
      placements: placementsById.values.toList(growable: false),
      edges: geometry.edges,
      marriageBridges: geometry.bridges,
      unionNodes: geometry.unions,
      branchNodes: geometry.branches,
      generations: List.unmodifiable(generations),
      generationLabels: [
        for (final generation in generations)
          (
            generation,
            topByGeneration[generation]! +
                rowHeightByGeneration[generation]! / 2,
          ),
      ],
      focusPoints: _focusPoints(),
      width: geometry.canvasWidth,
      height: geometry.canvasHeight,
    );
  }

  int _comparePeople(ApiPerson a, ApiPerson b) {
    final birthOrder = (a.birthOrder ?? 999).compareTo(b.birthOrder ?? 999);
    if (birthOrder != 0) return birthOrder;
    final branch = (a.branchId ?? '').compareTo(b.branchId ?? '');
    if (branch != 0) return branch;
    final birth = (a.birth?.year ?? 9999).compareTo(b.birth?.year ?? 9999);
    if (birth != 0) return birth;
    return a.fullName.compareTo(b.fullName);
  }

  void _buildUnits() {
    final spouseOf = <String, String>{};
    for (final edge in tree.spouses) {
      // Spouse relationship status is married/widowed/divorced/unknown, not
      // active. Only an explicitly divorced pair should be laid out apart.
      if (edge.status == 'divorced') continue;
      final a = persons[edge.personAId];
      final b = persons[edge.personBId];
      if (a == null || b == null || a.generationNo != b.generationNo) {
        continue;
      }
      spouseOf.putIfAbsent(a.id, () => b.id);
      spouseOf.putIfAbsent(b.id, () => a.id);
    }

    final used = <String>{};
    for (final generation in generations) {
      final units = <_Unit>[];
      for (final person in tree.persons.where(
        (person) => person.generationNo == generation,
      )) {
        if (!used.add(person.id)) continue;
        final members = <ApiPerson>[person];
        final spouseId = spouseOf[person.id];
        final spouse = spouseId == null ? null : persons[spouseId];
        if (spouse != null &&
            spouse.generationNo == generation &&
            used.add(spouse.id)) {
          members.add(spouse);
        }
        members.sort((a, b) {
          final aHasParent = _hasParent(a.id);
          final bHasParent = _hasParent(b.id);
          if (aHasParent != bHasParent) return aHasParent ? -1 : 1;
          if (a.gender != b.gender) return a.gender == 'male' ? -1 : 1;
          return _comparePeople(a, b);
        });
        final unit = _Unit(members: members, generation: generation);
        unit.width =
            members.length * _cardWidth(generation) +
            (members.length - 1) * _memberGap;
        units.add(unit);
      }
      units.sort((a, b) {
        final aMember = a.members.first;
        final bMember = b.members.first;
        return _comparePeople(aMember, bMember);
      });
      unitsByGeneration[generation] = units;
    }

    for (final generation in generations) {
      for (final unit in unitsByGeneration[generation]!) {
        for (final member in unit.members) {
          for (final edge in tree.parentChild) {
            if (edge.childId == member.id || edge.parentId == member.id) {
              if (edge.childId == member.id) unit.parentIds.add(edge.parentId);
            }
          }
        }
      }
    }

    final unitByPerson = <String, _Unit>{
      for (final units in unitsByGeneration.values)
        for (final unit in units)
          for (final member in unit.members) member.id: unit,
    };
    for (final edge in tree.parentChild) {
      final parentUnit = unitByPerson[edge.parentId];
      final childUnit = unitByPerson[edge.childId];
      if (parentUnit == null || childUnit == null) continue;
      if (parentUnit.generation >= childUnit.generation) continue;
      parentUnit.children.add(childUnit);
      childUnit.parents.add(parentUnit);
    }
  }

  bool _hasParent(String personId) {
    return tree.parentChild.any((edge) => edge.childId == personId);
  }

  void _initializeOrder() {
    for (final generation in generations) {
      var x = 0.0;
      for (final unit in unitsByGeneration[generation]!) {
        unit.left = x;
        x += unit.width + _unitGap;
      }
    }
  }

  void _alignToParents() {
    for (final generation in generations) {
      final units = unitsByGeneration[generation]!;
      final desired = <_Unit, double>{
        for (final unit in units)
          unit: unit.parents.isEmpty
              ? unit.center
              : unit.parents
                        .map((parent) => parent.center)
                        .reduce((a, b) => a + b) /
                    unit.parents.length,
      };
      _pack(units, desired);
    }
  }

  void _alignToChildren() {
    for (final generation in generations.reversed) {
      final units = unitsByGeneration[generation]!;
      final desired = <_Unit, double>{
        for (final unit in units)
          unit: unit.children.isEmpty
              ? unit.center
              : unit.children
                        .map((child) => child.center)
                        .reduce((a, b) => a + b) /
                    unit.children.length,
      };
      _pack(units, desired);
    }
  }

  void _pack(List<_Unit> units, Map<_Unit, double> desired) {
    // Keep each root family together and leave a clear visual gap between the
    // grandfather's branch, the second-grandfather's branch, etc. Sorting all
    // units by their desired centre alone would interleave those families.
    final groups = <String, List<_Unit>>{};
    for (final unit in units) {
      groups.putIfAbsent(_unitRoot(unit), () => []).add(unit);
    }
    final orderedRoots = groups.keys.toList()
      ..sort((a, b) {
        final personA = persons[a];
        final personB = persons[b];
        if (personA == null || personB == null) return a.compareTo(b);
        return _comparePeople(personA, personB);
      });

    var x = 0.0;
    var firstGroup = true;
    for (final root in orderedRoots) {
      final group = groups[root]!;
      group.sort((a, b) {
        final result = desired[a]!.compareTo(desired[b]!);
        if (result != 0) return result;
        return _comparePeople(a.members.first, b.members.first);
      });
      if (!firstGroup) x += _familyGap;
      firstGroup = false;
      for (final unit in group) {
        unit.left = x;
        x += unit.width + _unitGap;
      }
    }
  }

  final Map<String, String> _rootCache = {};

  String _unitRoot(_Unit unit) {
    for (final member in unit.members) {
      if (_hasParent(member.id)) return _rootOf(member.id);
    }
    return _rootOf(unit.members.first.id);
  }

  String _rootOf(String personId) {
    final cached = _rootCache[personId];
    if (cached != null) return cached;
    String? parent;
    for (final edge in tree.parentChild) {
      if (edge.childId == personId) {
        parent = edge.parentId;
        break;
      }
    }
    final root = parent == null ? personId : _rootOf(parent);
    _rootCache[personId] = root;
    return root;
  }

  void _finalizeHorizontal() {
    var maxWidth = 0.0;
    for (final generation in generations) {
      final row = unitsByGeneration[generation]!;
      if (row.isEmpty) continue;
      maxWidth = math.max(maxWidth, _rowRight(row));
    }
    var top = _top;
    for (final generation in generations) {
      final row = unitsByGeneration[generation]!;
      final rowWidth = row.isEmpty ? 0.0 : _rowRight(row);
      final offset = _contentLeft + (maxWidth - rowWidth) / 2;
      for (final unit in row) {
        unit.left += offset;
      }
      topByGeneration[generation] = top;
      top += rowHeightByGeneration[generation]! + _generationGap;
    }
    _canvasWidth = _contentLeft + maxWidth + _right;
    _canvasHeight = top - _generationGap + _bottom;
  }

  double _rowRight(List<_Unit> row) => row
      .map((unit) => unit.left + unit.width)
      .reduce((a, b) => math.max(a, b));

  double _canvasWidth = 0;
  double _canvasHeight = 0;

  double _cardWidth(int generation) =>
      compactByGeneration[generation]! ? _compactWidth : _wideWidth;

  double _cardHeight(int generation) =>
      compactByGeneration[generation]! ? _compactHeight : _wideHeight;

  void _buildPlacements() {
    for (final generation in generations) {
      for (final unit in unitsByGeneration[generation]!) {
        var left = unit.left;
        for (final member in unit.members) {
          final rect = Rect.fromLTWH(
            left,
            topByGeneration[generation]!,
            _cardWidth(generation),
            _cardHeight(generation),
          );
          placementsById[member.id] = TreePersonPlacement(
            person: member,
            rect: rect,
            generation: generation,
            compact: compactByGeneration[generation]!,
          );
          left += _cardWidth(generation) + _memberGap;
        }
      }
    }
  }

  _TreeGeometry _buildConnections() {
    final edges = <List<Offset>>[];
    final bridges = <(Offset, Offset)>[];
    final unions = <Offset>[];
    final branches = <Offset>[];

    for (final unit in unitsByGeneration.values.expand((row) => row)) {
      if (unit.members.length < 2) continue;
      final placements = unit.members
          .map((member) => placementsById[member.id])
          .whereType<TreePersonPlacement>()
          .toList();
      if (placements.length < 2) continue;
      final first = placements[0];
      final second = placements[1];
      final y = first.rect.center.dy;
      bridges.add((Offset(first.rect.right, y), Offset(second.rect.left, y)));
      unions.add(Offset((first.rect.right + second.rect.left) / 2, y));
    }

    final parentEdges = <String, List<ApiParentChildEdge>>{};
    for (final edge in tree.parentChild) {
      parentEdges.putIfAbsent(edge.childId, () => []).add(edge);
    }

    for (final entry in parentEdges.entries) {
      final child = placementsById[entry.key];
      if (child == null) continue;
      final parents = entry.value
          .map((edge) => placementsById[edge.parentId])
          .whereType<TreePersonPlacement>()
          .toList();
      if (parents.isEmpty) continue;
      parents.sort((a, b) => a.center.dx.compareTo(b.center.dx));

      final double anchorX;
      final double startY;
      if (parents.length >= 2 &&
          parents[0].generation == parents[1].generation) {
        anchorX = (parents[0].center.dx + parents[1].center.dx) / 2;
        startY = parents[0].center.dy;
      } else {
        anchorX =
            parents.map((parent) => parent.center.dx).reduce((a, b) => a + b) /
            parents.length;
        startY = parents.map((parent) => parent.rect.bottom).reduce(math.max);
      }

      final childX = child.center.dx;
      final childTop = child.rect.top;
      final distance = math.max(20.0, childTop - startY);
      final midY = startY + distance * 0.46;
      final path = <Offset>[
        Offset(anchorX, startY),
        Offset(anchorX, midY),
        Offset(childX, midY),
        Offset(childX, childTop),
      ];
      edges.add(path);
      unions.add(Offset(anchorX, startY));
      branches.add(Offset(childX, midY));
    }

    return _TreeGeometry(
      edges: List.unmodifiable(edges),
      bridges: List.unmodifiable(bridges),
      unions: List.unmodifiable(unions),
      branches: List.unmodifiable(branches),
      canvasWidth: _canvasWidth,
      canvasHeight: _canvasHeight,
    );
  }

  Map<int, Offset> _focusPoints() {
    final result = <int, Offset>{};
    for (final generation in generations) {
      final row = unitsByGeneration[generation]!;
      if (row.isEmpty) continue;
      final minLeft = row
          .map((unit) => unit.left)
          .reduce((a, b) => math.min(a, b));
      final maxRight = _rowRight(row);
      result[generation] = Offset(
        (minLeft + maxRight) / 2,
        topByGeneration[generation]! + rowHeightByGeneration[generation]! / 2,
      );
    }
    return result;
  }
}

class _TreeGeometry {
  const _TreeGeometry({
    required this.edges,
    required this.bridges,
    required this.unions,
    required this.branches,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final List<List<Offset>> edges;
  final List<(Offset, Offset)> bridges;
  final List<Offset> unions;
  final List<Offset> branches;
  final double canvasWidth;
  final double canvasHeight;
}
