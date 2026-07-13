package service

import (
	"net/url"
	"testing"

	"cy5vpn/server/internal/model"
)

func TestEPaySign(t *testing.T) {
	values := url.Values{
		"pid": {"1001"}, "money": {"9.90"}, "name": {"基础版"},
		"out_trade_no": {"202607130001"}, "type": {"alipay"},
		"empty": {""}, "sign_type": {"MD5"},
	}
	wantString := "money=9.90&name=基础版&out_trade_no=202607130001&pid=1001&type=alipay"
	if got := EPaySignString(values); got != wantString {
		t.Fatalf("sign string = %q, want %q", got, wantString)
	}
	sign := EPaySign(values, "secret")
	values.Set("sign", sign)
	if !VerifyEPaySign(values, "secret") {
		t.Fatal("generated signature did not verify")
	}
	values.Set("money", "10.00")
	if VerifyEPaySign(values, "secret") {
		t.Fatal("modified parameters unexpectedly verified")
	}
}

func TestPurchaseTerms(t *testing.T) {
	discount := 0.9
	plan := model.Plan{Price: 19.9, DiscountQuarter: &discount}
	months, cents, err := PurchaseTerms(plan, "quarter")
	if err != nil || months != 3 || cents != 5373 {
		t.Fatalf("got months=%d cents=%d err=%v", months, cents, err)
	}
}

func TestParseMoneyCents(t *testing.T) {
	for input, want := range map[string]int64{"9.90": 990, "9.9": 990, "0.01": 1, "10": 1000} {
		got, err := ParseMoneyCents(input)
		if err != nil || got != want {
			t.Fatalf("ParseMoneyCents(%q) = %d, %v; want %d", input, got, err, want)
		}
	}
	for _, input := range []string{"9.904", "-1.00", "1.", "NaN"} {
		if _, err := ParseMoneyCents(input); err == nil {
			t.Fatalf("ParseMoneyCents(%q) unexpectedly succeeded", input)
		}
	}
}
