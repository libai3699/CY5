package admin

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"log"
	"strings"
	"time"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

// ⚠️ 安全提醒：
// 1. 部署前务必使用强随机 ADMIN_PASSWORD_HASH 和 ADMIN_CAPTCHA_SECRET
// 2. 同步修改 .env 中的 ADMIN_JWT_SECRET 和 APP_SECRET 为全新随机字符串
// 3. 修改后重新部署，并清除所有旧 session
const (
	adminCaptchaPeriod = int64(30)
)

type adminLoginReq struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	Captcha  string `json:"captcha" binding:"required"`
}

func adminCaptchaCode(t time.Time) string {
	counter := uint64(t.Unix() / adminCaptchaPeriod)
	var buf [8]byte
	binary.BigEndian.PutUint64(buf[:], counter)

	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(config.App.AdminCaptchaSecret)
	if err != nil {
		return ""
	}
	mac := hmac.New(sha1.New, secret)
	mac.Write(buf[:])
	sum := mac.Sum(nil)
	offset := sum[len(sum)-1] & 0x0f
	value := (uint32(sum[offset])&0x7f)<<24 |
		(uint32(sum[offset+1])&0xff)<<16 |
		(uint32(sum[offset+2])&0xff)<<8 |
		(uint32(sum[offset+3]) & 0xff)

	return fmt.Sprintf("%06d", value%1000000)
}

func validateAdminCaptcha(code string) bool {
	code = strings.TrimSpace(code)
	now := time.Now()
	return code == adminCaptchaCode(now) ||
		code == adminCaptchaCode(now.Add(-time.Duration(adminCaptchaPeriod)*time.Second))
}

// Captcha 仅返回基础配置信息，不再暴露 secret、otpauth 或 account
// 管理员需通过安全渠道自行绑定 Google Authenticator
func Captcha(c *gin.Context) {
	handler.OK(c, gin.H{
		"issuer": "9.9 VPN Admin",
		"period": adminCaptchaPeriod,
		"digits": 6,
		"type":   "totp",
	})
}

func Login(c *gin.Context) {
	var req adminLoginReq
	status := int8(0)
	reason := "参数错误"
	username := ""
	defer func() {
		writeAdminLog(c, username, status, reason)
	}()

	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}
	username = req.Username

	if req.Username != config.App.AdminUsername ||
		bcrypt.CompareHashAndPassword([]byte(config.App.AdminPasswordHash), []byte(req.Password)) != nil {
		reason = "用户名或密码错误"
		handler.Fail(c, 1002, "用户名或密码错误")
		return
	}
	if !validateAdminCaptcha(req.Captcha) {
		reason = "验证码错误"
		handler.Fail(c, 1003, "验证码错误")
		return
	}

	token, err := config.GenerateAdminToken(req.Username)
	if err != nil {
		reason = "token 生成失败"
		handler.Fail(c, 500, "token 生成失败")
		return
	}

	status = 1
	reason = ""
	handler.OK(c, gin.H{"accessToken": token})
}

func UserInfo(c *gin.Context) {
	username := c.GetString("admin_username")
	if username == "" {
		username = config.App.AdminUsername
	}

	handler.OK(c, gin.H{
		"avatar":   "",
		"desc":     "9.9 VPN administrator",
		"homePath": "/workspace",
		"realName": username,
		"roles":    []string{"admin"},
		"token":    "",
		"userId":   username,
		"username": username,
	})
}

func AccessCodes(c *gin.Context) {
	handler.OK(c, []string{"CY_ADMIN"})
}

func Logout(c *gin.Context) {
	handler.OK(c, gin.H{"msg": "ok"})
}

func writeAdminLog(c *gin.Context, username string, status int8, reason string) {
	if username == "" {
		username = "-"
	}
	record := map[string]interface{}{
		"username":    username,
		"ip":          c.ClientIP(),
		"user_agent":  c.GetHeader("User-Agent"),
		"status":      status,
		"fail_reason": reason,
		"created_at":  time.Now(),
	}
	if err := database.DB.Model(&model.AdminLoginLog{}).Create(record).Error; err != nil {
		log.Printf("[admin_login_log] write failed: %v", err)
	}
}
