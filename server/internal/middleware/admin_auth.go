package middleware

import (
	"net/http"

	"cy5vpn/server/internal/config"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

type AdminClaims struct {
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// AdminAuthRequired 后台管理员 JWT 验证
func AdminAuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractToken(c)
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "msg": "未登录"})
			return
		}

		claims := &AdminClaims{}
		t, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (interface{}, error) {
			return []byte(config.App.AdminJWTSecret), nil
		})
		if err != nil || !t.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "msg": "token 无效或已过期"})
			return
		}

		c.Set("admin_username", claims.Username)
		c.Next()
	}
}
