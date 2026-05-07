package middleware

import (
	"net/http"
	"strings"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

type UserClaims struct {
	UserID   uint64 `json:"user_id"`
	DeviceID string `json:"device_id"`
	jwt.RegisteredClaims
}

// AuthRequired 前台用户 JWT 验证
func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractToken(c)
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "未登录"})
			return
		}

		claims := &UserClaims{}
		t, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (interface{}, error) {
			return []byte(config.App.JWTSecret), nil
		})
		if err != nil || !t.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "token 无效或已过期"})
			return
		}
		var user model.User
		if err := database.DB.Select("id, status").First(&user, claims.UserID).Error; err != nil || user.Status == 0 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "账号已禁用或不存在"})
			return
		}
		if claims.DeviceID != "" {
			var count int64
			database.DB.Model(&model.Device{}).Where("device_id = ? AND user_id = ?", claims.DeviceID, claims.UserID).Count(&count)
			if count == 0 {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "设备已退出，请重新登录"})
				return
			}
		}

		c.Set("user_id", claims.UserID)
		c.Set("device_id", claims.DeviceID)
		c.Next()
	}
}

func extractToken(c *gin.Context) string {
	bearer := c.GetHeader("Authorization")
	if strings.HasPrefix(bearer, "Bearer ") {
		return strings.TrimPrefix(bearer, "Bearer ")
	}
	return ""
}
