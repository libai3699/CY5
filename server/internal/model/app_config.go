package model

import "time"

// AppConfig 配置表（订阅链接、联系方式、下载链接等）
type AppConfig struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	KeyName   string    `gorm:"size:128;uniqueIndex;not null" json:"key_name"`
	Value     string    `gorm:"type:text;not null" json:"value"`
	Label     string    `gorm:"size:128" json:"label"`
	SortOrder int       `gorm:"default:0" json:"sort_order"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (AppConfig) TableName() string { return "app_configs" }
