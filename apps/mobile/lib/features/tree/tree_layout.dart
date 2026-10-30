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

/// One parent-to-child connector. [colorSlot] comes from the child's position
/// among its siblings, so siblings can be drawn in different colours.
class TreeEdge {
  const TreeEdge({required this.points, required this.colorSlot});

  final List<Offset> points;
  final int colorSlot;
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
  final List<TreeEdge> edges;
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
  final Map<_Unit, double> _subtreeWidthCache = {};

  static const double _contentLeft = 80;
  static const double _top = 28;
  static const double _right = 28;
  static const double _bottom = 30;
  static const double _memberGap = 14;
  static const double _childGap = 30;
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
      final people = tree.persons
          .where((person) => person.generationNo == generation)
          .toList();
      compactByGeneration[generation] =
          people.length > 3 || tree.persons.length > 22;
      rowHeightByGeneration[generation] = compactByGeneration[generation]!
          ? _compactHeight
          : _wideHeight;
    }

    _buildUnits();
    _chooseLayoutParents();
    _layoutForest();
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
      // Spouse status is married/widowed/divorced/unknown. Only an explicitly
      // divorced pair should be placed apart.
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
      final people =
          tree.persons
              .where((person) => person.generationNo == generation)
              .toList()
            ..sort(_comparePeople);
      for (final person in people) {
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
      units.sort((a, b) => _comparePeople(a.members.first, b.members.first));
      unitsByGeneration[generation] = units;
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

  /// A child with two parents normally has both parents in one couple unit.
  /// If the data has them in separate units, keep the child under one parent
  /// for layout purposes so it is not drawn twice.
  void _chooseLayoutParents() {
    for (final generation in generations) {
      for (final unit in unitsByGeneration[generation]!) {
        if (unit.parents.length < 2) continue;
        final keep = unit.parents.toList()
          ..sort((a, b) => _comparePeople(a.members.first, b.members.first));
        final layoutParent = keep.first;
        for (final parent in unit.parents) {
          if (parent != layoutParent) parent.children.remove(unit);
        }
        unit.parents
          ..clear()
          ..add(layoutParent);
      }
    }
  }

  void _layoutForest() {
    var top = _top;
    for (final generation in generations) {
      topByGeneration[generation] = top;
      top += rowHeightByGeneration[generation]! + _generationGap;
    }

    final roots =
        unitsByGeneration.values
            .expand((row) => row)
            .where((unit) => unit.parents.isEmpty)
            .toList()
          ..sort((a, b) {
            final generation = a.generation.compareTo(b.generation);
            if (generation != 0) return generation;
            return _comparePeople(a.members.first, b.members.first);
          });

    var left = _contentLeft;
    for (var index = 0; index < roots.length; index++) {
      final root = roots[index];
      _placeUnit(root, left);
      left += _subtreeWidth(root);
      if (index != roots.length - 1) left += _familyGap;
    }
    _canvasWidth = left + _right;
    _canvasHeight = top - _generationGap + _bottom;
  }

  double _subtreeWidth(_Unit unit) {
    final cached = _subtreeWidthCache[unit];
    if (cached != null) return cached;
    final children = _sortedChildren(unit);
    var childrenWidth = 0.0;
    for (var index = 0; index < children.length; index++) {
      childrenWidth += _subtreeWidth(children[index]);
      if (index != children.length - 1) childrenWidth += _childGap;
    }
    final width = math.max(unit.width, childrenWidth);
    _subtreeWidthCache[unit] = width;
    return width;
  }

  void _placeUnit(_Unit unit, double left) {
    final width = _subtreeWidth(unit);
    unit.left = left + (width - unit.width) / 2;
    final children = _sortedChildren(unit);
    if (children.isEmpty) return;
    var childrenWidth = 0.0;
    for (var index = 0; index < children.length; index++) {
      childrenWidth += _subtreeWidth(children[index]);
      if (index != children.length - 1) childrenWidth += _childGap;
    }
    var childLeft = left + (width - childrenWidth) / 2;
    for (final child in children) {
      _placeUnit(child, childLeft);
      childLeft += _subtreeWidth(child) + _childGap;
    }
  }

  List<_Unit> _sortedChildren(_Unit unit) {
    final children = unit.children.toList()
      ..sort((a, b) => _comparePeople(a.members.first, b.members.first));
    return children;
  }

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
    final edges = <TreeEdge>[];
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

    final grouped = <String, List<ApiParentChildEdge>>{};
    for (final edge in tree.parentChild) {
      final key = ([edge.parentId]..sort()).join('|');
      grouped.putIfAbsent(key, () => []).add(edge);
    }

    for (final group in grouped.values) {
      final children =
          group
              .map((edge) => placementsById[edge.childId])
              .whereType<TreePersonPlacement>()
              .toList()
            ..sort((a, b) => a.center.dx.compareTo(b.center.dx));
      if (children.isEmpty) continue;
      final parentPlacements =
          group
              .map((edge) => placementsById[edge.parentId])
              .whereType<TreePersonPlacement>()
              .toSet()
              .toList()
            ..sort((a, b) => a.center.dx.compareTo(b.center.dx));
      if (parentPlacements.isEmpty) continue;

      for (var index = 0; index < children.length; index++) {
        final child = children[index];
        final double anchorX;
        final double startY;
        if (parentPlacements.length >= 2 &&
            parentPlacements[0].generation == parentPlacements[1].generation) {
          anchorX =
              (parentPlacements[0].center.dx + parentPlacements[1].center.dx) /
              2;
          startY = parentPlacements[0].center.dy;
        } else {
          anchorX =
              parentPlacements
                  .map((parent) => parent.center.dx)
                  .reduce((a, b) => a + b) /
              parentPlacements.length;
          startY = parentPlacements
              .map((parent) => parent.rect.bottom)
              .reduce(math.max);
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
        edges.add(TreeEdge(points: path, colorSlot: index));
        unions.add(Offset(anchorX, startY));
        branches.add(Offset(childX, midY));
      }
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
      final maxRight = row
          .map((unit) => unit.left + unit.width)
          .reduce((a, b) => math.max(a, b));
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

  final List<TreeEdge> edges;
  final List<(Offset, Offset)> bridges;
  final List<Offset> unions;
  final List<Offset> branches;
  final double canvasWidth;
  final double canvasHeight;
}
