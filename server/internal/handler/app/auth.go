package app

import (
	"regexp"
	"time"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type registerReq struct {
	Username string `json:"username" binding:"required,min=6,max=32"`
	Password string `json:"password" binding:"required,min=6,max=64"`
	DeviceID string `json:"device_id" binding:"required"`
	Phone    string `json:"phone"`
}

var (
	usernameLetterRE = regexp.MustCompile(`[A-Za-z]`)
	usernameDigitRE  = regexp.MustCompile(`\d`)
)

func Register(c *gin.Context) {
	var req registerReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误: "+err.Error())
		return
	}
	if !usernameLetterRE.MatchString(req.Username) || !usernameDigitRE.MatchString(req.Username) {
		handler.Fail(c, 400, "账号至少6位，且必须同时包含字母和数字")
		return
	}

	var count int64
	database.DB.Model(&model.User{}).Where("username = ?", req.Username).Count(&count)
	if count > 0 {
		handler.Fail(c, 1001, "用户名已存在")
		return
	}

	var deviceUserCount int64
	database.DB.Model(&model.User{}).Where("device_id = ?", req.DeviceID).Count(&deviceUserCount)
	if deviceUserCount >= 3 {
		handler.Fail(c, 1004, "本设备最多只能注册 3 个账号，请联系客服")
		return
	}

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
	updateDeviceUser(req.DeviceID, user.ID)

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

type loginReq struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	DeviceID string `json:"device_id"`
}

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

	now := time.Now()
	updates := map[string]interface{}{"last_login_at": now}
	if req.DeviceID != "" {
		if !canLoginDevice(user, req.DeviceID) {
			handler.Fail(c, 1005, "登录设备数量已达当前套餐上限，请先移除其他设备")
			return
		}
		updates["device_id"] = req.DeviceID
	}
	database.DB.Model(&user).Updates(updates)
	if req.DeviceID != "" {
		updateDeviceUser(req.DeviceID, user.ID)
		user.DeviceID = req.DeviceID
	}

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

func updateDeviceUser(deviceID string, userID uint64) {
	if deviceID == "" {
		return
	}
	database.DB.Model(&model.Device{}).Where("device_id = ?", deviceID).Update("user_id", userID)
}

func canLoginDevice(user model.User, deviceID string) bool {
	var bound model.Device
	if err := database.DB.Where("device_id = ? AND user_id = ?", deviceID, user.ID).First(&bound).Error; err == nil {
		return true
	}

	maxDevices := 1
	if user.CurrentPlanID != nil && user.PlanExpiredAt != nil && user.PlanExpiredAt.After(time.Now()) {
		var plan model.Plan
		if err := database.DB.First(&plan, *user.CurrentPlanID).Error; err == nil && plan.MaxDevices > 0 {
			maxDevices = plan.MaxDevices
		}
	}

	var count int64
	database.DB.Model(&model.Device{}).Where("user_id = ?", user.ID).Count(&count)
	return count < int64(maxDevices)
}

func safeUser(u model.User) gin.H {
	return gin.H{
		"id":                  u.ID,
		"username":            u.Username,
		"phone":               u.Phone,
		"device_id":           u.DeviceID,
		"free_used_seconds":   u.FreeUsedSeconds,
		"free_limit_seconds":  u.FreeLimitSeconds,
		"free_remaining":      freeRemaining(u),
		"current_plan_id":     u.CurrentPlanID,
		"plan_expired_at":     u.PlanExpiredAt,
		"traffic_used_bytes":  u.TrafficUsedBytes,
		"traffic_limit_bytes": u.TrafficLimitBytes,
		"status":              u.Status,
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
