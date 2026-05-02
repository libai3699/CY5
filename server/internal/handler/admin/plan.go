package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListPlans 套餐列表（全部）
func ListPlans(c *gin.Context) {
	var plans []model.Plan
	database.DB.Order("sort_order asc").Find(&plans)
	handler.OK(c, plans)
}

type planReq struct {
	Name             string   `json:"name" binding:"required"`
	Price            float64  `json:"price" binding:"required"`
	TrafficGB        *int     `json:"traffic_gb"`
	DurationDays     int      `json:"duration_days" binding:"required"`
	MaxDevices       int      `json:"max_devices"`
	SortOrder        int      `json:"sort_order"`
	IsActive         *int8    `json:"is_active"`
	DiscountQuarter  *float64 `json:"discount_quarter"`   // 季付折扣率，如 0.95
	DiscountHalfYear *float64 `json:"discount_half_year"` // 半年付折扣率
	DiscountYear     *float64 `json:"discount_year"`      // 年付折扣率
}

// CreatePlan 新增套餐
func CreatePlan(c *gin.Context) {
	var req planReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误: "+err.Error())
		return
	}

	isActive := int8(1)
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	if req.MaxDevices < 1 {
		req.MaxDevices = 1
	}

	plan := model.Plan{
		Name:             req.Name,
		Price:            req.Price,
		TrafficGB:        req.TrafficGB,
		DurationDays:     req.DurationDays,
		MaxDevices:       req.MaxDevices,
		SortOrder:        req.SortOrder,
		IsActive:         isActive,
		DiscountQuarter:  req.DiscountQuarter,
		DiscountHalfYear: req.DiscountHalfYear,
		DiscountYear:     req.DiscountYear,
	}
	database.DB.Create(&plan)
	handler.OK(c, plan)
}

// UpdatePlan 编辑套餐
func UpdatePlan(c *gin.Context) {
	id := c.Param("id")
	var plan model.Plan
	if err := database.DB.First(&plan, id).Error; err != nil {
		handler.Fail(c, 404, "套餐不存在")
		return
	}

	var req planReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}
	if req.MaxDevices < 1 {
		req.MaxDevices = 1
	}

	updates := map[string]interface{}{
		"name":               req.Name,
		"price":              req.Price,
		"traffic_gb":         req.TrafficGB,
		"duration_days":      req.DurationDays,
		"max_devices":        req.MaxDevices,
		"sort_order":         req.SortOrder,
		"discount_quarter":   req.DiscountQuarter,
		"discount_half_year": req.DiscountHalfYear,
		"discount_year":      req.DiscountYear,
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	database.DB.Model(&plan).Updates(updates)
	handler.OK(c, gin.H{"msg": "更新成功"})
}

// DeletePlan 删除套餐
func DeletePlan(c *gin.Context) {
	id := c.Param("id")
	database.DB.Delete(&model.Plan{}, id)
	handler.OK(c, gin.H{"msg": "删除成功"})
}
