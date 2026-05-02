package config

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// GenerateUserToken 生成前台用户 JWT（7天）
func GenerateUserToken(userID uint64, deviceID string) (string, error) {
	claims := jwt.MapClaims{
		"user_id":   userID,
		"device_id": deviceID,
		"exp":       time.Now().Add(7 * 24 * time.Hour).Unix(),
		"iat":       time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(App.JWTSecret))
}

// GenerateAdminToken 生成后台管理员 JWT（24小时）
func GenerateAdminToken(username string) (string, error) {
	claims := jwt.MapClaims{
		"username": username,
		"exp":      time.Now().Add(24 * time.Hour).Unix(),
		"iat":      time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(App.AdminJWTSecret))
}
