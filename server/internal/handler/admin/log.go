package admin

import (
	"net"
	"strconv"
	"strings"

	"cy5vpn/server/internal/database"
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

	handler.OK(c, gin.H{"total": total, "page": page, "size": size, "list": logs})
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
			"created_at": log.CreatedAt,
		})
	}

	handler.OK(c, gin.H{"total": total, "page": page, "size": size, "list": result})
}

func describeIP(ip string) gin.H {
	parsed := net.ParseIP(ip)
	detail := gin.H{"ip": ip, "type": "unknown", "is_private": false, "location": "未知"}
	if parsed == nil {
		return detail
	}
	if parsed.IsLoopback() {
		detail["type"] = "loopback"
		detail["location"] = "本机"
		return detail
	}
	if parsed.IsPrivate() {
		detail["type"] = "private"
		detail["is_private"] = true
		detail["location"] = privateIPLocation(ip)
		return detail
	}
	if parsed.To4() != nil {
		detail["type"] = "ipv4"
	} else {
		detail["type"] = "ipv6"
	}
	detail["location"] = "公网 IP（未接入 GeoIP 库）"
	return detail
}

func privateIPLocation(ip string) string {
	switch {
	case strings.HasPrefix(ip, "192.168."):
		return "局域网 192.168.x.x"
	case strings.HasPrefix(ip, "10."):
		return "局域网 10.x.x.x"
	case strings.HasPrefix(ip, "172."):
		return "局域网 172.16-31.x.x"
	default:
		return "内网地址"
	}
}
