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
  final Map<String, List<String>> _spouseIds = {};

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
    _spouseIds.clear();
    for (final edge in tree.spouses) {
      // Spouse status is married/widowed/divorced/unknown. Only an explicitly
      // divorced pair should be placed apart.
      if (edge.status == 'divorced') continue;
      final a = persons[edge.personAId];
      final b = persons[edge.personBId];
      if (a == null || b == null || a.generationNo != b.generationNo) {
        continue;
      }
      (_spouseIds[a.id] ??= []).add(b.id);
      (_spouseIds[b.id] ??= []).add(a.id);
    }
    for (final ids in _spouseIds.values) {
      ids.sort((a, b) => _comparePeople(persons[a]!, persons[b]!));
    }

    final used = <String>{};
    for (final generation in generations) {
      final units = <_Unit>[];
      final people =
          tree.persons
              .where((person) => person.generationNo == generation)
              .toList()
            ..sort(_comparePeople);

      void addUnit(List<ApiPerson> members) {
        final unit = _Unit(members: members, generation: generation);
        unit.width =
            members.length * _cardWidth(generation) +
            (members.length - 1) * _memberGap;
        units.add(unit);
      }

      // A husband with several wives should keep all wives beside him. The
      // wives are sorted by birth order, not split into separate units.
      for (final person in people) {
        if (person.gender != 'male' || used.contains(person.id)) continue;
        final wives = (_spouseIds[person.id] ?? const <String>[])
            .map((id) => persons[id])
            .whereType<ApiPerson>()
            .where(
              (spouse) =>
                  spouse.generationNo == generation &&
                  !used.contains(spouse.id),
            )
            .toList();
        if (wives.isEmpty) continue;
        final members = [person, ...wives];
        used.addAll(members.map((person) => person.id));
        addUnit(members);
      }

      for (final person in people) {
        if (!used.add(person.id)) continue;
        final members = <ApiPerson>[person];
        for (final spouseId in _spouseIds[person.id] ?? const <String>[]) {
          final spouse = persons[spouseId];
          if (spouse == null ||
              spouse.generationNo != generation ||
              used.contains(spouse.id)) {
            continue;
          }
          used.add(spouse.id);
          members.add(spouse);
          break;
        }
        if (members.length == 2 &&
            members.first.gender != 'male' &&
            members.last.gender == 'male') {
          final first = members.first;
          final last = members.last;
          members
            ..clear()
            ..addAll([last, first]);
        }
        addUnit(members);
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
    final unions = <Offset>[];
    final branches = <Offset>[];

    // A child belongs to one marriage, not merely to one parent. Grouping by
    // father + mother keeps children of different wives on separate branches.
    final edgesByChild = <String, List<ApiParentChildEdge>>{};
    for (final edge in tree.parentChild) {
      edgesByChild.putIfAbsent(edge.childId, () => []).add(edge);
    }

    // Include ex-wives too: a divorced or remarried wife's children still need
    // their own branch, even though the wife is placed in a separate unit.
    final mothersByFather = <String, List<String>>{};
    for (final entry in edgesByChild.entries) {
      ApiParentChildEdge? fatherEdge;
      ApiParentChildEdge? motherEdge;
      for (final edge in entry.value) {
        if (edge.parentRole == 'father') fatherEdge ??= edge;
        if (edge.parentRole == 'mother') motherEdge ??= edge;
      }
      if (fatherEdge == null || motherEdge == null) continue;
      if (!placementsById.containsKey(fatherEdge.parentId) ||
          !placementsById.containsKey(motherEdge.parentId)) {
        continue;
      }
      final mothers = mothersByFather.putIfAbsent(
        fatherEdge.parentId,
        () => <String>[],
      );
      if (!mothers.contains(motherEdge.parentId)) {
        mothers.add(motherEdge.parentId);
      }
    }
    for (final mothers in mothersByFather.values) {
      mothers.sort((a, b) => _comparePeople(persons[a]!, persons[b]!));
    }

    final groups = <String, _UnionGroup>{};
    for (final entry in edgesByChild.entries) {
      final child = placementsById[entry.key];
      if (child == null) continue;

      TreePersonPlacement? father;
      TreePersonPlacement? mother;
      TreePersonPlacement? fallback;
      for (final edge in entry.value) {
        final parent = placementsById[edge.parentId];
        if (parent == null || parent.generation >= child.generation) continue;
        fallback ??= parent;
        if (edge.parentRole == 'father') {
          father ??= parent;
        } else if (edge.parentRole == 'mother') {
          mother ??= parent;
        }
      }
      final anchor = father ?? mother ?? fallback;
      if (anchor == null) continue;

      var wifeIndex = -1;
      if (father != null && mother != null) {
        final mothers = mothersByFather[father.person.id] ?? const <String>[];
        final index = mothers.indexOf(mother.person.id);
        if (index >= 0) wifeIndex = index;
      }
      final key = father != null
          ? '${father.person.id}|${mother?.person.id ?? 'single'}'
          : '${anchor.person.id}|single';
      final group = groups.putIfAbsent(
        key,
        () => _UnionGroup(anchor: anchor, wifeIndex: wifeIndex),
      );
      if (!group.children.any((item) => item.person.id == child.person.id)) {
        group.children.add(child);
      }
    }

    final groupsByAnchor = <String, List<_UnionGroup>>{};
    for (final group in groups.values) {
      groupsByAnchor.putIfAbsent(group.anchor.person.id, () => []).add(group);
    }
    for (final anchorGroups in groupsByAnchor.values) {
      anchorGroups.sort((a, b) => a.wifeIndex.compareTo(b.wifeIndex));
      final anchor = anchorGroups.first.anchor;
      final wifeCount = mothersByFather[anchor.person.id]?.length ?? 1;
      for (var groupIndex = 0; groupIndex < anchorGroups.length; groupIndex++) {
        final group = anchorGroups[groupIndex];
        final children = group.children
          ..sort((a, b) => a.center.dx.compareTo(b.center.dx));
        if (children.isEmpty) continue;
        final anchorX = wifeCount > 1 && group.wifeIndex >= 0
            ? anchor.rect.left +
                  anchor.rect.width * (group.wifeIndex + 1) / (wifeCount + 1)
            : anchor.center.dx;
        final startY = anchor.rect.bottom;
        final childTop = children.first.rect.top;
        final distance = math.max(20.0, childTop - startY);
        final stagger = anchorGroups.length > 1
            ? (groupIndex - (anchorGroups.length - 1) / 2) * 10.0
            : 0.0;
        final midY = (startY + distance * 0.46 + stagger)
            .clamp(startY + 8, childTop - 8)
            .toDouble();
        unions.add(Offset(anchorX, startY));
        for (var index = 0; index < children.length; index++) {
          final child = children[index];
          final childX = child.center.dx;
          final path = <Offset>[
            Offset(anchorX, startY),
            Offset(anchorX, midY),
            Offset(childX, midY),
            Offset(childX, child.rect.top),
          ];
          edges.add(TreeEdge(points: path, colorSlot: index));
          branches.add(Offset(childX, midY));
        }
      }
    }

    return _TreeGeometry(
      edges: List.unmodifiable(edges),
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

class _UnionGroup {
  _UnionGroup({required this.anchor, required this.wifeIndex});

  final TreePersonPlacement anchor;
  final int wifeIndex;
  final List<TreePersonPlacement> children = [];
}

class _TreeGeometry {
  const _TreeGeometry({
    required this.edges,
    required this.unions,
    required this.branches,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final List<TreeEdge> edges;
  final List<Offset> unions;
  final List<Offset> branches;
  final double canvasWidth;
  final double canvasHeight;
}
