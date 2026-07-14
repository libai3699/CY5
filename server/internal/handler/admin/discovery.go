package admin

import (
	"net/url"
	"strings"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

type discoveryItemReq struct {
	Name      string `json:"name" binding:"required"`
	IconURL   string `json:"icon_url" binding:"required"`
	H5URL     string `json:"h5_url" binding:"required"`
	IsActive  *int8  `json:"is_active"`
	SortOrder int    `json:"sort_order"`
}

func validHTTPURL(value string) bool {
	parsed, err := url.ParseRequestURI(strings.TrimSpace(value))
	return err == nil && parsed.Host != "" && (parsed.Scheme == "http" || parsed.Scheme == "https")
}

func validateDiscoveryItem(c *gin.Context, req *discoveryItemReq) bool {
	req.Name = strings.TrimSpace(req.Name)
	req.IconURL = strings.TrimSpace(req.IconURL)
	req.H5URL = strings.TrimSpace(req.H5URL)
	if req.Name == "" || !validHTTPURL(req.IconURL) || !validHTTPURL(req.H5URL) {
		handler.Fail(c, 400, "请填写名称以及有效的 http/https 图标和 H5 地址")
		return false
	}
	return true
}

func ListDiscoveryItems(c *gin.Context) {
	items := make([]model.DiscoveryItem, 0)
	if err := database.DB.Order("sort_order asc, id asc").Find(&items).Error; err != nil {
		handler.Fail(c, 500, "获取发现列表失败")
		return
	}
	handler.OK(c, items)
}

func CreateDiscoveryItem(c *gin.Context) {
	var req discoveryItemReq
	if err := c.ShouldBindJSON(&req); err != nil || !validateDiscoveryItem(c, &req) {
		if err != nil {
			handler.Fail(c, 400, "参数错误")
		}
		return
	}
	isActive := int8(1)
	if req.IsActive != nil {
		isActive = *req.IsActive
	}
	item := model.DiscoveryItem{Name: req.Name, IconURL: req.IconURL, H5URL: req.H5URL, IsActive: isActive, SortOrder: req.SortOrder}
	if err := database.DB.Create(&item).Error; err != nil {
		handler.Fail(c, 500, "创建失败")
		return
	}
	handler.OK(c, item)
}

func UpdateDiscoveryItem(c *gin.Context) {
	var item model.DiscoveryItem
	if err := database.DB.First(&item, c.Param("id")).Error; err != nil {
		handler.Fail(c, 404, "发现项不存在")
		return
	}
	var req discoveryItemReq
	if err := c.ShouldBindJSON(&req); err != nil || !validateDiscoveryItem(c, &req) {
		if err != nil {
			handler.Fail(c, 400, "参数错误")
		}
		return
	}
	updates := map[string]interface{}{"name": req.Name, "icon_url": req.IconURL, "h5_url": req.H5URL, "sort_order": req.SortOrder}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	if err := database.DB.Model(&item).Updates(updates).Error; err != nil {
		handler.Fail(c, 500, "更新失败")
		return
	}
	handler.OK(c, gin.H{"msg": "更新成功"})
}

func DeleteDiscoveryItem(c *gin.Context) {
	result := database.DB.Delete(&model.DiscoveryItem{}, c.Param("id"))
	if result.Error != nil {
		handler.Fail(c, 500, "删除失败")
		return
	}
	if result.RowsAffected == 0 {
		handler.Fail(c, 404, "发现项不存在")
		return
	}
	handler.OK(c, gin.H{"msg": "删除成功"})
}
