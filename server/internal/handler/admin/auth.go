package admin

import (
	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type adminLoginReq struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// Login 后台管理员登录
func Login(c *gin.Context) {
	var req adminLoginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	// 验证用户名
	if req.Username != config.App.AdminUsername {
		writeAdminLog(c, req.Username, 0)
		handler.Fail(c, 1002, "用户名或密码错误")
		return
	}

	// 验证密码（bcrypt）
	if err := bcrypt.CompareHashAndPassword(
		[]byte(config.App.AdminPasswordHash),
		[]byte(req.Password),
	); err != nil {
		writeAdminLog(c, req.Username, 0)
		handler.Fail(c, 1002, "用户名或密码错误")
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

func writeAdminLog(c *gin.Context, username string, status int8) {
	log := model.AdminLoginLog{
		Username:  username,
		IP:        c.ClientIP(),
		UserAgent: c.GetHeader("User-Agent"),
		Status:    status,
	}
	database.DB.Create(&log)
}
