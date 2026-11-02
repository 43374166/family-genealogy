import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../models/family_member.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../family/bind_person_page.dart';
import '../person/api_person_detail_page.dart';
import '../search/member_search_page.dart';
import 'tree_layout.dart';

class TreePage extends StatefulWidget {
  const TreePage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TreePage> createState() => TreePageState();
}

class TreePageState extends State<TreePage>
    with SingleTickerProviderStateMixin {
  static const double _detailReserve = 154;
  final TransformationController _transformation = TransformationController();
  late final AnimationController _zoomController;
  Animation<Matrix4>? _zoomAnimation;

  String? _selectedId;
  int? _focusGeneration;
  Size _viewportSize = Size.zero;
  bool _fitScheduled = false;
  TreeLayout? _layout;
  Map<String, FamilyMember> _membersById = const {};
  String? _treeFamilyId;
  bool _didInitialFocus = false;
  bool _initialFocusScheduled = false;

  FamilyMember? get _selected =>
      _selectedId == null ? null : _membersById[_selectedId];

  /// Called by the shell the first time the tree tab is opened. Re-running it
  /// on every tab switch would fight the user's saved filter/selection.
  void focusSelfOnFirstEntry() {
    if (!mounted) return;
    _didInitialFocus = true;
    _focusSelf(silent: true, animate: false);
  }

  void _clearSelection() {
    if (_selectedId == null) return;
    setState(() => _selectedId = null);
  }

  Future<void> _refreshTree() async {
    try {
      await SessionScope.of(context).refreshTree();
      if (!mounted) return;
      setState(() {
        _selectedId = null;
        _focusGeneration = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('族谱数据已刷新')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final familyId = SessionScope.of(context).tree?.familyId;
    if (familyId == _treeFamilyId) return;
    _treeFamilyId = familyId;
    _didInitialFocus = false;
    _selectedId = null;
    _focusGeneration = null;
    _scheduleInitialFocus();
  }

  void _scheduleInitialFocus() {
    if (_initialFocusScheduled) return;
    _initialFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialFocusScheduled = false;
      if (!mounted || _layout == null || _viewportSize.isEmpty) return;
      if (_didInitialFocus) return;
      _didInitialFocus = true;
      _focusSelf(silent: true, animate: false);
    });
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
    final layout = TreeLayout.fromTree(session.tree);
    _layout = layout;
    _membersById = {
      for (final member in session.treeMembers) member.id: member,
    };
    final selected = _selected;
    final familyName = session.family?.name ?? '当前家庭';
    final memberCount = session.family?.memberCount ?? layout?.personCount ?? 0;

    if (layout == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TreeHeader(
                subtitle: session.error ?? '族谱数据尚未载入',
                onBack: widget.onBack,
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MemberSearchPage(),
                  ),
                ),
                onDirectory: () {},
                onSelf: _focusSelf,
                onRefresh: _refreshTree,
              ),
              const Expanded(child: _TreeEmpty()),
            ],
          ),
        ),
      );
    }

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
                        '$familyName · ${layout.generations.length} 代 · 共 $memberCount 人',
                    onBack: widget.onBack,
                    onSearch: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MemberSearchPage(),
                      ),
                    ),
                    onDirectory: () => _showDirectory(context),
                    onSelf: _focusSelf,
                    onRefresh: _refreshTree,
                  ),
                  _GenerationFilters(
                    generations: layout.generations,
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
                            minScale: 0.16,
                            maxScale: 2.0,
                            clipBehavior: Clip.none,
                            alignment: Alignment.topLeft,
                            onInteractionStart: (_) => _zoomController.stop(),
                            child: SizedBox(
                              width: layout.width,
                              height: layout.height,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _TreeLinesPainter(
                                        edges: layout.edges,
                                        marriageBridges: layout.marriageBridges,
                                        unionNodes: layout.unionNodes,
                                        branchNodes: layout.branchNodes,
                                      ),
                                    ),
                                  ),
                                  _GenerationRail(
                                    selectedGeneration:
                                        selected?.generation ?? -1,
                                    focusGeneration: _focusGeneration,
                                    labels: layout.generationLabels,
                                  ),
                                  for (final placement in layout.placements)
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
                    bottom: selected == null ? 16 : 170,
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
                                  builder: (_) => ApiPersonDetailPage(
                                    personId: selected.id,
                                    initialPerson: _apiPersonFor(selected.id),
                                  ),
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

  ApiPerson? _apiPersonFor(String personId) {
    final tree = SessionScope.of(context).tree;
    if (tree == null) return null;
    for (final person in tree.persons) {
      if (person.id == personId) return person;
    }
    return null;
  }

  Widget _buildNode(TreePersonPlacement placement) {
    final member = _membersById[placement.person.id];
    if (member == null) return const SizedBox.shrink();
    final dimmed =
        _focusGeneration != null && member.generation != _focusGeneration;
    final isSelf =
        SessionScope.of(context).membership?.personId == placement.person.id;
    return Positioned.fromRect(
      rect: placement.rect,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: dimmed ? 0.28 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _PersonNode(
              person: member,
              selected: _selectedId == placement.person.id,
              compact: placement.compact,
              generation: placement.generation,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedId = placement.person.id);
              },
            ),
            if (isSelf)
              Positioned(
                left: 2,
                top: -7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '我',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _focusSelf({bool silent = false, bool animate = true}) {
    final session = SessionScope.of(context);
    final linkedId = session.membership?.personId;
    if (linkedId == null || linkedId.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('还没有绑定“我自己”，先绑定族谱人物'),
            action: SnackBarAction(
              label: '去绑定',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BindPersonPage()),
              ),
            ),
          ),
        );
      } else {
        _applyFit(animate: animate);
      }
      return;
    }
    final layout = _layout;
    if (layout == null || _viewportSize.isEmpty) return;
    TreePersonPlacement? target;
    for (final placement in layout.placements) {
      if (placement.person.id == linkedId) {
        target = placement;
        break;
      }
    }
    if (target == null) {
      if (silent) {
        _applyFit(animate: animate);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('你的族谱档案不在当前视图中')));
      }
      return;
    }
    if (!silent) HapticFeedback.selectionClick();
    setState(() {
      _focusGeneration = null;
      _selectedId = linkedId;
    });
    final rect = target.rect;
    const scale = 1.05;
    final targetX = _viewportSize.width / 2;
    final targetY = _viewportSize.height * 0.42;
    final matrix = Matrix4.identity()
      ..translateByDouble(
        targetX - rect.center.dx * scale,
        targetY - rect.center.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
    if (animate) {
      _animateTo(matrix);
    } else {
      _transformation.value = matrix;
    }
  }

  void _maybeScheduleFit(Size size) {
    if (_viewportSize == size) return;
    _viewportSize = size;
    if (_fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (!mounted || _viewportSize.isEmpty) return;
      if (!_didInitialFocus) {
        _scheduleInitialFocus();
      } else {
        _applyFit(animate: false);
      }
    });
  }

  void _applyFit({required bool animate}) {
    final layout = _layout;
    if (layout == null) return;
    final usableWidth = math.max(120.0, _viewportSize.width - 18);
    final usableHeight = math.max(
      180.0,
      _viewportSize.height - _detailReserve - 16,
    );
    final scale = math
        .min(usableWidth / layout.width, usableHeight / layout.height)
        .clamp(0.16, 0.90);
    final dx = (_viewportSize.width - layout.width * scale) / 2;
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

    final focus = _layout?.focusPoints[generation];
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
    final target = (current * factor).clamp(0.16, 2.0);
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
    final layout = _layout;
    if (layout == null) return;
    final generations = layout.generations;
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
                  '共 ${_membersById.length} 位成员',
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
                members: _membersById.values
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

class _TreeHeader extends StatelessWidget {
  const _TreeHeader({
    required this.subtitle,
    required this.onBack,
    required this.onSearch,
    required this.onDirectory,
    required this.onSelf,
    required this.onRefresh,
  });

  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onDirectory;
  final VoidCallback onSelf;
  final VoidCallback onRefresh;

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
          TextButton.icon(
            onPressed: onSelf,
            icon: const Icon(Icons.my_location_rounded, size: 15),
            label: const Text('自己'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(width: 3),
          RoundIconButton(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
            size: 38,
            backgroundColor: Colors.transparent,
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

class _TreeEmpty extends StatelessWidget {
  const _TreeEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(
                Icons.account_tree_outlined,
                size: 34,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '族谱暂时没有可展示的成员',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              '请重新登录或从下拉刷新族谱数据',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationFilters extends StatelessWidget {
  const _GenerationFilters({
    required this.generations,
    required this.selected,
    required this.onChanged,
    required this.onMore,
  });

  final List<int> generations;
  final int? selected;
  final ValueChanged<int?> onChanged;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, int?)>[
      ('全部', null),
      for (final generation in generations)
        (FamilyMember.generationLabelFor(generation), generation),
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

  final List<TreeEdge> edges;
  final List<(Offset, Offset)> marriageBridges;
  final List<Offset> unionNodes;
  final List<Offset> branchNodes;

  static const List<Color> _edgeColors = [
    Color(0xFF3F6E9E),
    Color(0xFF3A8D70),
    Color(0xFFC08A32),
    Color(0xFFB45D5A),
    Color(0xFF7B67A8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bridgePaint = Paint()
      ..color = const Color(0xFF9A7E58).withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
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
      final color = _edgeColors[edge.colorSlot % _edgeColors.length];
      final coloredPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      drawPolyline(edge.points, coloredPaint);
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
