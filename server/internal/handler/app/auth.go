package app

import (
	"errors"
	"fmt"
	"regexp"
	"time"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
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
	if !usernameLetterRE.MatchString(req.Username) ||
		!usernameDigitRE.MatchString(req.Username) {
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

	var existingCount int64
	database.DB.Model(&model.User{}).Where("device_id = ?", req.DeviceID).Count(&existingCount)
	freeLimitSeconds := 0
	if existingCount == 0 {
		freeLimitSeconds = 2700
	}

	user := model.User{
		Username:         req.Username,
		Password:         string(hash),
		Phone:            req.Phone,
		DeviceID:         req.DeviceID,
		Status:           1,
		FreeUsedSeconds:  0,
		FreeLimitSeconds: freeLimitSeconds,
	}
	if err := database.DB.Create(&user).Error; err != nil {
		handler.Fail(c, 500, "注册失败")
		return
	}
	if err := bindDeviceToUser(req.DeviceID, user.ID); err != nil {
		fmt.Printf("[AUTH_BIND] register bind failed user_id=%d device_id=%s err=%v\n",
			user.ID, req.DeviceID, err)
		handler.Fail(c, 500, "设备绑定失败")
		return
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
	if err := database.DB.Model(&user).Updates(updates).Error; err != nil {
		fmt.Printf("[AUTH_BIND] user update failed user_id=%d device_id=%s err=%v\n",
			user.ID, req.DeviceID, err)
		handler.Fail(c, 500, "登录失败")
		return
	}
	if req.DeviceID != "" {
		if err := bindDeviceToUser(req.DeviceID, user.ID); err != nil {
			fmt.Printf("[AUTH_BIND] login bind failed user_id=%d device_id=%s err=%v\n",
				user.ID, req.DeviceID, err)
			handler.Fail(c, 500, "设备绑定失败")
			return
		}
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

func bindDeviceToUser(deviceID string, userID uint64) error {
	if deviceID == "" {
		return nil
	}

	now := time.Now()
	var device model.Device
	err := database.DB.Where("device_id = ?", deviceID).First(&device).Error
	switch {
	case err == nil:
		fmt.Printf("[AUTH_BIND] update existing device_id=%s device_row_id=%d user_id=%d old_user_id=%v\n",
			deviceID, device.ID, userID, device.UserID)
		if err := database.DB.Model(&device).Updates(map[string]interface{}{
			"user_id":      userID,
			"last_seen_at": &now,
		}).Error; err != nil {
			return err
		}
	case errors.Is(err, gorm.ErrRecordNotFound):
		device = model.Device{
			DeviceID:   deviceID,
			DisplayID:  generateUniqueDisplayID(),
			UserID:     &userID,
			LastSeenAt: &now,
		}
		fmt.Printf("[AUTH_BIND] create device_id=%s user_id=%d display_id=%s\n",
			deviceID, userID, device.DisplayID)
		if err := database.DB.Create(&device).Error; err != nil {
			return err
		}
	default:
		return err
	}

	var count int64
	if err := database.DB.Model(&model.Device{}).
		Where("device_id = ? AND user_id = ?", deviceID, userID).
		Count(&count).Error; err != nil {
		return err
	}
	fmt.Printf("[AUTH_BIND] verify device_id=%s user_id=%d count=%d\n", deviceID, userID, count)
	if count == 0 {
		return fmt.Errorf("device binding verify failed for device_id=%s user_id=%d", deviceID, userID)
	}
	return nil
}

func canLoginDevice(user model.User, deviceID string) bool {
	var bound model.Device
	if err := database.DB.Where("device_id = ? AND user_id = ?", deviceID, user.ID).First(&bound).Error; err == nil {
		return true
	}

	if user.DeviceID == deviceID {
		return true
	}

	maxDevices := 1
	if user.PlanExpiredAt != nil && user.PlanExpiredAt.After(time.Now()) {
		if user.CurrentPlanID != nil {
			var plan model.Plan
			if err := database.DB.First(&plan, *user.CurrentPlanID).Error; err == nil && plan.MaxDevices > 0 {
				maxDevices = plan.MaxDevices
			}
		}
	}

	var count int64
	database.DB.Model(&model.Device{}).Where("user_id = ?", user.ID).Count(&count)
	if count >= int64(maxDevices) {
		var oldest model.Device
		if err := database.DB.Where("user_id = ?", user.ID).Order("updated_at asc").First(&oldest).Error; err == nil {
			database.DB.Delete(&oldest)
		}
	}
	return true
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
