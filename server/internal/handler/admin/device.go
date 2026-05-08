package admin

import (
	"strconv"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// ListDevices 设备列表
func ListDevices(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	keyword := c.Query("keyword")

	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}

	query := database.DB.Model(&model.Device{})
	if keyword != "" {
		query = query.Where("device_id LIKE ? OR brand LIKE ? OR model LIKE ?",
			"%"+keyword+"%", "%"+keyword+"%", "%"+keyword+"%")
	}

	var total int64
	query.Count(&total)

	var devices []model.Device
	query.Order("last_seen_at desc").
		Offset((page - 1) * size).
		Limit(size).
		Find(&devices)

	result := make([]gin.H, 0, len(devices))
	for _, device := range devices {
		result = append(result, gin.H{
			"id":             device.ID,
			"device_id":      device.DeviceID,
			"display_id":     device.DisplayID,
			"user_id":        device.UserID,
			"brand":          device.Brand,
			"model":          device.Model,
			"os_version":     device.OSVersion,
			"app_version":    device.AppVersion,
			"last_ip":        device.LastIP,
			"last_ip_detail": describeIP(device.LastIP),
			"last_seen_at":   device.LastSeenAt,
			"created_at":     device.CreatedAt,
			"updated_at":     device.UpdatedAt,
		})
	}

	handler.OK(c, gin.H{
		"total": total,
		"page":  page,
		"size":  size,
		"list":  result,
	})
}

// GetDevice 设备详情
func GetDevice(c *gin.Context) {
	id := c.Param("id")
	var device model.Device
	if err := database.DB.First(&device, id).Error; err != nil {
		handler.Fail(c, 404, "设备不存在")
		return
	}
	handler.OK(c, gin.H{
		"id":             device.ID,
		"device_id":      device.DeviceID,
		"display_id":     device.DisplayID,
		"user_id":        device.UserID,
		"brand":          device.Brand,
		"model":          device.Model,
		"os_version":     device.OSVersion,
		"app_version":    device.AppVersion,
		"last_ip":        device.LastIP,
		"last_ip_detail": describeIP(device.LastIP),
		"last_seen_at":   device.LastSeenAt,
		"created_at":     device.CreatedAt,
		"updated_at":     device.UpdatedAt,
	})
}
