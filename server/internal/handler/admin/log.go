package admin

import (
	"strconv"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/geoip"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

func ListUserLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}

	var total int64
	database.DB.Model(&model.UserLoginLog{}).Count(&total)

	var logs []model.UserLoginLog
	database.DB.Order("created_at desc").
		Offset((page - 1) * size).
		Limit(size).
		Find(&logs)

	result := make([]gin.H, 0, len(logs))
	for _, log := range logs {
		result = append(result, gin.H{
			"id":          log.ID,
			"user_id":     log.UserID,
			"device_id":   log.DeviceID,
			"ip":          log.IP,
			"ip_detail":   describeIP(log.IP),
			"app_version": log.AppVersion,
			"status":      log.Status,
			"status_text": loginStatusText(log.Status),
			"fail_reason": log.FailReason,
			"created_at":  formatDateTime(log.CreatedAt),
		})
	}

	handler.OK(c, gin.H{"total": total, "page": page, "size": size, "list": result})
}

func ListAdminLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}

	var total int64
	database.DB.Model(&model.AdminLoginLog{}).Count(&total)

	var logs []model.AdminLoginLog
	database.DB.Order("created_at desc").
		Offset((page - 1) * size).
		Limit(size).
		Find(&logs)

	result := make([]gin.H, 0, len(logs))
	for _, log := range logs {
		result = append(result, gin.H{
			"id":         log.ID,
			"username":   log.Username,
			"ip":         log.IP,
			"ip_detail":  describeIP(log.IP),
			"user_agent": log.UserAgent,
			"status":     log.Status,
			"status_text": loginStatusText(log.Status),
			"fail_reason": log.FailReason,
			"created_at": formatDateTime(log.CreatedAt),
		})
	}

	handler.OK(c, gin.H{"total": total, "page": page, "size": size, "list": result})
}

func describeIP(ip string) gin.H {
	return gin.H(geoip.Describe(ip))
}
