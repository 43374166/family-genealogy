import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';

import '../../core/lunar/lunar_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../services/api_models.dart';

enum _CalendarMode { solar, lunar }

class LunarDatePickerField extends StatelessWidget {
  const LunarDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '选择日期',
    this.allowClear = true,
  });

  final String label;
  final ApiPartialDate? value;
  final ValueChanged<ApiPartialDate?> onChanged;
  final String hint;
  final bool allowClear;

  Future<void> _pick(BuildContext context) async {
    final result = await Navigator.of(context).push<ApiPartialDate?>(
      MaterialPageRoute<ApiPartialDate?>(
        builder: (_) => LunarDatePickerPage(
          title: label,
          initial: value,
          allowClear: allowClear,
        ),
      ),
    );
    if (result != null) {
      onChanged(result.year == null ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.year != null;
    return SoftDateField(
      label: label,
      value: hasValue ? LunarDateUtils.short(value) : hint,
      secondary: hasValue ? LunarDateUtils.describe(value) : null,
      onTap: () => _pick(context),
      onClear: allowClear && hasValue ? () => onChanged(null) : null,
    );
  }
}

class SoftDateField extends StatelessWidget {
  const SoftDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.secondary,
    this.onClear,
  });

  final String label;
  final String value;
  final String? secondary;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (secondary != null && secondary!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      secondary!,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                tooltip: '清除',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.inkMuted,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class LunarDatePickerPage extends StatefulWidget {
  const LunarDatePickerPage({
    super.key,
    required this.title,
    this.initial,
    this.allowClear = true,
  });

  final String title;
  final ApiPartialDate? initial;
  final bool allowClear;

  @override
  State<LunarDatePickerPage> createState() => _LunarDatePickerPageState();
}

class _LunarDatePickerPageState extends State<LunarDatePickerPage> {
  late _CalendarMode _mode;
  late DateTime _solar;
  late int _lunarYear;
  late int _lunarMonth;
  late int _lunarDay;
  bool _leap = false;
  LunarDateInfo? _info;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mode = initial?.calendar == 'lunar'
        ? _CalendarMode.lunar
        : _CalendarMode.solar;
    if (initial?.year != null) {
      if (initial!.calendar == 'lunar') {
        _lunarYear = initial.year!;
        _lunarMonth = initial.month ?? 1;
        _lunarDay = initial.day ?? 1;
        _leap = initial.isLeapMonth;
        _solar =
            LunarDateUtils.fromLunar(
              year: _lunarYear,
              month: _lunarMonth,
              day: _lunarDay,
              isLeapMonth: _leap,
            )?.solar ??
            DateTime(initial.year!, 1, 1);
      } else if (initial.month != null && initial.day != null) {
        _solar = DateTime(initial.year!, initial.month!, initial.day!);
        final lunar = LunarDateUtils.fromSolar(_solar);
        _lunarYear = lunar?.lunarYear ?? initial.year!;
        _lunarMonth = lunar?.lunarMonth ?? 1;
        _lunarDay = lunar?.lunarDay ?? 1;
        _leap = lunar?.isLeapMonth ?? false;
      } else {
        _solar = DateTime(initial.year!, 1, 1);
        _lunarYear = initial.year!;
        _lunarMonth = 1;
        _lunarDay = 1;
      }
    } else {
      _solar = DateTime(DateTime.now().year - 30, 1, 1);
      final lunar = LunarDateUtils.fromSolar(_solar);
      _lunarYear = lunar?.lunarYear ?? 1990;
      _lunarMonth = lunar?.lunarMonth ?? 1;
      _lunarDay = lunar?.lunarDay ?? 1;
      _leap = lunar?.isLeapMonth ?? false;
    }
    _refresh();
  }

  int get _signedMonth => _leap ? -_lunarMonth : _lunarMonth;

  int get _lunarDayCount {
    try {
      final month = LunarYear.fromYear(_lunarYear).getMonth(_signedMonth);
      return month?.getDayCount() ?? 30;
    } catch (_) {
      return 30;
    }
  }

  bool get _hasLeapMonth {
    try {
      return LunarYear.fromYear(_lunarYear).getLeapMonth() == _lunarMonth;
    } catch (_) {
      return false;
    }
  }

  void _refresh() {
    if (_mode == _CalendarMode.lunar) {
      _lunarDay = _lunarDay.clamp(1, _lunarDayCount);
      _info = LunarDateUtils.fromLunar(
        year: _lunarYear,
        month: _lunarMonth,
        day: _lunarDay,
        isLeapMonth: _leap && _hasLeapMonth,
      );
      if (_info != null) _solar = _info!.solar;
    } else {
      _info = LunarDateUtils.fromSolar(_solar);
      if (_info != null) {
        _lunarYear = _info!.lunarYear;
        _lunarMonth = _info!.lunarMonth;
        _lunarDay = _info!.lunarDay;
        _leap = _info!.isLeapMonth;
      }
    }
  }

  void _setMode(_CalendarMode mode) {
    setState(() {
      _mode = mode;
      _refresh();
    });
  }

  void _save() {
    final info = _info;
    if (info == null) return;
    final date = _mode == _CalendarMode.lunar
        ? ApiPartialDate(
            year: _lunarYear,
            month: _lunarMonth,
            day: _lunarDay,
            calendar: 'lunar',
            isLeapMonth: _leap && _hasLeapMonth,
            text: info.lunarText,
          )
        : ApiPartialDate(
            year: info.solar.year,
            month: info.solar.month,
            day: info.solar.day,
            calendar: 'gregorian',
            text: info.solarText,
          );
    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(211, (index) => 1900 + index);
    final months = List<int>.generate(12, (index) => index + 1);
    final days = List<int>.generate(_lunarDayCount, (index) => index + 1);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(title: widget.title, subtitle: '公历、农历双向选择'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  SegmentedButton<_CalendarMode>(
                    segments: const [
                      ButtonSegment(
                        value: _CalendarMode.solar,
                        label: Text('公历'),
                        icon: Icon(Icons.wb_sunny_outlined, size: 17),
                      ),
                      ButtonSegment(
                        value: _CalendarMode.lunar,
                        label: Text('农历'),
                        icon: Icon(Icons.nightlight_outlined, size: 17),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) => _setMode(value.first),
                  ),
                  const SizedBox(height: 12),
                  if (_mode == _CalendarMode.solar)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: CalendarDatePicker(
                        initialDate: _solar.isAfter(DateTime.now())
                            ? DateTime.now()
                            : _solar,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        onDateChanged: (value) {
                          setState(() {
                            _solar = value;
                            _refresh();
                          });
                        },
                      ),
                    )
                  else
                    _LunarSelector(
                      years: years,
                      months: months,
                      days: days,
                      year: _lunarYear,
                      month: _lunarMonth,
                      day: _lunarDay,
                      leap: _leap,
                      hasLeapMonth: _hasLeapMonth,
                      onYear: (value) {
                        setState(() {
                          _lunarYear = value;
                          _leap = false;
                          _refresh();
                        });
                      },
                      onMonth: (value) {
                        setState(() {
                          _lunarMonth = value;
                          _leap = false;
                          _refresh();
                        });
                      },
                      onDay: (value) {
                        setState(() {
                          _lunarDay = value;
                          _refresh();
                        });
                      },
                      onLeap: (value) {
                        setState(() {
                          _leap = value;
                          _refresh();
                        });
                      },
                    ),
                  const SizedBox(height: 12),
                  if (_info != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            size: 19,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '公历 ${_info!.solarText}    ·    农历 ${_info!.lunarText}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.6,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _info == null ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('确定这个日期'),
                  ),
                  if (widget.allowClear) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const ApiPartialDate()),
                      child: const Text('清除日期'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LunarSelector extends StatelessWidget {
  const _LunarSelector({
    required this.years,
    required this.months,
    required this.days,
    required this.year,
    required this.month,
    required this.day,
    required this.leap,
    required this.hasLeapMonth,
    required this.onYear,
    required this.onMonth,
    required this.onDay,
    required this.onLeap,
  });

  final List<int> years;
  final List<int> months;
  final List<int> days;
  final int year;
  final int month;
  final int day;
  final bool leap;
  final bool hasLeapMonth;
  final ValueChanged<int> onYear;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onDay;
  final ValueChanged<bool> onLeap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _row(
            label: '农历年',
            child: DropdownButton<int>(
              value: year,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: years
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value 年')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onYear(value);
              },
            ),
          ),
          const Divider(height: 1),
          _row(
            label: '月份',
            child: DropdownButton<int>(
              value: month,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: months
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        '${leap && value == month ? '闰' : ''}$value 月',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onMonth(value);
              },
            ),
          ),
          if (hasLeapMonth)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: leap,
              onChanged: (value) => onLeap(value ?? false),
              title: Text('闰$month月', style: const TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const Divider(height: 1),
          _row(
            label: '日期',
            child: DropdownButton<int>(
              value: day,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: days
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value 日')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onDay(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({required String label, required Widget child}) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
