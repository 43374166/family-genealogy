package store

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
	lunar "github.com/6tail/lunar-go/calendar"
)

type anniversaryDate struct {
	year, month, day int
	calendar         string
	leap             bool
}

func (s *Store) UpcomingAnniversaries(
	ctx context.Context, familyID string, days int, now time.Time,
) ([]model.Anniversary, error) {
	if days < 1 || days > 366 {
		days = 60
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, full_name, life_status,
		       birth_year, birth_month, birth_day, birth_calendar, birth_is_leap_month,
		       death_year, death_month, death_day, death_calendar, death_is_leap_month
		FROM persons
		WHERE family_id = ? AND status = 'active'`, familyID)
	if err != nil {
		return nil, fmt.Errorf("list anniversary persons: %w", err)
	}
	defer rows.Close()

	items := make([]model.Anniversary, 0)
	for rows.Next() {
		var personID, fullName, lifeStatus string
		var by, bm, bd, dy, dm, dd sql.NullInt64
		var bc, dc string
		var bl, dl bool
		if err := rows.Scan(
			&personID, &fullName, &lifeStatus,
			&by, &bm, &bd, &bc, &bl,
			&dy, &dm, &dd, &dc, &dl,
		); err != nil {
			return nil, fmt.Errorf("scan anniversary person: %w", err)
		}
		if by.Valid && bm.Valid && bd.Valid {
			item, ok := makeAnniversary(personID, fullName, "birthday",
				anniversaryDate{int(by.Int64), int(bm.Int64), int(bd.Int64), bc, bl},
				now, days)
			if ok {
				items = append(items, item)
			}
		}
		if lifeStatus == "deceased" && dy.Valid && dm.Valid && dd.Valid {
			item, ok := makeAnniversary(personID, fullName, "memorial",
				anniversaryDate{int(dy.Int64), int(dm.Int64), int(dd.Int64), dc, dl},
				now, days)
			if ok {
				items = append(items, item)
			}
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate anniversary persons: %w", err)
	}
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].Date == items[j].Date {
			return items[i].Kind < items[j].Kind
		}
		return items[i].Date < items[j].Date
	})
	if len(items) > 100 {
		items = items[:100]
	}
	return items, nil
}

func makeAnniversary(
	personID, fullName, kind string, date anniversaryDate,
	now time.Time, days int,
) (model.Anniversary, bool) {
	location := now.Location()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, location)
	event, lunarDate, age, ok := nextAnniversary(date, today)
	if !ok {
		return model.Anniversary{}, false
	}
	daysUntil := int(event.Sub(today).Hours() / 24)
	if daysUntil < 0 || daysUntil > days {
		return model.Anniversary{}, false
	}
	ageValue := age
	return model.Anniversary{
		PersonID: personID, FullName: fullName, Kind: kind,
		Date:      event.Format("2006-01-02"),
		DaysUntil: daysUntil,
		SolarText: fmt.Sprintf("%d年%d月%d日", event.Year(), int(event.Month()), event.Day()),
		LunarText: fmt.Sprintf("%s年%s月%s",
			lunarDate.GetYearInGanZhi(), lunarDate.GetMonthInChinese(), lunarDate.GetDayInChinese()),
		Age:     &ageValue,
		IsLunar: date.calendar == "lunar",
	}, true
}

func nextAnniversary(
	date anniversaryDate, today time.Time,
) (time.Time, *lunar.Lunar, int, bool) {
	startYear := today.Year()
	for offset := 0; offset <= 1; offset++ {
		targetYear := startYear + offset
		var event time.Time
		if date.calendar == "lunar" {
			lunarEvent, ok := lunarEventForYear(date, targetYear)
			if !ok {
				continue
			}
			solar := lunarEvent.GetSolar()
			event = time.Date(solar.GetYear(), time.Month(solar.GetMonth()), solar.GetDay(),
				0, 0, 0, 0, today.Location())
		} else {
			event = solarEventForYear(date, targetYear, today.Location())
		}
		if event.Before(today) {
			continue
		}
		lunarDate := lunar.NewLunarFromDate(event)
		age := event.Year() - date.year
		if date.calendar == "lunar" {
			age = lunarDate.GetYear() - date.year
		}
		if age < 0 {
			age = 0
		}
		return event, lunarDate, age, true
	}
	return time.Time{}, nil, 0, false
}

func solarEventForYear(date anniversaryDate, year int, location *time.Location) time.Time {
	day := date.day
	// Keep Feb 29 birthdays observable in non-leap years.
	if date.month == 2 && day == 29 {
		last := time.Date(year, 3, 0, 0, 0, 0, 0, location).Day()
		if last == 28 {
			day = 28
		}
	}
	return time.Date(year, time.Month(date.month), day, 0, 0, 0, 0, location)
}

func lunarEventForYear(date anniversaryDate, solarYear int) (result *lunar.Lunar, ok bool) {
	defer func() {
		if recover() != nil {
			result, ok = nil, false
		}
	}()
	// The lunar year containing the start of the solar year is the best
	// approximation; try both adjacent lunar years to avoid New Year gaps.
	lunarYear := lunar.NewLunarFromDate(time.Date(solarYear, 1, 1, 0, 0, 0, 0, time.Local)).GetYear()
	for _, year := range []int{lunarYear, lunarYear + 1} {
		signedMonth := date.month
		if date.leap {
			signedMonth = -date.month
			if lunar.NewLunarYear(year).GetMonth(signedMonth) == nil {
				signedMonth = date.month
			}
		}
		month := lunar.NewLunarYear(year).GetMonth(signedMonth)
		if month == nil || date.day > month.GetDayCount() {
			continue
		}
		return lunar.NewLunarFromYmd(year, signedMonth, date.day), true
	}
	return nil, false
}
