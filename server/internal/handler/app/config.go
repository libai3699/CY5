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

// GetContactConfig 只返回联系方式配置（key_name 以 contact_ 开头）
func GetContactConfig(c *gin.Context) {
	var configs []model.AppConfig
	database.DB.Where("key_name LIKE ?", "contact_%").Order("sort_order asc").Find(&configs)

	type contactItem struct {
		Key   string `json:"key"`
		Label string `json:"label"`
		Value string `json:"value"`
	}

	items := make([]contactItem, 0, len(configs))
	for _, cfg := range configs {
		items = append(items, contactItem{
			Key:   cfg.KeyName,
			Label: cfg.Label,
			Value: cfg.Value,
		})
	}

	handler.OK(c, items)
}
