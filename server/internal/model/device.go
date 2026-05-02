package model

import "time"

// Device 设备表
type Device struct {
	ID       uint64 `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID string `gorm:"size:128;uniqueIndex;not null" json:"device_id"` // ANDROID_ID

	UserID *uint64 `gorm:"default:null;index" json:"user_id"` // 最后登录的用户

	Brand     string `gorm:"size:64" json:"brand"`      // 设备品牌
	Model     string `gorm:"size:128" json:"model"`     // 设备型号
	OSVersion string `gorm:"size:32" json:"os_version"` // Android 版本
	AppVersion string `gorm:"size:32" json:"app_version"` // App 版本

	LastIP     string     `gorm:"size:64" json:"last_ip"`
	LastSeenAt *time.Time `json:"last_seen_at"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

func (Device) TableName() string { return "devices" }
