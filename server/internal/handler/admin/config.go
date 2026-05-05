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

	var req updateConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	// 用 map 强制更新，避免 GORM 对空字符串零值跳过更新的问题
	result := database.DB.Model(&model.AppConfig{}).
		Where("key_name = ?", key).
		Updates(map[string]interface{}{"value": req.Value})
	if result.Error != nil {
		handler.Fail(c, 500, "保存失败: "+result.Error.Error())
		return
	}
	if result.RowsAffected == 0 {
		handler.Fail(c, 404, "配置项不存在")
		return
	}

	var cfg model.AppConfig
	database.DB.Where("key_name = ?", key).First(&cfg)
	handler.OK(c, gin.H{"msg": "更新成功", "config": cfg})
}
