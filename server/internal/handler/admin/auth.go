package admin

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"net/url"
	"strings"
	"time"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

const (
	adminUsername      = "yuexiameiren"
	adminPassword      = "1"
	adminCaptchaSecret = "JBSWY3DPEHPK3PXP"
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

	secret, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(adminCaptchaSecret)
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

func Captcha(c *gin.Context) {
	issuer := "9.9 VPN Admin"
	account := adminUsername
	otpauth := fmt.Sprintf(
		"otpauth://totp/%s:%s?secret=%s&issuer=%s&period=%d&digits=6",
		url.QueryEscape(issuer),
		url.QueryEscape(account),
		adminCaptchaSecret,
		url.QueryEscape(issuer),
		adminCaptchaPeriod,
	)
	handler.OK(c, gin.H{
		"account":  account,
		"issuer":   issuer,
		"otpauth":  otpauth,
		"period":   adminCaptchaPeriod,
		"secret":   adminCaptchaSecret,
		"type":     "totp",
	})
}

func Login(c *gin.Context) {
	var req adminLoginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	if req.Username != adminUsername || req.Password != adminPassword {
		writeAdminLog(c, req.Username, 0)
		handler.Fail(c, 1002, "用户名或密码错误")
		return
	}
	if !validateAdminCaptcha(req.Captcha) {
		writeAdminLog(c, req.Username, 0)
		handler.Fail(c, 1003, "验证码错误")
		return
	}

	token, err := config.GenerateAdminToken(req.Username)
	if err != nil {
		handler.Fail(c, 500, "token 生成失败")
		return
	}

	writeAdminLog(c, req.Username, 1)
	handler.OK(c, gin.H{"accessToken": token})
}

func UserInfo(c *gin.Context) {
	username := c.GetString("admin_username")
	if username == "" {
		username = adminUsername
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

func writeAdminLog(c *gin.Context, username string, status int8) {
	log := model.AdminLoginLog{
		Username:  username,
		IP:        c.ClientIP(),
		UserAgent: c.GetHeader("User-Agent"),
		Status:    status,
	}
	database.DB.Create(&log)
}
