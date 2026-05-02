package app

import (
	"fmt"
	"math/rand"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

type deviceRegisterReq struct {
	DeviceID   string `json:"device_id" binding:"required"`
	Brand      string `json:"brand"`
	Model      string `json:"model"`
	OSVersion  string `json:"os_version"`
	AppVersion string `json:"app_version"`
}

// DeviceRegister 设备注册/更新（公开接口，无需签名）
func DeviceRegister(c *gin.Context) {
	var req deviceRegisterReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	now := time.Now()
	ip := c.ClientIP()

	var device model.Device
	result := database.DB.Where("device_id = ?", req.DeviceID).First(&device)

	if result.Error != nil {
		// 新设备，生成唯一 7 位展示 ID
		displayID := generateUniqueDisplayID()
		device = model.Device{
			DeviceID:   req.DeviceID,
			DisplayID:  displayID,
			Brand:      req.Brand,
			Model:      req.Model,
			OSVersion:  req.OSVersion,
			AppVersion: req.AppVersion,
			LastIP:     ip,
			LastSeenAt: &now,
		}
		database.DB.Create(&device)
	} else {
		// 已有设备，更新活跃信息
		database.DB.Model(&device).Updates(map[string]interface{}{
			"brand":        req.Brand,
			"model":        req.Model,
			"os_version":   req.OSVersion,
			"app_version":  req.AppVersion,
			"last_ip":      ip,
			"last_seen_at": now,
		})
	}

	handler.OK(c, gin.H{
		"device_id":  req.DeviceID,
		"display_id": device.DisplayID,
	})
}

// generateUniqueDisplayID 生成唯一的 7 位数字展示 ID（1000000~9999999）
func generateUniqueDisplayID() string {
	for {
		n := 1_000_000 + rand.Intn(9_000_000)
		id := fmt.Sprintf("%07d", n)
		var count int64
		database.DB.Model(&model.Device{}).Where("display_id = ?", id).Count(&count)
		if count == 0 {
			return id
		}
	}
}

type heartbeatReq struct {
	DeviceID string `json:"device_id" binding:"required"`
	Seconds  int    `json:"seconds"` // 本次上报的使用秒数（通常 60）
}

// DeviceHeartbeat VPN 使用心跳（需要签名 + JWT）
func DeviceHeartbeat(c *gin.Context) {
	var req heartbeatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	userID := c.GetUint64("user_id")

	// 限制单次上报最多 65 秒（防止异常上报）
	seconds := req.Seconds
	if seconds <= 0 {
		seconds = 60
	}
	if seconds > 65 {
		seconds = 65
	}

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	// 检查是否有有效套餐（有套餐则不消耗免费时长）
	hasPlan := user.CurrentPlanID != nil && user.PlanExpiredAt != nil && user.PlanExpiredAt.After(time.Now())
	if hasPlan {
		handler.OK(c, gin.H{
			"has_plan":          true,
			"remaining_seconds": -1, // -1 表示无限（套餐用户）
		})
		return
	}

	// 累加免费时长
	newUsed := user.FreeUsedSeconds + seconds
	if newUsed > user.FreeLimitSeconds {
		newUsed = user.FreeLimitSeconds
	}
	database.DB.Model(&user).Update("free_used_seconds", newUsed)

	remaining := user.FreeLimitSeconds - newUsed

	handler.OK(c, gin.H{
		"has_plan":          false,
		"remaining_seconds": remaining,
		"used_seconds":      newUsed,
		"limit_seconds":     user.FreeLimitSeconds,
	})
}
