package admin

import (
	"strconv"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

// ListUsers 用户列表（分页 + 搜索）
func ListUsers(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	size, _ := strconv.Atoi(c.DefaultQuery("size", "20"))
	keyword := c.Query("keyword")

	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}

	query := database.DB.Model(&model.User{})
	if keyword != "" {
		query = query.Where("username LIKE ? OR phone LIKE ? OR device_id LIKE ?",
			"%"+keyword+"%", "%"+keyword+"%", "%"+keyword+"%")
	}

	var total int64
	query.Count(&total)

	var users []model.User
	query.Order("created_at desc").
		Offset((page - 1) * size).
		Limit(size).
		Find(&users)

	safe := make([]gin.H, 0, len(users))
	for _, u := range users {
		safe = append(safe, safeUserAdmin(u))
	}

	handler.OK(c, gin.H{
		"total": total,
		"page":  page,
		"size":  size,
		"list":  safe,
	})
}

// GetUser 用户详情
func GetUser(c *gin.Context) {
	id := c.Param("id")
	var user model.User
	if err := database.DB.First(&user, id).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}
	handler.OK(c, safeUserAdmin(user))
}

type createUserReq struct {
	Username         string `json:"username" binding:"required"`
	Password         string `json:"password" binding:"required"`
	Phone            string `json:"phone"`
	FreeLimitSeconds int    `json:"free_limit_seconds"`
}

// CreateUser 新增用户
func CreateUser(c *gin.Context) {
	var req createUserReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误: "+err.Error())
		return
	}

	// 检查用户名是否已存在
	var count int64
	database.DB.Model(&model.User{}).Where("username = ?", req.Username).Count(&count)
	if count > 0 {
		handler.Fail(c, 400, "用户名已存在")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		handler.Fail(c, 500, "密码加密失败")
		return
	}

	limit := 2700
	if req.FreeLimitSeconds > 0 {
		limit = req.FreeLimitSeconds
	}

	user := model.User{
		Username:         req.Username,
		Password:         string(hash),
		Phone:            req.Phone,
		Status:           1,
		FreeLimitSeconds: limit,
	}
	database.DB.Create(&user)
	handler.OK(c, safeUserAdmin(user))
}

type updateUserReq struct {
	Status           *int8  `json:"status"`
	Phone            string `json:"phone"`
	Password         string `json:"password"`
	FreeUsedSeconds  *int   `json:"free_used_seconds"`
	FreeLimitSeconds *int   `json:"free_limit_seconds"`
}

// UpdateUser 编辑用户
func UpdateUser(c *gin.Context) {
	id := c.Param("id")
	var user model.User
	if err := database.DB.First(&user, id).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	var req updateUserReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	updates := map[string]interface{}{}
	if req.Status != nil {
		updates["status"] = *req.Status
	}
	if req.Phone != "" {
		updates["phone"] = req.Phone
	}
	if req.FreeUsedSeconds != nil {
		updates["free_used_seconds"] = *req.FreeUsedSeconds
	}
	if req.FreeLimitSeconds != nil {
		updates["free_limit_seconds"] = *req.FreeLimitSeconds
	}
	if req.Password != "" {
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
		if err == nil {
			updates["password"] = string(hash)
		}
	}

	database.DB.Model(&user).Updates(updates)
	handler.OK(c, gin.H{"msg": "更新成功"})
}

// DeleteUser 删除用户
func DeleteUser(c *gin.Context) {
	id := c.Param("id")
	var user model.User
	if err := database.DB.First(&user, id).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}
	database.DB.Delete(&user)
	handler.OK(c, gin.H{"msg": "删除成功"})
}

func safeUserAdmin(u model.User) gin.H {
	return gin.H{
		"id":                  u.ID,
		"username":            u.Username,
		"phone":               u.Phone,
		"device_id":           u.DeviceID,
		"status":              u.Status,
		"free_used_seconds":   u.FreeUsedSeconds,
		"free_limit_seconds":  u.FreeLimitSeconds,
		"current_plan_id":     u.CurrentPlanID,
		"plan_expired_at":     u.PlanExpiredAt,
		"traffic_used_bytes":  u.TrafficUsedBytes,
		"traffic_limit_bytes": u.TrafficLimitBytes,
		"last_login_at":       u.LastLoginAt,
		"created_at":          u.CreatedAt,
	}
}
