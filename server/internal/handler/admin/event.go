package admin

import (
	"strconv"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListPageEvents 埋点事件列表
func ListPageEvents(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	page2 := c.Query("page_name")
	event := c.Query("event")

	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}

	query := database.DB.Model(&model.PageEvent{})
	if page2 != "" {
		query = query.Where("page = ?", page2)
	}
	if event != "" {
		query = query.Where("event = ?", event)
	}

	var total int64
	query.Count(&total)

	var events []model.PageEvent
	query.Order("created_at desc").
		Offset((page - 1) * size).
		Limit(size).
		Find(&events)

	result := make([]gin.H, 0, len(events))
	for _, event := range events {
		result = append(result, gin.H{
			"id":          event.ID,
			"page":        event.Page,
			"event":       event.Event,
			"user_id":     event.UserID,
			"username":    event.Username,
			"device_id":   event.DeviceID,
			"display_id":  event.DisplayID,
			"plan_name":   event.PlanName,
			"plan_price":  event.PlanPrice,
			"cycle":       event.Cycle,
			"stay_ms":     event.StayMs,
			"ip":          event.IP,
			"ip_detail":   describeIP(event.IP),
			"created_at":  event.CreatedAt,
		})
	}

	handler.OK(c, gin.H{
		"total": total,
		"page":  page,
		"size":  size,
		"list":  result,
	})
}

// PageEventStats 埋点统计汇总
func PageEventStats(c *gin.Context) {
	type stat struct {
		Page  string `json:"page"`
		Event string `json:"event"`
		Count int64  `json:"count"`
	}
	var stats []stat
	database.DB.Model(&model.PageEvent{}).
		Select("page, event, count(*) as count").
		Group("page, event").
		Order("count desc").
		Scan(&stats)

	// 支付页平均停留时长
	type avgStat struct {
		Page   string  `json:"page"`
		AvgMs  float64 `json:"avg_ms"`
		MaxMs  int64   `json:"max_ms"`
		Total  int64   `json:"total"`
	}
	var avgStats []avgStat
	database.DB.Model(&model.PageEvent{}).
		Select("page, avg(stay_ms) as avg_ms, max(stay_ms) as max_ms, count(*) as total").
		Where("event = 'leave' AND stay_ms > 0").
		Group("page").
		Scan(&avgStats)

	handler.OK(c, gin.H{
		"event_counts": stats,
		"stay_stats":   avgStats,
	})
}
