package app

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/service"
	"cy5vpn/server/internal/ws"

	"github.com/gin-gonic/gin"
)

type confirmPaymentReq struct {
	PlanID       uint   `json:"plan_id" binding:"required"`
	BillingCycle string `json:"billing_cycle" binding:"required"`
	PayChannel   string `json:"pay_channel"`
	PaymentMode  string `json:"payment_mode"`
}

// NotifyPaymentConfirm 用户二次确认后：手动模式立即开通套餐；自动模式仅 ntfy 通知（套餐由易支付回调开通）。
func NotifyPaymentConfirm(c *gin.Context) {
	var req confirmPaymentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	userID := c.GetUint64("user_id")
	var user model.User
	if err := database.DB.Select("id, username").First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	if strings.EqualFold(strings.TrimSpace(req.PaymentMode), "auto") {
		go pushPaymentConfirmNtfy()
		handler.OK(c, gin.H{"msg": "ok"})
		return
	}

	payMethod := normalizeConfirmPayMethod(req.PayChannel)
	remark := fmt.Sprintf("用户二次确认开通，待核实；模式=%s；渠道=%s", strings.TrimSpace(req.PaymentMode), payMethod)
	record, err := service.FulfillPlanPurchase(database.DB, userID, req.PlanID, req.BillingCycle, payMethod, remark)
	if err != nil {
		handler.Fail(c, 400, err.Error())
		return
	}

	ws.Notices.PushEvent(userID, "status_update", gin.H{
		"msg": "套餐已开通，管理员将核实付款情况",
	})

	go pushPaymentConfirmNtfy()

	handler.OK(c, gin.H{
		"msg":   "开通成功",
		"order": record,
	})
}

func normalizeConfirmPayMethod(channel string) string {
	switch strings.ToLower(strings.TrimSpace(channel)) {
	case "wechat", "wxpay":
		return "user_confirm_wechat"
	case "alipay":
		return "user_confirm_alipay"
	case "qq", "qqpay":
		return "user_confirm_qq"
	case "usdt":
		return "user_confirm_usdt"
	default:
		return "user_confirm"
	}
}

func pushPaymentConfirmNtfy() {
	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest(http.MethodPost, "https://ntfy.sh/vpn", strings.NewReader("vpn"))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = client.Do(req)
}
