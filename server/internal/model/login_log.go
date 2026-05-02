package model

import "time"

// UserLoginLog 前台登录日志
type UserLoginLog struct {
	ID         uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint64    `gorm:"not null;index" json:"user_id"`
	DeviceID   string    `gorm:"size:128" json:"device_id"`
	IP         string    `gorm:"size:64" json:"ip"`
	AppVersion string    `gorm:"size:32" json:"app_version"`
	Status     int8      `gorm:"default:1" json:"status"` // 1成功 0失败
	FailReason string    `gorm:"size:255" json:"fail_reason"`
	CreatedAt  time.Time `gorm:"index" json:"created_at"`
}

func (UserLoginLog) TableName() string { return "user_login_logs" }

// AdminLoginLog 后台登录日志
type AdminLoginLog struct {
	ID        uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	Username  string    `gorm:"size:64;not null" json:"username"`
	IP        string    `gorm:"size:64" json:"ip"`
	UserAgent string    `gorm:"size:512" json:"user_agent"`
	Status    int8      `gorm:"default:1" json:"status"` // 1成功 0失败
	CreatedAt time.Time `gorm:"index" json:"created_at"`
}

func (AdminLoginLog) TableName() string { return "admin_login_logs" }
