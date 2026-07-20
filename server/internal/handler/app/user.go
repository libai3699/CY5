package app

import (
	"strconv"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/geoip"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
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

	println("[STATUS] ========== 获取用户状态 ==========")
	println("[STATUS] UserID:", userID)

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		println("[ERROR] 查询用户失败:", err.Error())
		handler.Fail(c, 404, "用户不存在")
		return
	}

	println("[STATUS] 当前已用流量:", user.TrafficUsedBytes, "bytes (", formatGB(user.TrafficUsedBytes), ")")
	if user.TrafficLimitBytes != nil {
		println("[STATUS] 流量限制:", *user.TrafficLimitBytes, "bytes (", formatGB(*user.TrafficLimitBytes), ")")
	} else {
		println("[STATUS] 流量限制: 无限")
	}

	hasPlan := userHasPlan(user)

	remaining := freeRemaining(user)

	if coupling := service.QuotaCouplingUpdates(user); len(coupling) > 0 {
		database.DB.Model(&user).Updates(coupling)
		if err := database.DB.First(&user, userID).Error; err == nil {
			hasPlan = userHasPlan(user)
		}
	}

	planLevel := "免费体验"
	remainingSeconds := remaining
	trafficRemaining := "0 GB"
	if hasPlan {
		quota := service.BuildPlanQuotaView(user, formatGB)
		planLevel = "付费套餐"
		remainingSeconds = quota.RemainingSeconds
		trafficRemaining = quota.TrafficRemaining
		hasPlan = quota.HasPlan
	}

	println("[STATUS] 返回结果 | 剩余流量:", trafficRemaining)
	println("[STATUS] ========== 状态查询完成 ==========")

	handler.OK(c, gin.H{
		"has_plan":            hasPlan,
		"plan_level":          planLevel,
		"remaining_seconds":   remainingSeconds,
		"remaining_time_text": formatRemainingTime(remainingSeconds),
		"traffic_remaining":   trafficRemaining,
		"server_time":         time.Now().Unix(),
	})
}

type userHeartbeatReq struct {
	Seconds      int   `json:"seconds"`
	TrafficBytes int64 `json:"traffic_bytes"` // 本次心跳周期内的流量增量（字节）
}

func UserHeartbeat(c *gin.Context) {
	userID := c.GetUint64("user_id")
	var req userHeartbeatReq
	_ = c.ShouldBindJSON(&req)

	println("[HEARTBEAT] ========== 开始处理心跳 ==========")
	println("[HEARTBEAT] UserID:", userID, "| 上报秒数:", req.Seconds, "| 上报流量:", req.TrafficBytes, "bytes")

	seconds := req.Seconds
	if seconds <= 0 {
		seconds = 60
	}
	if seconds > 65 {
		seconds = 65
	}
	// 流量增量：限制单次上报最多 500MB，防止异常数据
	trafficBytes := req.TrafficBytes
	if trafficBytes < 0 {
		trafficBytes = 0
	}
	const maxTrafficPerHeartbeat = int64(500 * 1024 * 1024) // 500MB
	if trafficBytes > maxTrafficPerHeartbeat {
		println("[HEARTBEAT] 流量超限，限制为500MB，原值:", trafficBytes)
		trafficBytes = maxTrafficPerHeartbeat
	}

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		println("[ERROR] 查询用户失败:", err.Error())
		handler.Fail(c, 404, "用户不存在")
		return
	}

	println("[HEARTBEAT] 查询用户成功 | 当前已用流量:", user.TrafficUsedBytes, "bytes (", formatGB(user.TrafficUsedBytes), ")")
	if user.TrafficLimitBytes != nil {
		println("[HEARTBEAT] 流量限制:", *user.TrafficLimitBytes, "bytes (", formatGB(*user.TrafficLimitBytes), ")")
	} else {
		println("[HEARTBEAT] 流量限制: 无限")
	}

	hasPlan := userHasPlan(user)

	updates := map[string]interface{}{}

	// 累加免费时长（无套餐时）
	if !hasPlan {
		used := user.FreeUsedSeconds + seconds
		if used > user.FreeLimitSeconds {
			used = user.FreeLimitSeconds
		}
		updates["free_used_seconds"] = used
		user.FreeUsedSeconds = used
	}

	// 累加流量（使用原子更新，防止高并发时被覆盖）
	trafficExhausted := false
	if trafficBytes > 0 {
		// 记录更新前的值
		oldTraffic := user.TrafficUsedBytes
		
		// 原子更新
		result := database.DB.Model(&user).Update("traffic_used_bytes", gorm.Expr("traffic_used_bytes + ?", trafficBytes))
		if result.Error != nil {
			handler.Fail(c, 500, "流量更新失败")
			return
		}
		
		// 重新查询最新的 traffic_used_bytes，确保计算剩余流量时使用最新值
		if err := database.DB.Model(&user).Select("traffic_used_bytes").Where("id = ?", user.ID).Scan(&user).Error; err != nil {
			handler.Fail(c, 500, "查询流量失败")
			return
		}
		
		// 详细日志：记录流量变化
		println("[TRAFFIC] UserID:", user.ID, 
			"| 上报:", trafficBytes, "bytes (", formatGB(trafficBytes), ")",
			"| 更新前:", oldTraffic, "bytes (", formatGB(oldTraffic), ")",
			"| 更新后:", user.TrafficUsedBytes, "bytes (", formatGB(user.TrafficUsedBytes), ")",
			"| 影响行数:", result.RowsAffected)
	}

	if hasPlan && user.TrafficLimitBytes != nil && user.TrafficUsedBytes >= *user.TrafficLimitBytes {
		trafficExhausted = true
		println("[TRAFFIC] UserID:", user.ID, "流量已耗尽! 已用:", user.TrafficUsedBytes, "限制:", *user.TrafficLimitBytes)
		if coupling := service.QuotaCouplingUpdates(user); len(coupling) > 0 {
			database.DB.Model(&user).Updates(coupling)
			if err := database.DB.First(&user, userID).Error; err == nil {
				hasPlan = userHasPlan(user)
			}
		}
	}

	if len(updates) > 0 {
		if err := database.DB.Model(&user).Updates(updates).Error; err != nil {
			println("[ERROR] 更新用户信息失败:", err.Error())
		}
	}

	remaining := freeRemaining(user)
	remainingSeconds := remaining
	trafficRemaining := "0 GB"
	hasPlanActive := hasPlan
	if hasPlan {
		quota := service.BuildPlanQuotaView(user, formatGB)
		remainingSeconds = quota.RemainingSeconds
		trafficRemaining = quota.TrafficRemaining
		hasPlanActive = quota.HasPlan
		if quota.TrafficLeftBytes <= 0 && user.TrafficLimitBytes != nil {
			trafficExhausted = true
		}
	}

	println("[HEARTBEAT] 返回结果 | 剩余流量:", trafficRemaining, "| 流量耗尽:", trafficExhausted)
	println("[HEARTBEAT] ========== 心跳处理完成 ==========")

	handler.OK(c, gin.H{
		"has_plan":            hasPlanActive,
		"remaining_seconds":   remainingSeconds,
		"remaining_time_text": formatRemainingTime(remainingSeconds),
		"traffic_remaining":   trafficRemaining,
		"traffic_exhausted":   trafficExhausted,
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
