import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../data/demo_data.dart';
import '../../models/family_member.dart';
import '../../services/app_session.dart';
import '../person/person_detail_page.dart';
import '../search/member_search_page.dart';

class TreePage extends StatefulWidget {
  const TreePage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage>
    with SingleTickerProviderStateMixin {
  static const double _canvasWidth = 800;
  static const double _canvasHeight = 1010;
  static const double _detailReserve = 154;

  // A couple is laid out side by side. The child line starts from the centre
  // of the small marriage bridge between the two cards and drops straight to
  // the next generation. The direct bloodline therefore steps to the right by
  // one spouse width per generation, which keeps the actual relationship
  // unambiguous instead of drawing a line out of one person's card.
  static const List<_TreePlacement> _placements = [
    _TreePlacement(
      id: 'person_zhang_tianming',
      left: 130,
      top: 40,
      width: 140,
      height: 82,
      generation: 6,
      compact: false,
    ),
    _TreePlacement(
      id: 'person_lin_shi',
      left: 290,
      top: 40,
      width: 140,
      height: 82,
      generation: 6,
      compact: false,
    ),
    _TreePlacement(
      id: 'person_zhang_hongyuan',
      left: 210,
      top: 245,
      width: 140,
      height: 82,
      generation: 7,
      compact: false,
    ),
    _TreePlacement(
      id: 'person_su_shi',
      left: 370,
      top: 245,
      width: 140,
      height: 82,
      generation: 7,
      compact: false,
    ),
    _TreePlacement(
      id: 'person_zhang_yi',
      left: 290,
      top: 465,
      width: 140,
      height: 82,
      generation: 8,
      compact: false,
    ),
    _TreePlacement(
      id: 'person_yu_meng',
      left: 450,
      top: 465,
      width: 140,
      height: 82,
      generation: 8,
      compact: false,
    ),
    _TreePlacement(
      id: 'person_zhang_xu',
      left: 206,
      top: 635,
      width: 84,
      height: 126,
      generation: 9,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_yao',
      left: 302,
      top: 635,
      width: 84,
      height: 126,
      generation: 9,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_lang',
      left: 398,
      top: 635,
      width: 84,
      height: 126,
      generation: 9,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_xue',
      left: 494,
      top: 635,
      width: 84,
      height: 126,
      generation: 9,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_xuan',
      left: 590,
      top: 635,
      width: 84,
      height: 126,
      generation: 9,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_xiaohu',
      left: 254,
      top: 840,
      width: 84,
      height: 126,
      generation: 10,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_xiaoyu',
      left: 350,
      top: 840,
      width: 84,
      height: 126,
      generation: 10,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_xiaoyue',
      left: 542,
      top: 840,
      width: 84,
      height: 126,
      generation: 10,
      compact: true,
    ),
    _TreePlacement(
      id: 'person_zhang_xiaoyu_junior',
      left: 638,
      top: 840,
      width: 84,
      height: 126,
      generation: 10,
      compact: true,
    ),
  ];

  static const List<List<Offset>> _edges = [
    // 张天明 + 林氏 → 张宏远
    [Offset(280, 81), Offset(280, 245)],
    // 张宏远 + 苏氏 → 张一
    [Offset(360, 286), Offset(360, 465)],
    // 张一 + 余梦 → five children
    [Offset(440, 506), Offset(440, 595)],
    [Offset(248, 595), Offset(632, 595)],
    [Offset(248, 595), Offset(248, 635)],
    [Offset(344, 595), Offset(344, 635)],
    [Offset(440, 595), Offset(440, 635)],
    [Offset(536, 595), Offset(536, 635)],
    [Offset(632, 595), Offset(632, 635)],
    // Grandchildren under 张瑶
    [Offset(344, 761), Offset(344, 800)],
    [Offset(296, 800), Offset(392, 800)],
    [Offset(296, 800), Offset(296, 840)],
    [Offset(392, 800), Offset(392, 840)],
    // Grandchildren under 张轩
    [Offset(632, 761), Offset(632, 800)],
    [Offset(584, 800), Offset(680, 800)],
    [Offset(584, 800), Offset(584, 840)],
    [Offset(680, 800), Offset(680, 840)],
  ];

  /// Short bridges inside the gap between each husband and wife.
  static const List<(Offset, Offset)> _marriageBridges = [
    (Offset(270, 81), Offset(290, 81)),
    (Offset(350, 286), Offset(370, 286)),
    (Offset(430, 506), Offset(450, 506)),
  ];

  /// A tiny junction where the marriage bridge meets the descent line.
  static const List<Offset> _unionNodes = [
    Offset(280, 81),
    Offset(360, 286),
    Offset(440, 506),
  ];

  /// Branch junctions on the sibling buses.
  static const List<Offset> _branchNodes = [
    Offset(440, 595),
    Offset(344, 800),
    Offset(632, 800),
  ];

  static const List<(int, double)> _generationLabels = [
    (6, 81),
    (7, 286),
    (8, 506),
    (9, 698),
    (10, 903),
  ];

  /// Horizontal and vertical centers used when a generation is focused.
  static const Map<int, Offset> _generationFocusPoints = {
    6: Offset(280, 81),
    7: Offset(360, 286),
    8: Offset(440, 506),
    9: Offset(440, 698),
    10: Offset(488, 903),
  };

  final TransformationController _transformation = TransformationController();
  late final AnimationController _zoomController;
  Animation<Matrix4>? _zoomAnimation;

  String? _selectedId;
  int? _focusGeneration;
  Size _viewportSize = Size.zero;
  bool _fitScheduled = false;
  Map<String, FamilyMember> _membersByPlacement = const {};

  FamilyMember? get _selected =>
      _selectedId == null ? null : _membersByPlacement[_selectedId];

  /// The tree artwork still uses the prototype's fixed geometry. Resolve each
  /// fixture placement against the live family data by display name until the
  /// relationship layout engine replaces the static coordinates.
  Map<String, FamilyMember> _membersFrom(List<FamilyMember> members) {
    final byName = {for (final member in members) member.name: member};
    final result = <String, FamilyMember>{};
    for (final placement in _placements) {
      final fixture = DemoData.memberById(placement.id);
      if (fixture == null) continue;
      final live = byName[fixture.name];
      if (live != null) result[placement.id] = live;
    }
    return result;
  }

  void _clearSelection() {
    if (_selectedId == null) return;
    setState(() => _selectedId = null);
  }

  @override
  void initState() {
    super.initState();
    _zoomController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _zoomAnimation;
          if (animation != null) {
            _transformation.value = animation.value;
          }
        });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final session = SessionScope.of(context);
    _membersByPlacement = _membersFrom(session.treeMembers);
    final selected = _selected;
    final activeGeneration =
        selected?.generation ?? DemoData.currentUser.generation;
    final familyName = session.family?.name ?? DemoData.family.name;
    final memberCount =
        session.family?.memberCount ?? DemoData.family.memberCount;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _clearSelection,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: topInset + 6),
              color: const Color(0xFFF7F9F9),
              child: Column(
                children: [
                  _TreeHeader(
                    subtitle:
                        '$familyName · ${FamilyMember.generationLabelFor(activeGeneration)} · 共 $memberCount 人',
                    onBack: widget.onBack,
                    onSearch: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MemberSearchPage(),
                      ),
                    ),
                    onDirectory: () => _showDirectory(context),
                  ),
                  _GenerationFilters(
                    selected: _focusGeneration,
                    onChanged: _handleFilterChanged,
                    onMore: () => _showDirectory(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Color(0xFFF7F7F2)),
                      child: Image.asset(
                        'assets/images/tree_paper.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFFBFBF7).withValues(alpha: 0.22),
                            Colors.transparent,
                            AppColors.background.withValues(alpha: 0.60),
                          ],
                          stops: const [0, 0.78, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        _maybeScheduleFit(size);
                        return ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformation,
                            constrained: false,
                            boundaryMargin: const EdgeInsets.all(140),
                            minScale: 0.30,
                            maxScale: 2.0,
                            clipBehavior: Clip.none,
                            alignment: Alignment.topLeft,
                            onInteractionStart: (_) => _zoomController.stop(),
                            child: SizedBox(
                              width: _canvasWidth,
                              height: _canvasHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _TreeLinesPainter(
                                        edges: _edges,
                                        marriageBridges: _marriageBridges,
                                        unionNodes: _unionNodes,
                                        branchNodes: _branchNodes,
                                      ),
                                    ),
                                  ),
                                  _GenerationRail(
                                    selectedGeneration: activeGeneration,
                                    focusGeneration: _focusGeneration,
                                    labels: _generationLabels,
                                  ),
                                  for (final placement in _placements)
                                    _buildNode(placement),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _ZoomControls(
                      onZoomIn: () => _zoomBy(1.22),
                      onZoomOut: () => _zoomBy(1 / 1.22),
                      onReset: _resetView,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 10,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        final offset =
                            Tween<Offset>(
                              begin: const Offset(0, 0.045),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: selected == null
                          ? const SizedBox.shrink(
                              key: ValueKey('tree-summary-hidden'),
                            )
                          : _PersonSummaryCard(
                              key: ValueKey(selected.id),
                              person: selected,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PersonDetailPage(person: selected),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(_TreePlacement placement) {
    final member = _membersByPlacement[placement.id];
    if (member == null) return const SizedBox.shrink();
    final dimmed =
        _focusGeneration != null && member.generation != _focusGeneration;
    return Positioned(
      left: placement.left,
      top: placement.top,
      width: placement.width,
      height: placement.height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: dimmed ? 0.28 : 1,
        child: _PersonNode(
          person: member,
          selected: _selectedId == placement.id,
          compact: placement.compact,
          generation: placement.generation,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedId = placement.id);
          },
        ),
      ),
    );
  }

  void _maybeScheduleFit(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
    if (_fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (!mounted || _viewportSize.isEmpty) return;
      _applyFit(animate: false);
    });
  }

  void _applyFit({required bool animate}) {
    final usableWidth = math.max(120.0, _viewportSize.width - 18);
    final usableHeight = math.max(
      180.0,
      _viewportSize.height - _detailReserve - 16,
    );
    final scale = math
        .min(usableWidth / _canvasWidth, usableHeight / _canvasHeight)
        .clamp(0.30, 0.90);
    final dx = (_viewportSize.width - _canvasWidth * scale) / 2;
    final target = Matrix4.identity()
      ..translateByDouble(dx, 8.0, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    if (animate) {
      _animateTo(target);
    } else {
      _transformation.value = target;
    }
  }

  void _handleFilterChanged(int? generation) {
    setState(() {
      _focusGeneration = generation;
      _selectedId = null;
    });

    if (generation == null) {
      _applyFit(animate: true);
      return;
    }

    final focus = _generationFocusPoints[generation];
    if (focus == null || _viewportSize.isEmpty) return;

    const scale = 0.74;
    final targetY = _viewportSize.height * 0.32;
    final targetX = _viewportSize.width / 2;
    final matrix = Matrix4.identity()
      ..translateByDouble(
        targetX - focus.dx * scale,
        targetY - focus.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
    _animateTo(matrix);
  }

  void _resetView() {
    _applyFit(animate: true);
  }

  void _zoomBy(double factor) {
    final current = _transformation.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.30, 2.0);
    if ((target - current).abs() < 0.001) return;
    final focal = Offset(_viewportSize.width / 2, _viewportSize.height * 0.42);
    final scene = _transformation.toScene(focal);
    final matrix = Matrix4.identity()
      ..translateByDouble(
        focal.dx - scene.dx * target,
        focal.dy - scene.dy * target,
        0,
        1,
      )
      ..scaleByDouble(target, target, target, 1);
    _animateTo(matrix);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation =
        Matrix4Tween(begin: _transformation.value.clone(), end: target).animate(
          CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
        );
    _zoomController.forward(from: 0);
  }

  void _showDirectory(BuildContext context) {
    final generations = [6, 7, 8, 9, 10];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.paddingOf(context).bottom + 18,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Text('世代目录', style: AppTheme.serif(fontSize: 21)),
                const Spacer(),
                Text(
                  '共 ${_membersByPlacement.length} 位在世系节点',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              '选择世代可聚焦族谱中的相应分支',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            for (final generation in generations)
              _DirectoryRow(
                generation: generation,
                members: _membersByPlacement.values
                    .where((member) => member.generation == generation)
                    .toList(),
                selected: _focusGeneration == generation,
                onTap: () {
                  final next = _focusGeneration == generation
                      ? null
                      : generation;
                  Navigator.pop(context);
                  _handleFilterChanged(next);
                },
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleFilterChanged(null);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.line),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('显示全部世代', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreePlacement {
  const _TreePlacement({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.generation,
    required this.compact,
  });

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
  final int generation;
  final bool compact;
}

class _TreeHeader extends StatelessWidget {
  const _TreeHeader({
    required this.subtitle,
    required this.onBack,
    required this.onSearch,
    required this.onDirectory,
  });

  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onDirectory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 5),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack,
            size: 38,
            backgroundColor: Colors.white,
            iconColor: AppColors.ink,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('族谱树', style: AppTheme.serif(fontSize: 22)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          RoundIconButton(
            icon: Icons.search_rounded,
            onTap: onSearch,
            size: 38,
            backgroundColor: Colors.transparent,
          ),
          RoundIconButton(
            icon: Icons.format_list_bulleted_rounded,
            onTap: onDirectory,
            size: 38,
            backgroundColor: Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _GenerationFilters extends StatelessWidget {
  const _GenerationFilters({
    required this.selected,
    required this.onChanged,
    required this.onMore,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const filters = <(String, int?)>[
      ('全部', null),
      ('第六世', 6),
      ('第七世', 7),
      ('第八世', 8),
      ('第九世', 9),
      ('第十世', 10),
    ];
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 8, 2, 8),
              children: [
                for (final filter in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Material(
                      color: selected == filter.$2
                          ? const Color(0xFFECF1FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      child: InkWell(
                        onTap: () => onChanged(filter.$2),
                        borderRadius: BorderRadius.circular(19),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: selected == filter.$2
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.line,
                            ),
                          ),
                          child: Text(
                            filter.$1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected == filter.$2
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected == filter.$2
                                  ? AppColors.primary
                                  : AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onMore,
                borderRadius: BorderRadius.circular(16),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeLinesPainter extends CustomPainter {
  _TreeLinesPainter({
    required this.edges,
    required this.marriageBridges,
    required this.unionNodes,
    required this.branchNodes,
  });

  final List<List<Offset>> edges;
  final List<(Offset, Offset)> marriageBridges;
  final List<Offset> unionNodes;
  final List<Offset> branchNodes;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF829BA1).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bridgePaint = Paint()
      ..color = const Color(0xFFAE9673).withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawPolyline(List<Offset> edge, Paint paint) {
      final path = Path()..moveTo(edge.first.dx, edge.first.dy);
      for (var i = 1; i < edge.length; i++) {
        path.lineTo(edge[i].dx, edge[i].dy);
      }
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }

    for (final edge in edges) {
      drawPolyline(edge, linePaint);
    }

    // A short bridge joins the two cards; the child line starts exactly at its
    // centre. This makes the relationship read as a couple, never as a line
    // drawn from only one parent.
    for (final bridge in marriageBridges) {
      drawPolyline([bridge.$1, bridge.$2], bridgePaint);
    }

    final unionFill = Paint()..color = const Color(0xFFFFFEFA);
    final unionStroke = Paint()
      ..color = const Color(0xFFB09875).withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final point in unionNodes) {
      canvas.drawCircle(point, 3.6, unionFill);
      canvas.drawCircle(point, 3.6, unionStroke);
    }

    final branchPaint = Paint()
      ..color = const Color(0xFF9FB0B3).withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;
    for (final point in branchNodes) {
      canvas.drawCircle(point, 2.2, branchPaint);
    }
  }

  @override
  bool shouldRepaint(_TreeLinesPainter oldDelegate) =>
      oldDelegate.edges != edges ||
      oldDelegate.marriageBridges != marriageBridges ||
      oldDelegate.unionNodes != unionNodes ||
      oldDelegate.branchNodes != branchNodes;
}

class _GenerationRail extends StatelessWidget {
  const _GenerationRail({
    required this.selectedGeneration,
    required this.focusGeneration,
    required this.labels,
  });

  final int selectedGeneration;
  final int? focusGeneration;
  final List<(int, double)> labels;

  @override
  Widget build(BuildContext context) {
    final firstY = labels.first.$2;
    final lastY = labels.last.$2;
    return Positioned(
      left: 4,
      top: 0,
      bottom: 0,
      width: 62,
      child: Stack(
        children: [
          Positioned(
            left: 3,
            top: firstY,
            height: lastY - firstY,
            child: Container(
              width: 1,
              color: AppColors.inkMuted.withValues(alpha: 0.24),
            ),
          ),
          for (final label in labels)
            Positioned(
              left: 0,
              top: label.$2 - 7,
              child: _GenerationLabel(
                generation: label.$1,
                active:
                    focusGeneration == label.$1 ||
                    (focusGeneration == null && selectedGeneration == label.$1),
                dimmed: focusGeneration != null && focusGeneration != label.$1,
              ),
            ),
        ],
      ),
    );
  }
}

class _GenerationLabel extends StatelessWidget {
  const _GenerationLabel({
    required this.generation,
    required this.active,
    required this.dimmed,
  });

  final int generation;
  final bool active;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final label = FamilyMember.generationLabelFor(generation);
    final color = active
        ? AppColors.primary
        : dimmed
        ? AppColors.inkMuted.withValues(alpha: 0.30)
        : AppColors.inkSoft.withValues(alpha: 0.78);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.6 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: active ? 7 : 5,
            height: active ? 7 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : const Color(0xFFD5DEDF),
              border: Border.all(
                color: active ? Colors.white : const Color(0xFFE1E7E8),
                width: 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.1,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonNode extends StatelessWidget {
  const _PersonNode({
    required this.person,
    required this.selected,
    required this.compact,
    required this.generation,
    required this.onTap,
  });

  final FamilyMember person;
  final bool selected;
  final bool compact;
  final int generation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${person.name}，${person.generationLabel}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: compact
              ? const EdgeInsets.fromLTRB(5, 5, 5, 5)
              : const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFA),
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE7ECEC),
              width: selected ? 1.5 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.20)
                    : const Color(0xFF39545C).withValues(alpha: 0.07),
                blurRadius: selected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: compact
              ? _CompactNodeContent(person: person, selected: selected)
              : _WideNodeContent(person: person, selected: selected),
        ),
      ),
    );
  }
}

class _WideNodeContent extends StatelessWidget {
  const _WideNodeContent({required this.person, required this.selected});

  final FamilyMember person;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PortraitWithDot(person: person, width: 42, height: 60, radius: 9),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '(${person.lifespan})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: person.relation == '配偶'
                      ? AppColors.roseSoft
                      : const Color(0xFFF3F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  person.relation == '配偶' ? '配偶' : person.generationLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    height: 1.1,
                    color: person.relation == '配偶'
                        ? AppColors.rose
                        : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (selected)
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }
}

class _CompactNodeContent extends StatelessWidget {
  const _CompactNodeContent({required this.person, required this.selected});

  final FamilyMember person;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PortraitWithDot(person: person, width: 50, height: 55, radius: 8),
        const SizedBox(height: 4),
        Text(
          person.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '(${person.lifespan})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 8,
            height: 1.1,
            color: AppColors.inkMuted,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : const Color(0xFFF4F5F4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            person.generationLabel,
            style: TextStyle(
              fontSize: 8,
              height: 1.1,
              color: selected ? AppColors.primary : AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitWithDot extends StatelessWidget {
  const _PortraitWithDot({
    required this.person,
    required this.width,
    required this.height,
    required this.radius,
  });

  final FamilyMember person;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkPortrait(
          person: person,
          width: width,
          height: height,
          radius: radius,
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: person.isFemale ? AppColors.rose : AppColors.primary,
              border: Border.all(color: Colors.white, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C20323B),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(icon: Icons.add_rounded, onTap: onZoomIn),
          Container(width: 22, height: 1, color: AppColors.line),
          _ZoomButton(icon: Icons.remove_rounded, onTap: onZoomOut),
          Container(width: 22, height: 1, color: AppColors.line),
          _ZoomButton(icon: Icons.center_focus_strong_rounded, onTap: onReset),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 35,
        height: 35,
        child: Icon(icon, size: 18, color: AppColors.inkSoft),
      ),
    );
  }
}

class _PersonSummaryCard extends StatelessWidget {
  const _PersonSummaryCard({
    super.key,
    required this.person,
    required this.onTap,
  });

  final FamilyMember person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1526333A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkPortrait(
                person: person,
                width: 66,
                height: 78,
                radius: 14,
                showBorder: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.serif(
                              fontSize: 20,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            person.generationLabel,
                            style: const TextStyle(
                              fontSize: 8,
                              height: 1.1,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE4E9EA)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '查看详情',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 13,
                                color: AppColors.inkMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '出生：${person.birthYear ?? '未记录'}年    ${person.ageLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '籍贯：${person.birthPlace ?? '未记录'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      person.biography ?? '暂无生平记录',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1.45,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.generation,
    required this.members,
    required this.selected,
    required this.onTap,
  });

  final int generation;
  final List<FamilyMember> members;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = FamilyMember.generationLabelFor(generation);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : const Color(0xFFF5F7F8),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$generation',
                style: TextStyle(
                  fontFamily: AppTheme.serifFamily,
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    members.map((member) => member.name).take(4).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${members.length} 人',
              style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
            ),
            const SizedBox(width: 3),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              size: selected ? 17 : 18,
              color: selected ? AppColors.primary : AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
