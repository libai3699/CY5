package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

type trackEventReq struct {
	Page      string  `json:"page"`
	Event     string  `json:"event"`
	DeviceID  string  `json:"device_id"`
	DisplayID string  `json:"display_id"`
	PlanName  string  `json:"plan_name"`
	PlanPrice float64 `json:"plan_price"`
	Cycle     string  `json:"cycle"`
	StayMs    int64   `json:"stay_ms"`
}

// TrackEvent 接收前端埋点上报（无需登录）
func TrackEvent(c *gin.Context) {
	var req trackEventReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	event := model.PageEvent{
		Page:      req.Page,
		Event:     req.Event,
		DeviceID:  req.DeviceID,
		DisplayID: req.DisplayID,
		PlanName:  req.PlanName,
		PlanPrice: req.PlanPrice,
		Cycle:     req.Cycle,
		StayMs:    req.StayMs,
		IP:        c.ClientIP(),
	}

	// 如果有登录态，从 JWT 中间件取用户信息
	if userID, exists := c.Get("user_id"); exists {
		if uid, ok := userID.(uint64); ok && uid > 0 {
			event.UserID = &uid
			// 查用户名
			var u model.User
			if err := database.DB.Select("username").First(&u, uid).Error; err == nil {
				event.Username = u.Username
			}
		}
	}

	database.DB.Create(&event)
	handler.OK(c, gin.H{"msg": "ok"})
}
