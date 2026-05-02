package model

import "time"

// Notice 公共通知
type Notice struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	Type      int8      `gorm:"default:1" json:"type"`      // 1普通 2重要
	IsActive  int8      `gorm:"default:1" json:"is_active"` // 1显示 0隐藏
	SortOrder int       `gorm:"default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Notice) TableName() string { return "notices" }
