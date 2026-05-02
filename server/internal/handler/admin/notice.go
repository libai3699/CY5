package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/ws"

	"github.com/gin-gonic/gin"
)

// ListNotices 通知列表（全部）
func ListNotices(c *gin.Context) {
	var notices []model.Notice
	database.DB.Order("sort_order asc, created_at desc").Find(&notices)
	handler.OK(c, notices)
}

type noticeReq struct {
	TargetUserID *uint64 `json:"target_user_id"`
	Content      string  `json:"content" binding:"required"`
	Type         int8    `json:"type"`
	IsActive     *int8   `json:"is_active"`
	SortOrder    int     `json:"sort_order"`
}

// CreateNotice 新增通知
func CreateNotice(c *gin.Context) {
	var req noticeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	isActive := int8(1)
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	noticeType := req.Type
	if noticeType == 0 {
		noticeType = 1
	}

	notice := model.Notice{
		TargetUserID: req.TargetUserID,
		Content:      req.Content,
		Type:         noticeType,
		IsActive:     isActive,
		SortOrder:    req.SortOrder,
	}
	database.DB.Create(&notice)
	if notice.TargetUserID != nil && notice.IsActive == 1 {
		ws.Notices.Push(*notice.TargetUserID, notice)
	}
	handler.OK(c, notice)
}

// UpdateNotice 编辑通知
func UpdateNotice(c *gin.Context) {
	id := c.Param("id")
	var notice model.Notice
	if err := database.DB.First(&notice, id).Error; err != nil {
		handler.Fail(c, 404, "通知不存在")
		return
	}

	var req noticeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	updates := map[string]interface{}{
		"target_user_id": req.TargetUserID,
		"content":        req.Content,
		"sort_order":     req.SortOrder,
	}
	if req.Type != 0 {
		updates["type"] = req.Type
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}

	database.DB.Model(&notice).Updates(updates)
	handler.OK(c, gin.H{"msg": "更新成功"})
}

// DeleteNotice 删除通知
func DeleteNotice(c *gin.Context) {
	id := c.Param("id")
	database.DB.Delete(&model.Notice{}, id)
	handler.OK(c, gin.H{"msg": "删除成功"})
}
