package app

import (
	"time"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type registerReq struct {
	Username string `json:"username" binding:"required,min=3,max=32"`
	Password string `json:"password" binding:"required,min=6,max=64"`
	DeviceID string `json:"device_id" binding:"required"`
	Phone    string `json:"phone"`
}

// Register 用户注册
func Register(c *gin.Context) {
	var req registerReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误: "+err.Error())
		return
	}

	// 检查用户名是否已存在
	var count int64
	database.DB.Model(&model.User{}).Where("username = ?", req.Username).Count(&count)
	if count > 0 {
		handler.Fail(c, 1001, "用户名已存在")
		return
	}

	// 哈希密码
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		handler.Fail(c, 500, "服务器错误")
		return
	}

	user := model.User{
		Username:         req.Username,
		Password:         string(hash),
		Phone:            req.Phone,
		DeviceID:         req.DeviceID,
		Status:           1,
		FreeUsedSeconds:  0,
		FreeLimitSeconds: 2700,
	}
	if err := database.DB.Create(&user).Error; err != nil {
		handler.Fail(c, 500, "注册失败")
		return
	}

	// 注册成功，直接签发 token（自动登录）
	token, err := config.GenerateUserToken(user.ID, user.DeviceID)
	if err != nil {
		handler.Fail(c, 500, "token 生成失败")
		return
	}

	// 记录登录日志
	writeUserLoginLog(c, user.ID, req.DeviceID, 1, "")

	handler.OK(c, gin.H{
		"token": token,
		"user":  safeUser(user),
	})
}

type loginReq struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	DeviceID string `json:"device_id"`
}

// Login 用户登录
func Login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	var user model.User
	if err := database.DB.Where("username = ?", req.Username).First(&user).Error; err != nil {
		writeUserLoginLog(c, 0, req.DeviceID, 0, "用户不存在")
		handler.Fail(c, 1002, "用户名或密码错误")
		return
	}

	if user.Status == 0 {
		handler.Fail(c, 1003, "账号已被禁用")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		writeUserLoginLog(c, user.ID, req.DeviceID, 0, "密码错误")
		handler.Fail(c, 1002, "用户名或密码错误")
		return
	}

	// 更新最后登录时间和设备
	now := time.Now()
	updates := map[string]interface{}{"last_login_at": now}
	if req.DeviceID != "" {
		updates["device_id"] = req.DeviceID
	}
	database.DB.Model(&user).Updates(updates)

	token, err := config.GenerateUserToken(user.ID, user.DeviceID)
	if err != nil {
		handler.Fail(c, 500, "token 生成失败")
		return
	}

	writeUserLoginLog(c, user.ID, req.DeviceID, 1, "")

	handler.OK(c, gin.H{
		"token": token,
		"user":  safeUser(user),
	})
}

// safeUser 返回安全的用户信息（不含密码）
func safeUser(u model.User) gin.H {
	return gin.H{
		"id":                   u.ID,
		"username":             u.Username,
		"phone":                u.Phone,
		"device_id":            u.DeviceID,
		"free_used_seconds":    u.FreeUsedSeconds,
		"free_limit_seconds":   u.FreeLimitSeconds,
		"free_remaining":       u.FreeLimitSeconds - u.FreeUsedSeconds,
		"current_plan_id":      u.CurrentPlanID,
		"plan_expired_at":      u.PlanExpiredAt,
		"traffic_used_bytes":   u.TrafficUsedBytes,
		"traffic_limit_bytes":  u.TrafficLimitBytes,
		"status":               u.Status,
	}
}

func writeUserLoginLog(c *gin.Context, userID uint64, deviceID string, status int8, reason string) {
	log := model.UserLoginLog{
		UserID:     userID,
		DeviceID:   deviceID,
		IP:         c.ClientIP(),
		AppVersion: c.GetHeader("X-App-Version"),
		Status:     status,
		FailReason: reason,
	}
	database.DB.Create(&log)
}
