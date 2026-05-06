package app

import (
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"strings"

	"github.com/gin-gonic/gin"
)

// GetPaymentConfigs 获取支付配置列表（只返回启用的）
func GetPaymentConfigs(c *gin.Context) {
	var configs []model.PaymentConfig
	database.DB.Where("is_active = 1").Order("sort_order asc").Find(&configs)
	for i := range configs {
		configs[i].QRCode = absoluteUploadURL(c, configs[i].QRCode)
	}
	handler.OK(c, configs)
}

func absoluteUploadURL(c *gin.Context, value string) string {
	if value == "" || strings.HasPrefix(value, "http://") || strings.HasPrefix(value, "https://") {
		return value
	}
	if !strings.HasPrefix(value, "/") {
		value = "/" + value
	}
	proto := c.GetHeader("X-Forwarded-Proto")
	if proto == "" {
		if c.Request.TLS != nil {
			proto = "https"
		} else {
			proto = "http"
		}
	}
	host := c.GetHeader("X-Forwarded-Host")
	if host == "" {
		host = c.Request.Host
	}
	if proto == "http" && !strings.HasPrefix(host, "localhost") && !strings.HasPrefix(host, "127.0.0.1") {
		proto = "https"
	}
	return proto + "://" + host + value
}
