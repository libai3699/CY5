package model

import "time"

// Quote 精选语录表
type Quote struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	Author    string    `gorm:"size:64" json:"author"`           // 作者（可选）
	IsActive  int8      `gorm:"default:1" json:"is_active"`      // 1启用 0禁用
	SortOrder int       `gorm:"default:0" json:"sort_order"`     // 排序
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Quote) TableName() string { return "quotes" }
