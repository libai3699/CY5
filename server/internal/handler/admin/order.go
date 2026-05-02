package admin

import (
	"strconv"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListOrders 订单列表
func ListOrders(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))

	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}

	var total int64
	database.DB.Model(&model.OrderRecord{}).Count(&total)

	var orders []model.OrderRecord
	database.DB.Order("created_at desc").
		Offset((page - 1) * size).
		Limit(size).
		Find(&orders)

	handler.OK(c, gin.H{
		"total": total,
		"page":  page,
		"size":  size,
		"list":  orders,
	})
}

type manualOrderReq struct {
	UserID uint64 `json:"user_id" binding:"required"`
	PlanID uint   `json:"plan_id" binding:"required"`
	Remark string `json:"remark"`
}

// CreateOrder 手动开通套餐
func CreateOrder(c *gin.Context) {
	var req manualOrderReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	var user model.User
	if err := database.DB.First(&user, req.UserID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	var plan model.Plan
	if err := database.DB.First(&plan, req.PlanID).Error; err != nil {
		handler.Fail(c, 404, "套餐不存在")
		return
	}

	now := time.Now()
	expiredAt := now.AddDate(0, 0, plan.DurationDays)

	// 计算流量上限（字节）
	var trafficLimit *int64
	if plan.TrafficGB != nil {
		bytes := int64(*plan.TrafficGB) * 1024 * 1024 * 1024
		trafficLimit = &bytes
	}

	// 创建订单记录
	order := model.OrderRecord{
		UserID:       req.UserID,
		PlanID:       req.PlanID,
		PlanName:     plan.Name,
		PlanPrice:    plan.Price,
		TrafficGB:    plan.TrafficGB,
		DurationDays: plan.DurationDays,
		StartedAt:    now,
		ExpiredAt:    expiredAt,
		PayMethod:    "manual",
		Remark:       req.Remark,
	}
	database.DB.Create(&order)

	// 更新用户当前套餐
	database.DB.Model(&user).Updates(map[string]interface{}{
		"current_plan_id":     plan.ID,
		"plan_expired_at":     expiredAt,
		"traffic_used_bytes":  0,
		"traffic_limit_bytes": trafficLimit,
	})

	handler.OK(c, gin.H{"msg": "开通成功", "order": order})
}
