package admin

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/ws"

	"github.com/gin-gonic/gin"
)

type lineReq struct {
	Name        string `json:"name" binding:"required"`
	Region      string `json:"region"`
	Protocol    string `json:"protocol" binding:"required"`
	Address     string `json:"address" binding:"required"`
	RawURI      string `json:"raw_uri" binding:"required"`
	SortOrder   int    `json:"sort_order"`
	IsDefault   *int8  `json:"is_default"`
	IsActive    *int8  `json:"is_active"`
	Description string `json:"description"`
}

type assignLineReq struct {
	UserID uint64 `json:"user_id" binding:"required"`
	LineID uint   `json:"line_id" binding:"required"`
	Notice string `json:"notice"`
}

func ListLines(c *gin.Context) {
	var lines []model.VpnLine
	database.DB.Order("sort_order asc, id asc").Find(&lines)
	handler.OK(c, lines)
}

func CreateLine(c *gin.Context) {
	var req lineReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误: "+err.Error())
		return
	}

	line := model.VpnLine{
		Name:        req.Name,
		Region:      req.Region,
		Protocol:    req.Protocol,
		Address:     req.Address,
		RawURI:      req.RawURI,
		SortOrder:   req.SortOrder,
		IsDefault:   valueOrDefault(req.IsDefault, 0),
		IsActive:    valueOrDefault(req.IsActive, 1),
		Description: req.Description,
	}
	if line.IsDefault == 1 {
		database.DB.Model(&model.VpnLine{}).Where("is_default = 1").Update("is_default", 0)
	}
	database.DB.Create(&line)
	handler.OK(c, line)
}

func UpdateLine(c *gin.Context) {
	id := c.Param("id")
	var line model.VpnLine
	if err := database.DB.First(&line, id).Error; err != nil {
		handler.Fail(c, 404, "线路不存在")
		return
	}

	var req lineReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	isDefault := valueOrDefault(req.IsDefault, line.IsDefault)
	if isDefault == 1 {
		database.DB.Model(&model.VpnLine{}).Where("id <> ?", line.ID).Update("is_default", 0)
	}

	database.DB.Model(&line).Updates(map[string]interface{}{
		"name":        req.Name,
		"region":      req.Region,
		"protocol":    req.Protocol,
		"address":     req.Address,
		"raw_uri":     req.RawURI,
		"sort_order":  req.SortOrder,
		"is_default":  isDefault,
		"is_active":   valueOrDefault(req.IsActive, line.IsActive),
		"description": req.Description,
	})
	handler.OK(c, gin.H{"msg": "更新成功"})
}

func DeleteLine(c *gin.Context) {
	id := c.Param("id")
	database.DB.Delete(&model.VpnLine{}, id)
	handler.OK(c, gin.H{"msg": "删除成功"})
}

func AssignUserLine(c *gin.Context) {
	var req assignLineReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	var line model.VpnLine
	if err := database.DB.Where("id = ? AND is_active = 1", req.LineID).First(&line).Error; err != nil {
		handler.Fail(c, 404, "线路不存在或已停用")
		return
	}

	var user model.User
	if err := database.DB.First(&user, req.UserID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	database.DB.Model(&user).Update("current_line_id", req.LineID)
	content := req.Notice
	if content == "" {
		content = "你的 VPN 线路已切换为：" + line.Name
	}
	notice := model.Notice{TargetUserID: &req.UserID, Content: content, Type: 2, IsActive: 1, SortOrder: 0}
	database.DB.Create(&notice)
	ws.Notices.Push(req.UserID, notice)

	handler.OK(c, gin.H{"msg": "线路已切换", "line": line})
}

func valueOrDefault(value *int8, fallback int8) int8 {
	if value == nil {
		return fallback
	}
	return *value
}
