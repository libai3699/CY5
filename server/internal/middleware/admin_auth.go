package middleware

import (
	"net/http"

	"cy5vpn/server/internal/config"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

type AdminClaims struct {
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

// AdminAuthRequired 后台管理员 JWT 验证
func AdminAuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractToken(c)
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "未登录"})
			return
		}

		claims := &AdminClaims{}
		t, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (interface{}, error) {
			return []byte(config.App.AdminJWTSecret), nil
		})
		if err != nil || !t.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"code": 401, "message": "token 无效或已过期"})
			return
		}

		c.Set("admin_username", claims.Username)
		c.Set("admin_role", claims.Role)
		c.Next()
	}
}

func AdminRequireRole(roles ...string) gin.HandlerFunc {
	allowed := map[string]bool{}
	for _, role := range roles {
		allowed[role] = true
	}
	return func(c *gin.Context) {
		role := c.GetString("admin_role")
		if !allowed[role] {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"code": 403, "message": "权限不足"})
			return
		}
		c.Next()
	}
}
