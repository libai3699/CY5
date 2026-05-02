package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListConfigs 配置列表
func ListConfigs(c *gin.Context) {
	var configs []model.AppConfig
	database.DB.Order("sort_order asc").Find(&configs)
	handler.OK(c, configs)
}

type updateConfigReq struct {
	Value string `json:"value"`
}

// UpdateConfig 更新配置
func UpdateConfig(c *gin.Context) {
	key := c.Param("key")

	var cfg model.AppConfig
	if err := database.DB.Where("key_name = ?", key).First(&cfg).Error; err != nil {
		handler.Fail(c, 404, "配置项不存在")
		return
	}

	var req updateConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	database.DB.Model(&cfg).Update("value", req.Value)
	handler.OK(c, gin.H{"msg": "更新成功"})
}
