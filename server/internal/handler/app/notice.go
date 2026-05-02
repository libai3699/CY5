package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetNotices 获取公共通知列表（只返回启用的）
func GetNotices(c *gin.Context) {
	var notices []model.Notice
	database.DB.Where("is_active = 1").Order("sort_order asc, created_at desc").Find(&notices)
	handler.OK(c, notices)
}
