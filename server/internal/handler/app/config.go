package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetConfig 获取 App 公共配置（订阅链接、联系方式、下载链接）
func GetConfig(c *gin.Context) {
	var configs []model.AppConfig
	database.DB.Order("sort_order asc").Find(&configs)

	result := make(map[string]string)
	for _, cfg := range configs {
		result[cfg.KeyName] = cfg.Value
	}

	handler.OK(c, result)
}
