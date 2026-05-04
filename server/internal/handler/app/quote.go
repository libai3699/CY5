package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetRandomQuote 获取随机一条语录
func GetRandomQuote(c *gin.Context) {
	var quote model.Quote
	// 从启用的语录中随机获取一条
	err := database.DB.Where("is_active = 1").Order("RAND()").First(&quote).Error
	if err != nil {
		handler.Fail(c, 404, "暂无语录")
		return
	}
	handler.OK(c, quote)
}
