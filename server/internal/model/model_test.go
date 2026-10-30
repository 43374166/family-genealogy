package model

import "testing"

func TestGenerationLabel(t *testing.T) {
	cases := map[int]string{
		1:  "第一世",
		8:  "第八世",
		10: "第十世",
		11: "第十一世",
		20: "第二十世",
		21: "第二十一世",
		99: "第九十九世",
	}
	for generation, want := range cases {
		if got := GenerationLabel(generation); got != want {
			t.Errorf("GenerationLabel(%d) = %q, want %q", generation, got, want)
		}
	}
}
