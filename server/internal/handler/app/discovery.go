package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListDiscoveryItems returns enabled H5 applications for the client.
func ListDiscoveryItems(c *gin.Context) {
	items := make([]model.DiscoveryItem, 0)
	if err := database.DB.Where("is_active = ?", 1).
		Order("sort_order asc, id asc").Find(&items).Error; err != nil {
		handler.Fail(c, 500, "获取发现列表失败")
		return
	}
	handler.OK(c, items)
}
