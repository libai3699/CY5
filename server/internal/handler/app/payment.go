package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetPaymentConfigs 获取支付配置列表（只返回启用的）
func GetPaymentConfigs(c *gin.Context) {
	var configs []model.PaymentConfig
	database.DB.Where("is_active = 1").Order("sort_order asc").Find(&configs)
	handler.OK(c, configs)
}
