package model

import "time"

// UserNoticeRead 用户通知已读记录
type UserNoticeRead struct {
	ID        uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint64    `gorm:"not null;index:idx_user_notice,unique" json:"user_id"`
	NoticeID  uint      `gorm:"not null;index:idx_user_notice,unique" json:"notice_id"`
	ReadAt    time.Time `json:"read_at"`
}

func (UserNoticeRead) TableName() string { return "user_notice_reads" }
