package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"

	"cy5vpn/server/internal/service"
)

// 仅用于本地/测试环境模拟易支付成功通知，切勿在生产服务器上保留 EPAY_KEY 后运行未知命令。
func main() {
	baseURL := flag.String("base-url", "http://127.0.0.1:8080", "CY5 server base URL")
	orderNo := flag.String("order", "", "payment order number")
	money := flag.String("money", "", "exact order amount, e.g. 9.90")
	tradeNo := flag.String("trade", "MOCK-TRADE-001", "mock gateway trade number")
	flag.Parse()

	pid, key := os.Getenv("EPAY_PID"), os.Getenv("EPAY_KEY")
	if pid == "" || key == "" || *orderNo == "" || *money == "" {
		fmt.Fprintln(os.Stderr, "EPAY_PID、EPAY_KEY、-order 和 -money 均为必填")
		os.Exit(2)
	}
	values := url.Values{
		"pid":          {pid},
		"trade_no":     {*tradeNo},
		"out_trade_no": {*orderNo},
		"type":         {"alipay"},
		"name":         {"CY5 mock payment"},
		"money":        {*money},
		"trade_status": {"TRADE_SUCCESS"},
		"sign_type":    {"MD5"},
	}
	values.Set("sign", service.EPaySign(values, key))
	notifyURL := strings.TrimRight(*baseURL, "/") + "/api/public/payment/notify?" + values.Encode()
	resp, err := http.Get(notifyURL) // #nosec G107 -- explicit developer test tool
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	fmt.Printf("HTTP %d: %s\n", resp.StatusCode, strings.TrimSpace(string(body)))
	if resp.StatusCode != http.StatusOK || strings.TrimSpace(string(body)) != "success" {
		os.Exit(1)
	}
}
