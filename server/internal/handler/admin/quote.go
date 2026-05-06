package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListQuotes 语录列表（全部）
func ListQuotes(c *gin.Context) {
	var quotes []model.Quote
	database.DB.Order("sort_order asc, created_at desc").Find(&quotes)
	handler.OK(c, quotes)
}

type quoteReq struct {
	Content   string `json:"content" binding:"required"`
	Author    string `json:"author"`
	IsActive  *int8  `json:"is_active"`
	SortOrder int    `json:"sort_order"`
}

// CreateQuote 新增语录
func CreateQuote(c *gin.Context) {
	var req quoteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	isActive := int8(1)
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	quote := model.Quote{
		Content:   req.Content,
		Author:    req.Author,
		IsActive:  isActive,
		SortOrder: req.SortOrder,
	}
	database.DB.Create(&quote)
	handler.OK(c, quote)
}

// UpdateQuote 编辑语录
func UpdateQuote(c *gin.Context) {
	id := c.Param("id")
	var quote model.Quote
	if err := database.DB.First(&quote, id).Error; err != nil {
		handler.Fail(c, 404, "语录不存在")
		return
	}

	var req quoteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	updates := map[string]interface{}{
		"content":    req.Content,
		"author":     req.Author,
		"sort_order": req.SortOrder,
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	database.DB.Model(&quote).Updates(updates)
	handler.OK(c, gin.H{"msg": "更新成功"})
}

// DeleteQuote 删除语录
func DeleteQuote(c *gin.Context) {
	id := c.Param("id")
	result := database.DB.Delete(&model.Quote{}, id)
	if result.Error != nil {
		handler.Fail(c, 500, "删除失败")
		return
	}
	if result.RowsAffected == 0 {
		handler.Fail(c, 404, "语录不存在")
		return
	}
	handler.OK(c, gin.H{"msg": "删除成功"})
}
