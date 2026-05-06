package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListPaymentConfigs 支付配置列表
func ListPaymentConfigs(c *gin.Context) {
	var configs []model.PaymentConfig
	database.DB.Order("sort_order asc").Find(&configs)
	for i := range configs {
		configs[i].QRCode = absoluteUploadURL(c, configs[i].QRCode)
	}
	handler.OK(c, configs)
}

type paymentConfigReq struct {
	Type      string `json:"type" binding:"required"`
	Label     string `json:"label" binding:"required"`
	Address   string `json:"address"`
	QRCode    string `json:"qr_code"`
	IsActive  *int8  `json:"is_active"`
	SortOrder int    `json:"sort_order"`
	Remark    string `json:"remark"`
}

// CreatePaymentConfig 新增支付配置
func CreatePaymentConfig(c *gin.Context) {
	var req paymentConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	isActive := int8(1)
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	config := model.PaymentConfig{
		Type:      req.Type,
		Label:     req.Label,
		Address:   req.Address,
		QRCode:    req.QRCode,
		IsActive:  isActive,
		SortOrder: req.SortOrder,
		Remark:    req.Remark,
	}
	database.DB.Create(&config)
	config.QRCode = absoluteUploadURL(c, config.QRCode)
	handler.OK(c, config)
}

// UpdatePaymentConfig 编辑支付配置
func UpdatePaymentConfig(c *gin.Context) {
	id := c.Param("id")
	var config model.PaymentConfig
	if err := database.DB.First(&config, id).Error; err != nil {
		handler.Fail(c, 404, "支付配置不存在")
		return
	}

	var req paymentConfigReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	updates := map[string]interface{}{
		"type":       req.Type,
		"label":      req.Label,
		"address":    req.Address,
		"qr_code":    req.QRCode,
		"sort_order": req.SortOrder,
		"remark":     req.Remark,
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	database.DB.Model(&config).Updates(updates)
	handler.OK(c, gin.H{"msg": "更新成功"})
}

// DeletePaymentConfig 删除支付配置
func DeletePaymentConfig(c *gin.Context) {
	id := c.Param("id")
	database.DB.Delete(&model.PaymentConfig{}, id)
	handler.OK(c, gin.H{"msg": "删除成功"})
}
