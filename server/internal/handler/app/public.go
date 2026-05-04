package app

import (
	"strconv"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

func GetPublicConfig(c *gin.Context) {
	var configs []model.AppConfig
	database.DB.Order("sort_order asc").Find(&configs)

	result := make(map[string]string)
	for _, cfg := range configs {
		result[cfg.KeyName] = cfg.Value
	}
	handler.OK(c, result)
}

func GetPublicAppStatus(c *gin.Context) {
	handler.OK(c, gin.H{
		"plan_level":          "免费体验",
		"remaining_seconds":   0,
		"traffic_remaining":   "0 GB",
		"server_time":         time.Now().Unix(),
		"remaining_time_text": "未登录",
	})
}

func formatRemainingTime(seconds int) string {
	if seconds <= 0 {
		return "已到期"
	}
	if seconds >= 24*60*60 {
		days := seconds / (24 * 60 * 60)
		minutes := (seconds % (24 * 60 * 60)) / 60
		if minutes > 0 {
			return formatDaysMinutes(days, minutes)
		}
		return formatDaysMinutes(days, 0)
	}
	minutes := seconds / 60
	if minutes <= 1 {
		return "最后 1 分钟"
	}
	return formatDaysMinutes(0, minutes)
}

func formatDaysMinutes(days int, minutes int) string {
	if days > 0 && minutes > 0 {
		return strconv.Itoa(days) + "天 " + strconv.Itoa(minutes) + "分钟"
	}
	if days > 0 {
		return strconv.Itoa(days) + "天"
	}
	return strconv.Itoa(minutes) + "分钟"
}
