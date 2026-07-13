package app

import (
	"fmt"
	"html"
	"net/http"
	"net/url"
	"sort"
	"strings"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type createPaymentOrderReq struct {
	PlanID       uint   `json:"plan_id" binding:"required"`
	BillingCycle string `json:"billing_cycle" binding:"required"`
	PayType      string `json:"pay_type" binding:"required"`
}

// CreatePaymentOrder 创建易支付订单并返回签名后的收银台地址。
func CreatePaymentOrder(c *gin.Context) {
	cfg := config.App
	if cfg.EPayPID == "" || cfg.EPayKey == "" || cfg.EPayNotifyURL == "" || cfg.EPayReturnURL == "" {
		handler.Fail(c, 503, "在线支付尚未配置完整")
		return
	}

	var req createPaymentOrderReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}
	if req.PayType != "alipay" && req.PayType != "wxpay" {
		handler.Fail(c, 400, "仅支持支付宝或微信支付")
		return
	}

	var plan model.Plan
	if err := database.DB.Where("id = ? AND is_active = 1", req.PlanID).First(&plan).Error; err != nil {
		handler.Fail(c, 404, "套餐不存在或已下架")
		return
	}
	months, amountCents, err := service.PurchaseTerms(plan, req.BillingCycle)
	if err != nil {
		handler.Fail(c, 400, err.Error())
		return
	}
	orderNo, err := service.NewPaymentOrderNo()
	if err != nil {
		handler.Fail(c, 500, "生成订单号失败")
		return
	}
	checkoutToken, err := service.NewPaymentCheckoutToken()
	if err != nil {
		handler.Fail(c, 500, "生成收银台令牌失败")
		return
	}

	var trafficGB *int
	if plan.TrafficGB != nil {
		value := *plan.TrafficGB * months
		trafficGB = &value
	}
	payment := model.PaymentOrder{
		OrderNo: orderNo, CheckoutToken: checkoutToken,
		UserID: c.GetUint64("user_id"), PlanID: plan.ID,
		PlanName: plan.Name, BillingCycle: req.BillingCycle, Months: months,
		DurationDays: plan.DurationDays * months, TrafficGB: trafficGB,
		AmountCents: amountCents, PayType: req.PayType, Status: "pending",
	}
	if err := database.DB.Create(&payment).Error; err != nil {
		handler.Fail(c, 500, "创建支付订单失败")
		return
	}

	payURL, err := checkoutURL(cfg.EPayNotifyURL, payment.OrderNo, payment.CheckoutToken)
	if err != nil {
		handler.Fail(c, 500, "支付回调地址配置无效")
		return
	}
	handler.OK(c, gin.H{
		"order_no": payment.OrderNo,
		"amount":   fmt.Sprintf("%.2f", float64(payment.AmountCents)/100),
		"pay_url":  payURL,
		"status":   payment.Status,
	})
}

// EPayCheckout 用自动提交的 HTML 表单桥接系统浏览器与网关要求的 POST 接口。
func EPayCheckout(c *gin.Context) {
	var payment model.PaymentOrder
	if err := database.DB.Where("order_no = ? AND checkout_token = ?", c.Param("order_no"), c.Query("token")).First(&payment).Error; err != nil {
		c.String(http.StatusNotFound, "checkout not found")
		return
	}
	if payment.Status == "paid" {
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(http.StatusOK, "<!doctype html><meta charset=utf-8><h2>该订单已支付，请返回 CY5 App。</h2>")
		return
	}
	cfg := config.App
	gateway, err := url.Parse(cfg.EPayGatewayURL)
	if err != nil || gateway.Scheme == "" || gateway.Host == "" {
		c.String(http.StatusInternalServerError, "payment gateway is not configured")
		return
	}
	values := url.Values{
		"pid":          {cfg.EPayPID},
		"type":         {payment.PayType},
		"out_trade_no": {payment.OrderNo},
		"notify_url":   {cfg.EPayNotifyURL},
		"return_url":   {cfg.EPayReturnURL},
		"name":         {payment.PlanName},
		"money":        {fmt.Sprintf("%.2f", float64(payment.AmountCents)/100)},
		"sitename":     {cfg.EPaySiteName},
	}
	values.Set("sign", service.EPaySign(values, cfg.EPayKey))
	values.Set("sign_type", "MD5")
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	var fields strings.Builder
	for _, key := range keys {
		fmt.Fprintf(&fields, `<input type="hidden" name="%s" value="%s">`, html.EscapeString(key), html.EscapeString(values.Get(key)))
	}
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.String(http.StatusOK, `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>正在前往支付</title><body><p>正在安全跳转到支付页面…</p><form id="pay" method="post" action="%s">%s<noscript><button type="submit">继续支付</button></noscript></form><script>document.getElementById('pay').submit()</script></body></html>`, html.EscapeString(gateway.String()), fields.String())
}

