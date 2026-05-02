package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetPlans 获取套餐列表（只返回上架的）
func GetPlans(c *gin.Context) {
	var plans []model.Plan
	database.DB.Where("is_active = 1").Order("sort_order asc").Find(&plans)
	handler.OK(c, plans)
}
