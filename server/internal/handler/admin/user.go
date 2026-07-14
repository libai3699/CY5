package admin

import (
	"strconv"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/ws"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

const userOnlineWindow = 2 * time.Minute

type userDeviceSummary struct {
	displayID     string
	lastIP        string
	lastSeenAt    *time.Time
	onlineDevices int
}

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

	// 批量汇总用户所有已绑定设备。最近两分钟有鉴权请求即视为在线。
	userIDs := make([]uint64, 0, len(users))
	for _, u := range users {
		userIDs = append(userIDs, u.ID)
	}
	deviceMap := make(map[uint64]*userDeviceSummary)
	if len(userIDs) > 0 {
		var devices []model.Device
		database.DB.Select("user_id, display_id, last_ip, last_seen_at").
			Where("user_id IN ?", userIDs).
			Order("last_seen_at desc, updated_at desc").
			Find(&devices)
		onlineCutoff := time.Now().Add(-userOnlineWindow)
		for _, d := range devices {
			if d.UserID == nil {
				continue
			}
			summary := deviceMap[*d.UserID]
			if summary == nil {
				summary = &userDeviceSummary{
					displayID:  d.DisplayID,
					lastIP:     d.LastIP,
					lastSeenAt: d.LastSeenAt,
				}
				deviceMap[*d.UserID] = summary
			}
			if d.LastSeenAt != nil && d.LastSeenAt.After(onlineCutoff) {
				summary.onlineDevices++
			}
		}
	}

	for _, u := range users {
		h := safeUserAdmin(u)
		summary := deviceMap[u.ID]
		if summary == nil {
			h["display_id"] = ""
			h["last_ip"] = ""
			h["last_ip_detail"] = describeIP("")
			h["last_active_at"] = nil
			h["online_devices"] = 0
			h["is_online"] = false
		} else {
			h["display_id"] = summary.displayID
			h["last_ip"] = summary.lastIP
			h["last_ip_detail"] = describeIP(summary.lastIP)
			h["last_active_at"] = summary.lastSeenAt
			h["online_devices"] = summary.onlineDevices
			h["is_online"] = summary.onlineDevices > 0
		}
		safe = append(safe, h)
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
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.Device{}).Error; err != nil {
			return err
		}
		if err := tx.Model(&model.User{}).
			Where("inviter_id = ?", user.ID).
			Update("inviter_id", nil).Error; err != nil {
			return err
		}
		if err := tx.Where("inviter_id = ? OR invitee_id = ?", user.ID, user.ID).
			Delete(&model.InviteRewardLog{}).Error; err != nil {
			return err
		}
		if err := tx.Where("target_user_id = ?", user.ID).
			Delete(&model.Notice{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.UserNoticeRead{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.UserLoginLog{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.DurationLog{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.OrderRecord{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.PaymentOrder{}).Error; err != nil {
			return err
		}
		if err := tx.Where("user_id = ?", user.ID).
			Delete(&model.PageEvent{}).Error; err != nil {
			return err
		}
		return tx.Delete(&user).Error
	}); err != nil {
		handler.Fail(c, 500, "删除用户失败")
		return
	}
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
		"current_line_id":     u.CurrentLineID,
		"current_plan_id":     u.CurrentPlanID,
		"plan_expired_at":     u.PlanExpiredAt,
		"traffic_used_bytes":  u.TrafficUsedBytes,
		"traffic_limit_bytes": u.TrafficLimitBytes,
		"last_login_at":       u.LastLoginAt,
		"created_at":          u.CreatedAt,
	}
}

type addDurationReq struct {
	Seconds      int64 `json:"seconds" binding:"required,min=1"`
	TrafficBytes int64 `json:"traffic_bytes"` // 追加流量字节数，0=不追加
}

// AddUserDuration 给用户追加时长和流量
func AddUserDuration(c *gin.Context) {
	id := c.Param("id")
	var user model.User
	if err := database.DB.First(&user, id).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	var req addDurationReq
	if err := c.ShouldBindJSON(&req); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}

	now := time.Now()
	duration := time.Duration(req.Seconds) * time.Second
	var newExpiredAt time.Time

	if user.PlanExpiredAt == nil || user.PlanExpiredAt.Before(now) {
		newExpiredAt = now.Add(duration)
	} else {
		newExpiredAt = user.PlanExpiredAt.Add(duration)
	}

	updates := map[string]interface{}{
		"plan_expired_at": newExpiredAt,
	}

	// 追加流量
	if req.TrafficBytes > 0 {
		if user.TrafficLimitBytes == nil {
			updates["traffic_limit_bytes"] = req.TrafficBytes
		} else {
			updates["traffic_limit_bytes"] = *user.TrafficLimitBytes + req.TrafficBytes
		}
	}

	database.DB.Model(&user).Updates(updates)

	// 写入追加记录
	operatorName := c.GetString("admin_username")
	if operatorName == "" {
		operatorName = "admin"
	}
	database.DB.Create(&model.DurationLog{
		UserID:       user.ID,
		Username:     user.Username,
		Seconds:      req.Seconds,
		TrafficBytes: req.TrafficBytes,
		OperatorName: operatorName,
	})

	// 推送 WS 通知，让用户端实时刷新状态
	ws.Notices.PushEvent(user.ID, "status_update", gin.H{
		"msg": "管理员已为您追加时长/流量",
	})

	handler.OK(c, gin.H{
		"msg":             "追加成功",
		"plan_expired_at": newExpiredAt,
	})
}