func checkoutURL(notifyURL, orderNo, token string) (string, error) {
	u, err := url.Parse(notifyURL)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return "", fmt.Errorf("invalid notify URL")
	}
	u.Path = "/api/public/payment/checkout/" + url.PathEscape(orderNo)
	u.RawQuery = url.Values{"token": {token}}.Encode()
	u.Fragment = ""
	return u.String(), nil
}

func GetPaymentOrder(c *gin.Context) {
	var payment model.PaymentOrder
	err := database.DB.Select("order_no, amount_cents, pay_type, status, paid_at, created_at").
		Where("order_no = ? AND user_id = ?", c.Param("order_no"), c.GetUint64("user_id")).
		First(&payment).Error
	if err != nil {
		handler.Fail(c, 404, "支付订单不存在")
		return
	}
	handler.OK(c, payment)
}

func EPayNotify(c *gin.Context) {
	values, err := requestValues(c)
	if err != nil {
		c.String(http.StatusOK, "fail")
		return
	}
	if err := processEPayCallback(values); err != nil {
		fmt.Printf("[EPAY] notify rejected: %v\n", err)
		c.String(http.StatusOK, "fail")
		return
	}
	c.String(http.StatusOK, "success")
}

func EPayReturn(c *gin.Context) {
	values, err := requestValues(c)
	if err == nil {
		err = processEPayCallback(values)
	}
	title, message := "支付成功", "订单已经到账，请返回 CY5 App 查看套餐状态。"
	if err != nil {
		title, message = "支付结果待确认", "暂时无法确认订单，请返回 App 稍后检查；如已扣款请勿重复支付。"
		fmt.Printf("[EPAY] return rejected: %v\n", err)
	}
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.String(http.StatusOK, `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%s</title><body style="font-family:sans-serif;text-align:center;padding:60px 20px"><h2>%s</h2><p>%s</p></body></html>`, html.EscapeString(title), html.EscapeString(title), html.EscapeString(message))
}

func requestValues(c *gin.Context) (url.Values, error) {
	if err := c.Request.ParseForm(); err != nil {
		return nil, err
	}
	return c.Request.Form, nil
}

func processEPayCallback(values url.Values) error {
	cfg := config.App
	if cfg.EPayKey == "" || !service.VerifyEPaySign(values, cfg.EPayKey) {
		return fmt.Errorf("invalid signature")
	}
	if values.Get("pid") != cfg.EPayPID {
		return fmt.Errorf("pid mismatch")
	}
	if strings.ToUpper(values.Get("trade_status")) != "TRADE_SUCCESS" {
		return fmt.Errorf("trade status is not success")
	}
	orderNo := values.Get("out_trade_no")
	if orderNo == "" {
		return fmt.Errorf("missing order number")
	}
	var payment model.PaymentOrder
	if err := database.DB.Where("order_no = ?", orderNo).First(&payment).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return fmt.Errorf("order not found")
		}
		return err
	}
	moneyCents, err := service.ParseMoneyCents(values.Get("money"))
	if err != nil || moneyCents != payment.AmountCents {
		return fmt.Errorf("amount mismatch")
	}
	tradeNo := values.Get("trade_no")
	if tradeNo == "" {
		return fmt.Errorf("missing gateway trade number")
	}
	_, err = service.CompletePayment(database.DB, orderNo, tradeNo)
	return err
}
