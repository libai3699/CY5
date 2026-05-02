package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

func ListConfigs(c *gin.Context) {
	var configs []model.AppConfig
	database.DB.Order("sort_order asc").Find(&configs)
	handler.OK(c, configs)
}

type createConfigReq struct {
	KeyName   string `json:"key_name" binding:"required"`
	Value     string `json:"value"`
	Label     string `json:"label" binding:"required"`
	SortOrder int    `json:"sort_order"`
}

func CreateConfig(c *gin.Context) {
	var req createConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误: "+err.Error())
		return
	}

	cfg := model.AppConfig{
		KeyName:   req.KeyName,
		Value:     req.Value,
		Label:     req.Label,
		SortOrder: req.SortOrder,
	}
	if err := database.DB.Create(&cfg).Error; err != nil {
		handler.Fail(c, 400, "配置键已存在或保存失败")
		return
	}
	handler.OK(c, cfg)
}

type updateConfigReq struct {
	Value string `json:"value"`
}

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
