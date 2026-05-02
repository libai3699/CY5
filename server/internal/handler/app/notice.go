package app

import (
	"fmt"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetNotices 获取公共通知列表（只返回启用的，无需登录）
func GetNotices(c *gin.Context) {
	var notices []model.Notice
	database.DB.Where("is_active = 1 AND target_user_id IS NULL").Order("sort_order asc, created_at desc").Find(&notices)
	handler.OK(c, notices)
}

// GetUserNotices 获取通知列表（带已读状态，需要登录）
func GetUserNotices(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var notices []model.Notice
	database.DB.Where("is_active = 1 AND (target_user_id IS NULL OR target_user_id = ?)", userID).Order("sort_order asc, created_at desc").Find(&notices)

	// 查询该用户已读的通知 ID 集合
	var reads []model.UserNoticeRead
	database.DB.Where("user_id = ?", userID).Find(&reads)
	readSet := make(map[uint]bool, len(reads))
	for _, r := range reads {
		readSet[r.NoticeID] = true
	}

	type noticeWithRead struct {
		ID        uint      `json:"id"`
		Content   string    `json:"content"`
		Type      int8      `json:"type"`
		SortOrder int       `json:"sort_order"`
		CreatedAt time.Time `json:"created_at"`
		IsRead    bool      `json:"is_read"`
	}

	result := make([]noticeWithRead, 0, len(notices))
	for _, n := range notices {
		result = append(result, noticeWithRead{
			ID:        n.ID,
			Content:   n.Content,
			Type:      n.Type,
			SortOrder: n.SortOrder,
			CreatedAt: n.CreatedAt,
			IsRead:    readSet[n.ID],
		})
	}

	// 未读数
	unreadCount := 0
	for _, item := range result {
		if !item.IsRead {
			unreadCount++
		}
	}

	handler.OK(c, gin.H{
		"list":         result,
		"unread_count": unreadCount,
	})
}

// MarkNoticeRead 标记单条通知已读
func MarkNoticeRead(c *gin.Context) {
	userID := c.GetUint64("user_id")
	noticeID := c.Param("id")

	now := time.Now()
	read := model.UserNoticeRead{
		UserID: userID,
		ReadAt: now,
	}
	// 解析 noticeID
	var nid uint
	if _, err := fmt.Sscanf(noticeID, "%d", &nid); err != nil {
		handler.Fail(c, 400, "参数错误")
		return
	}
	read.NoticeID = nid

	// upsert：已存在则忽略
	database.DB.Where(model.UserNoticeRead{UserID: userID, NoticeID: nid}).
		FirstOrCreate(&read)

	handler.OK(c, gin.H{"msg": "已标记已读"})
}

// MarkAllNoticesRead 全部标记已读
func MarkAllNoticesRead(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var notices []model.Notice
	database.DB.Where("is_active = 1 AND (target_user_id IS NULL OR target_user_id = ?)", userID).Select("id").Find(&notices)

	now := time.Now()
	for _, n := range notices {
		read := model.UserNoticeRead{
			UserID:   userID,
			NoticeID: n.ID,
			ReadAt:   now,
		}
		database.DB.Where(model.UserNoticeRead{UserID: userID, NoticeID: n.ID}).
			FirstOrCreate(&read)
	}

	handler.OK(c, gin.H{"msg": "全部已读"})
}
