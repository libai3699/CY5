package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

func GetDefaultLine(c *gin.Context) {
	line, ok := findDefaultLine()
	if !ok {
		handler.Fail(c, 404, "暂无可用线路")
		return
	}
	handler.OK(c, line)
}

type publicLine struct {
	ID          uint   `json:"id"`
	Name        string `json:"name"`
	Region      string `json:"region"`
	Protocol    string `json:"protocol"`
	Address     string `json:"address"`
	RawURI      string `json:"raw_uri"`
	Description string `json:"description"`
}

func GetPublicDefaultLine(c *gin.Context) {
	line, ok := findDefaultLine()
	if !ok {
		handler.Fail(c, 404, "暂无可用线路")
		return
	}
	handler.OK(c, publicLine{
		ID:          line.ID,
		Name:        line.Name,
		Region:      line.Region,
		Protocol:    line.Protocol,
		Address:     line.Address,
		RawURI:      line.RawURI,
		Description: line.Description,
	})
}

func GetUserLine(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	if user.CurrentLineID != nil {
		var line model.VpnLine
		if err := database.DB.Where("id = ? AND is_active = 1", *user.CurrentLineID).First(&line).Error; err == nil {
			handler.OK(c, line)
			return
		}
	}

	line, ok := findDefaultLine()
	if !ok {
		handler.Fail(c, 404, "暂无可用线路")
		return
	}
	database.DB.Model(&user).Update("current_line_id", line.ID)
	handler.OK(c, line)
}

func findDefaultLine() (model.VpnLine, bool) {
	var line model.VpnLine
	if err := database.DB.Where("is_active = 1 AND is_default = 1").Order("sort_order asc, id asc").First(&line).Error; err == nil {
		return line, true
	}
	if err := database.DB.Where("is_active = 1").Order("sort_order asc, id asc").First(&line).Error; err == nil {
		return line, true
	}
	return line, false
}
