import { Lunar, Solar, SolarUtil } from 'lunar-typescript';
import type { PartialDate } from '@/types/api';

export interface DualCalendarDate {
  /** The date in the calendar in which it was recorded. */
  primary: string;
  /** The same date rendered in the other calendar, when it can be derived. */
  secondary: string;
  lunar: string;
  solar: string;
  ganzhiYear: string;
  zodiac: string;
}

function pad(value: number): string {
  return String(value).padStart(2, '0');
}

function solarLabel(year: number, month: number, day: number): string {
  return `公历 ${year}.${pad(month)}.${pad(day)}`;
}

function lunarLabel(lunar: Lunar): string {
  return `农历 ${lunar.getYearInGanZhi()}年${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}`;
}

/**
 * Return both the recorded calendar and the other calendar for a partial
 * person date. Dates are optional in the archive, so year-only and
 * month-only values degrade to a readable partial date instead of guessing.
 */
export function dualCalendarDate(date?: PartialDate | null): DualCalendarDate | null {
  if (!date) return null;
  if (date.text && !date.year) {
    return {
      primary: date.text,
      secondary: '',
      lunar: date.calendar === 'lunar' ? date.text : '',
      solar: date.calendar !== 'lunar' ? date.text : '',
      ganzhiYear: '',
      zodiac: '',
    };
  }
  if (!date.year) return null;

  const { year, month, day } = date;
  const isLunar = date.calendar === 'lunar';
  const hasFullDate = Boolean(month && day);

  if (!hasFullDate) {
    const lunar = isLunar ? safeLunarYear(year) : safeSolarYear(year);
    const monthPart = month
      ? `${date.isLeapMonth ? '闰' : ''}${month}月`
      : '';
    const recorded = isLunar
      ? `农历 ${year}年${monthPart}`
      : `公历 ${year}年${monthPart}`;
    return {
      primary: date.text || recorded,
      secondary: '',
      lunar: isLunar ? recorded : '',
      solar: isLunar ? '' : recorded,
      ganzhiYear: lunar ? `${lunar.getYearInGanZhi()}年` : '',
      zodiac: lunar?.getYearShengXiao() ?? '',
    };
  }

  try {
    if (isLunar) {
      const lunar = Lunar.fromYmd(year, date.isLeapMonth ? -month! : month!, day!);
      const solar = lunar.getSolar();
      return {
        primary: lunarLabel(lunar),
        secondary: solarLabel(solar.getYear(), solar.getMonth(), solar.getDay()),
        lunar: lunarLabel(lunar),
        solar: solarLabel(solar.getYear(), solar.getMonth(), solar.getDay()),
        ganzhiYear: `${lunar.getYearInGanZhi()}年`,
        zodiac: lunar.getYearShengXiao(),
      };
    }

    if (month! < 1 || month! > 12 || day! < 1 || day! > SolarUtil.getDaysOfMonth(year, month!)) {
      throw new Error('invalid solar date');
    }
    const solar = Solar.fromYmd(year, month!, day!);
    const lunar = solar.getLunar();
    return {
      primary: solarLabel(year, month!, day!),
      secondary: lunarLabel(lunar),
      lunar: lunarLabel(lunar),
      solar: solarLabel(year, month!, day!),
      ganzhiYear: `${lunar.getYearInGanZhi()}年`,
      zodiac: lunar.getYearShengXiao(),
    };
  } catch {
    // Invalid or out-of-range historical dates still deserve a readable line.
    const recorded = isLunar
      ? `农历 ${year}年${date.isLeapMonth ? '闰' : ''}${month}月${day}日`
      : `公历 ${year}.${pad(month!)}.${pad(day!)}`;
    return {
      primary: date.text || recorded,
      secondary: '',
      lunar: isLunar ? recorded : '',
      solar: isLunar ? '' : recorded,
      ganzhiYear: '',
      zodiac: '',
    };
  }
}

function safeLunarYear(year: number): Lunar | null {
  try {
    return Lunar.fromYmd(year, 1, 1);
  } catch {
    return null;
  }
}

function safeSolarYear(year: number): Lunar | null {
  try {
    return Solar.fromYmd(year, 6, 1).getLunar();
  } catch {
    return null;
  }
}
