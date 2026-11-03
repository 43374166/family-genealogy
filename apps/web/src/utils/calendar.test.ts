import { describe, expect, it } from 'vitest';
import { dualCalendarDate } from './calendar';

describe('dualCalendarDate', () => {
  it('renders both calendars for a Gregorian date', () => {
    const date = dualCalendarDate({
      year: 2014,
      month: 1,
      day: 31,
      calendar: 'gregorian',
    });
    expect(date?.primary).toBe('公历 2014.01.31');
    expect(date?.secondary).toBe('农历 甲午年正月初一');
    expect(date?.ganzhiYear).toBe('甲午年');
    expect(date?.zodiac).toBe('马');
  });

  it('renders both calendars for a lunar date, including the zodiac year', () => {
    const date = dualCalendarDate({
      year: 2014,
      month: 1,
      day: 1,
      calendar: 'lunar',
    });
    expect(date?.primary).toBe('农历 甲午年正月初一');
    expect(date?.secondary).toBe('公历 2014.01.31');
    expect(date?.ganzhiYear).toBe('甲午年');
    expect(date?.zodiac).toBe('马');
  });

  it('handles leap lunar months', () => {
    const date = dualCalendarDate({
      year: 2020,
      month: 4,
      day: 1,
      calendar: 'lunar',
      isLeapMonth: true,
    });
    expect(date?.primary).toContain('闰四月');
    expect(date?.secondary).toBe('公历 2020.05.23');
  });

  it('degrades to a year-only lunar label with ganzhi and zodiac', () => {
    const date = dualCalendarDate({ year: 1954, calendar: 'lunar' });
    expect(date?.primary).toBe('农历 1954年');
    expect(date?.ganzhiYear).toBe('甲午年');
    expect(date?.zodiac).toBe('马');
  });

  it('does not throw on an invalid full date', () => {
    const date = dualCalendarDate({
      year: 2014,
      month: 2,
      day: 30,
      calendar: 'gregorian',
    });
    expect(date?.primary).toContain('2014');
    expect(date?.secondary).toBe('');
  });
});
