package model

import "time"

// Plan 套餐表
type Plan struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name         string    `gorm:"size:64;not null" json:"name"`
	Price        float64   `gorm:"type:decimal(10,2);not null" json:"price"`
	TrafficGB    *int      `gorm:"default:null" json:"traffic_gb"`    // NULL=无限
	DurationDays int       `gorm:"default:30" json:"duration_days"`
	SortOrder    int       `gorm:"default:0" json:"sort_order"`
	IsActive     int8      `gorm:"default:1" json:"is_active"` // 1上架 0下架
	CreatedAt    time.Time `json:"created_at"`
}

func (Plan) TableName() string { return "plans" }
