package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"strconv"

	"github.com/gin-gonic/gin"
)

// ListDurationLogs 追加记录列表
func ListDurationLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	userID := c.Query("user_id")

	if page < 1 {
		page = 1
	}
	offset := (page - 1) * size

	query := database.DB.Model(&model.DurationLog{})
	if userID != "" {
		query = query.Where("user_id = ?", userID)
	}

	var total int64
	query.Count(&total)

	var logs []model.DurationLog
	query.Order("created_at desc").Offset(offset).Limit(size).Find(&logs)

	handler.OK(c, gin.H{
		"list":  logs,
		"total": total,
		"page":  page,
		"size":  size,
	})
}
