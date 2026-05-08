package app

import (
	"strconv"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/geoip"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetProfile 获取用户信息 + 当前套餐状态
func GetProfile(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	// 检查套餐是否过期
	hasPlan := userHasPlan(user)

	remaining := freeRemaining(user)

	handler.OK(c, gin.H{
		"user":           safeUser(user),
		"has_plan":       hasPlan,
		"free_remaining": remaining,
	})
}

func GetUserStatus(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	hasPlan := userHasPlan(user)

	remaining := freeRemaining(user)

	planLevel := "免费体验"
	remainingSeconds := remaining
	if hasPlan {
		planLevel = "付费套餐"
		secs := int(time.Until(*user.PlanExpiredAt).Seconds())
		if secs < 0 {
			secs = 0
		}
		remainingSeconds = secs
	}

	trafficRemaining := "0 GB"
	if hasPlan {
		if user.TrafficLimitBytes != nil {
			left := *user.TrafficLimitBytes - user.TrafficUsedBytes
			if left < 0 {
				left = 0
			}
			trafficRemaining = formatGB(left)
		} else {
			trafficRemaining = "不限流量"
		}
	}

	handler.OK(c, gin.H{
		"plan_level":          planLevel,
		"remaining_seconds":   remainingSeconds,
		"remaining_time_text": formatRemainingTime(remainingSeconds),
		"traffic_remaining":   trafficRemaining,
		"server_time":         time.Now().Unix(),
	})
}

type userHeartbeatReq struct {
	Seconds int `json:"seconds"`
}

func UserHeartbeat(c *gin.Context) {
	userID := c.GetUint64("user_id")
	var req userHeartbeatReq
	_ = c.ShouldBindJSON(&req)

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

	hasPlan := userHasPlan(user)
	if !hasPlan {
		used := user.FreeUsedSeconds + seconds
		if used > user.FreeLimitSeconds {
			used = user.FreeLimitSeconds
		}
		database.DB.Model(&user).Update("free_used_seconds", used)
		user.FreeUsedSeconds = used
	}

	remaining := freeRemaining(user)
	if hasPlan {
		remaining = int(time.Until(*user.PlanExpiredAt).Seconds())
	}

	handler.OK(c, gin.H{
		"has_plan":            hasPlan,
		"remaining_seconds":   remaining,
		"remaining_time_text": formatRemainingTime(remaining),
	})
}

func ListLoginDevices(c *gin.Context) {
	userID := c.GetUint64("user_id")
	var devices []model.Device
	database.DB.Where("user_id = ?", userID).Order("last_seen_at desc, updated_at desc").Find(&devices)
	result := make([]gin.H, 0, len(devices))
	for _, device := range devices {
		result = append(result, gin.H{
			"id":             device.ID,
			"device_id":      device.DeviceID,
			"display_id":     device.DisplayID,
			"user_id":        device.UserID,
			"brand":          device.Brand,
			"model":          device.Model,
			"os_version":     device.OSVersion,
			"app_version":    device.AppVersion,
			"last_ip":        device.LastIP,
			"last_ip_detail": geoip.Describe(device.LastIP),
			"last_seen_at":   device.LastSeenAt,
			"created_at":     device.CreatedAt,
			"updated_at":     device.UpdatedAt,
		})
	}
	handler.OK(c, result)
}

func LogoutCurrentDevice(c *gin.Context) {
	userID := c.GetUint64("user_id")
	deviceID := c.GetString("device_id")
	database.DB.Model(&model.Device{}).Where("device_id = ? AND user_id = ?", deviceID, userID).Updates(map[string]interface{}{"user_id": nil})
	handler.OK(c, gin.H{"msg": "退出成功"})
}

func RemoveLoginDevice(c *gin.Context) {
	userID := c.GetUint64("user_id")
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}
	database.DB.Model(&model.Device{}).Where("id = ? AND user_id = ?", id, userID).Updates(map[string]interface{}{"user_id": nil})
	handler.OK(c, gin.H{"msg": "移除成功"})
}

func formatGB(bytes int64) string {
	gb := float64(bytes) / 1024 / 1024 / 1024
	return strconv.FormatFloat(gb, 'f', 2, 64) + " GB"
}

// userHasPlan 判断用户是否有有效套餐（只要 plan_expired_at 未过期即可）
func userHasPlan(user model.User) bool {
	return user.PlanExpiredAt != nil && user.PlanExpiredAt.After(time.Now())
}

func freeRemaining(user model.User) int {
	usedRemaining := user.FreeLimitSeconds - user.FreeUsedSeconds
	elapsedRemaining := user.FreeLimitSeconds - int(time.Since(user.CreatedAt).Seconds())
	if elapsedRemaining < usedRemaining {
		usedRemaining = elapsedRemaining
	}
	if usedRemaining < 0 {
		return 0
	}
	return usedRemaining
}

// GetOrders 获取购买历史
func GetOrders(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var orders []model.OrderRecord
	database.DB.Where("user_id = ?", userID).
		Order("created_at desc").
		Limit(50).
		Find(&orders)

	handler.OK(c, orders)
}
