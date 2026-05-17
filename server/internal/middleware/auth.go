package middleware

import (
	"fmt"
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
			fmt.Printf("[AUTH_MW] invalid token err=%v\n", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "token 无效或已过期"})
			return
		}

		var user model.User
		if err := database.DB.Select("id, status, device_id").First(&user, claims.UserID).Error; err != nil || user.Status == 0 {
			fmt.Printf("[AUTH_MW] user lookup failed user_id=%d device_id=%s err=%v status=%d\n",
				claims.UserID, claims.DeviceID, err, user.Status)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "账号已禁用或不存在"})
			return
		}

		if claims.DeviceID != "" {
			var count int64
			query := database.DB.Model(&model.Device{}).
				Where("device_id = ? AND user_id = ?", claims.DeviceID, claims.UserID)
			if err := query.Count(&count).Error; err != nil {
				fmt.Printf("[AUTH_MW] device count failed user_id=%d device_id=%s err=%v\n",
					claims.UserID, claims.DeviceID, err)
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "设备状态校验失败"})
				return
			}
			fmt.Printf("[AUTH_MW] verify user_id=%d claim_device_id=%s user_device_id=%s count=%d path=%s\n",
				claims.UserID, claims.DeviceID, user.DeviceID, count, c.Request.URL.Path)
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
