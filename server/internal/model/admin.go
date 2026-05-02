package model

import "time"

// Admin 管理员表
type Admin struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Username  string    `gorm:"size:64;uniqueIndex;not null" json:"username"`
	Password  string    `gorm:"size:255;not null" json:"-"` // bcrypt
	Status    int8      `gorm:"default:1" json:"status"`    // 1正常 0禁用
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Admin) TableName() string { return "admins" }
