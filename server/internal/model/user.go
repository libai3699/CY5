package model

import "time"

// User 用户表
type User struct {
	ID       uint64 `gorm:"primaryKey;autoIncrement" json:"id"`
	Username string `gorm:"size:64;uniqueIndex;not null" json:"username"`
	Password string `gorm:"size:255;not null" json:"-"` // bcrypt，不输出 JSON

	Phone  string `gorm:"size:20" json:"phone"`
	Status int8   `gorm:"default:1" json:"status"` // 1正常 0禁用

	// 设备关联
	DeviceID         string `gorm:"size:128;index" json:"device_id"`
	FreeUsedSeconds  int    `gorm:"default:0" json:"free_used_seconds"`
	FreeLimitSeconds int    `gorm:"default:2700" json:"free_limit_seconds"` // 45分钟
	CurrentLineID    *uint  `gorm:"default:null;index" json:"current_line_id"`

	// 当前套餐冗余字段（快速查询，避免 JOIN）
	CurrentPlanID     *uint      `gorm:"default:null" json:"current_plan_id"`
	PlanExpiredAt     *time.Time `gorm:"default:null" json:"plan_expired_at"`
	TrafficUsedBytes  int64      `gorm:"default:0" json:"traffic_used_bytes"`
	TrafficLimitBytes *int64     `gorm:"default:null" json:"traffic_limit_bytes"` // NULL=无限

	LastLoginAt *time.Time `json:"last_login_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

func (User) TableName() string { return "users" }
