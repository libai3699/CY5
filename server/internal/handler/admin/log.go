package admin

import (
	"strconv"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListUserLogs 前台登录日志
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

// ListAdminLogs 后台登录日志
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

	handler.OK(c, gin.H{"total": total, "page": page, "size": size, "list": logs})
}
