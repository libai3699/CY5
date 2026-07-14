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
	"cy5vpn/server/internal/service"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type registerReq struct {
	Username   string `json:"username" binding:"required,min=6,max=32"`
	Password   string `json:"password" binding:"required,min=6,max=64"`
	DeviceID   string `json:"device_id" binding:"required"`
	Phone      string `json:"phone"`
	InviteCode string `json:"invite_code"`
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

	inviteCode, err := service.GenerateInviteCode(database.DB)
	if err != nil {
		handler.Fail(c, 500, "邀请码生成失败")
		return
	}

	var inviterID *uint64
	inviter, err := service.FindEligibleInviter(database.DB, req.InviteCode, req.DeviceID, deviceUserCount)
	if err != nil {
		fmt.Printf("[INVITE] resolve inviter failed code=%s device_id=%s err=%v\n", req.InviteCode, req.DeviceID, err)
		handler.Fail(c, 500, "邀请码校验失败")
		return
	}
	if inviter != nil {
		inviterID = &inviter.ID
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
		InviteCode:       inviteCode,
		InviterID:        inviterID,
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
	if inviterID != nil {
		if err := service.GrantRegisterReward(database.DB, *inviterID, user.ID, req.DeviceID); err != nil {
			fmt.Printf("[INVITE] register reward failed inviter_id=%d invitee_id=%d err=%v\n", *inviterID, user.ID, err)
		}
	}

	handler.OK(c, gin.H{
		"token": token,
		"user":  safeUser(user),
	})
}

type loginReq struct {
	Username   string `json:"username" binding:"required"`
	Password   string `json:"password" binding:"required"`
	DeviceID   string `json:"device_id"`
	ForceLogin bool   `json:"force_login"`
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
		maxDevices := loginDeviceLimit(user)
		loggedInCount, alreadyLoggedIn := loginDeviceStatus(user.ID, req.DeviceID)
		if !alreadyLoggedIn && loggedInCount >= int64(maxDevices) {
			if !req.ForceLogin {
				handler.FailData(c, 1005, "登录设备已达套餐上限", gin.H{
					"max_devices":       maxDevices,
					"logged_in_devices": loggedInCount,
				})
				return
			}
			if err := logoutExcessDevices(user.ID, req.DeviceID, maxDevices-1); err != nil {
				fmt.Printf("[AUTH_BIND] force logout failed user_id=%d device_id=%s err=%v\n",
					user.ID, req.DeviceID, err)
				handler.Fail(c, 500, "自动退出其他设备失败，请稍后重试")
				return
			}
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

func loginDeviceLimit(user model.User) int {
	maxDevices := 1
	if user.PlanExpiredAt != nil && user.PlanExpiredAt.After(time.Now()) {
		if user.CurrentPlanID != nil {
			var plan model.Plan
			if err := database.DB.First(&plan, *user.CurrentPlanID).Error; err == nil && plan.MaxDevices > 0 {
				maxDevices = plan.MaxDevices
			}
		}
	}
	return maxDevices
}

func loginDeviceStatus(userID uint64, deviceID string) (int64, bool) {
	var count int64
	database.DB.Model(&model.Device{}).Where("user_id = ?", userID).Count(&count)
	var currentCount int64
	database.DB.Model(&model.Device{}).
		Where("user_id = ? AND device_id = ?", userID, deviceID).
		Count(&currentCount)
	return count, currentCount > 0
}

func logoutExcessDevices(userID uint64, currentDeviceID string, keepCount int) error {
	var devices []model.Device
	if err := database.DB.Where("user_id = ? AND device_id <> ?", userID, currentDeviceID).
		Order("last_seen_at desc, updated_at desc").
		Find(&devices).Error; err != nil {
		return err
	}
	if keepCount < 0 {
		keepCount = 0
	}
	if len(devices) <= keepCount {
		return nil
	}
	ids := make([]uint64, 0, len(devices)-keepCount)
	for _, device := range devices[keepCount:] {
		ids = append(ids, device.ID)
	}
	return database.DB.Model(&model.Device{}).
		Where("id IN ? AND user_id = ?", ids, userID).
		Update("user_id", nil).Error
}

func safeUser(u model.User) gin.H {
	return gin.H{
		"id":                  u.ID,
		"username":            u.Username,
		"phone":               u.Phone,
		"device_id":           u.DeviceID,
		"invite_code":         u.InviteCode,
		"inviter_id":          u.InviterID,
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
