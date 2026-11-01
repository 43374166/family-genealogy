package store

import (
	"database/sql"
	"fmt"
)

type normalizedDate struct {
	year     any
	month    any
	day      any
	calendar string
	leap     bool
	text     string
}

func normalizeEventDate(
	year, month, day *int, calendar string, leap bool,
) (normalizedDate, error) {
	if year == nil {
		if month != nil || day != nil {
			return normalizedDate{}, fmt.Errorf("date month/day require a year")
		}
		return normalizedDate{calendar: "unknown"}, nil
	}
	if *year < 1 || *year > 9999 {
		return normalizedDate{}, fmt.Errorf("year must be between 1 and 9999")
	}
	if calendar == "" || calendar == "unknown" {
		calendar = "gregorian"
	}
	if calendar != "gregorian" && calendar != "lunar" {
		return normalizedDate{}, fmt.Errorf("calendar must be gregorian or lunar")
	}
	if leap && calendar != "lunar" {
		return normalizedDate{}, fmt.Errorf("leap month is only valid for lunar dates")
	}
	if month == nil {
		return normalizedDate{
			year: *year, calendar: calendar, leap: false,
			text: fmt.Sprintf("%d年", *year),
		}, nil
	}
	if *month < 1 || *month > 12 {
		return normalizedDate{}, fmt.Errorf("month must be between 1 and 12")
	}
	if day == nil {
		return normalizedDate{
			year: *year, month: *month, calendar: calendar, leap: false,
			text: fmt.Sprintf("%d-%02d", *year, *month),
		}, nil
	}
	maxDay := 31
	if calendar == "lunar" {
		maxDay = 30
	}
	if *day < 1 || *day > maxDay {
		return normalizedDate{}, fmt.Errorf("day is out of range")
	}
	prefix := ""
	if calendar == "lunar" {
		prefix = "农历"
		if leap {
			prefix += "闰"
		}
	}
	return normalizedDate{
		year: *year, month: *month, day: *day,
		calendar: calendar, leap: leap,
		text: fmt.Sprintf("%s%d-%02d-%02d", prefix, *year, *month, *day),
	}, nil
}

func (d normalizedDate) nullable() (year, month, day any) {
	return d.year, d.month, d.day
}

func loadExistingDate(
	tx *sql.Tx, personID, prefix string,
) (year, month, day *int, calendar string, leap bool, err error) {
	var y, m, d sql.NullInt64
	var cal string
	var lp bool
	query := fmt.Sprintf(
		"SELECT %s_year, %s_month, %s_day, %s_calendar, %s_is_leap_month FROM persons WHERE id = ?",
		prefix, prefix, prefix, prefix, prefix,
	)
	if err := tx.QueryRow(query, personID).Scan(&y, &m, &d, &cal, &lp); err != nil {
		return nil, nil, nil, "", false, err
	}
	if y.Valid {
		v := int(y.Int64)
		year = &v
	}
	if m.Valid {
		v := int(m.Int64)
		month = &v
	}
	if d.Valid {
		v := int(d.Int64)
		day = &v
	}
	return year, month, day, cal, lp, nil
}
