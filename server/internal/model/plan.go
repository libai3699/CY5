package model

import "time"

// Plan 套餐表
type Plan struct {
	ID           uint    `gorm:"primaryKey;autoIncrement" json:"id"`
	Name         string  `gorm:"size:64;not null" json:"name"`
	Price        float64 `gorm:"type:decimal(10,2);not null" json:"price"` // 月付原价
	TrafficGB    *int    `gorm:"default:null" json:"traffic_gb"`           // NULL=无限
	DurationDays int     `gorm:"default:30" json:"duration_days"`
	MaxDevices   int     `gorm:"default:1" json:"max_devices"`
	SortOrder    int     `gorm:"default:0" json:"sort_order"`
	IsActive     int8    `gorm:"default:1" json:"is_active"` // 1上架 0下架

	// 折扣率（0~1，1=无折扣，0.95=95折，null=不提供该周期）
	DiscountQuarter  *float64 `gorm:"type:decimal(4,2);default:null" json:"discount_quarter"`   // 季付折扣
	DiscountHalfYear *float64 `gorm:"type:decimal(4,2);default:null" json:"discount_half_year"` // 半年付折扣
	DiscountYear     *float64 `gorm:"type:decimal(4,2);default:null" json:"discount_year"`      // 年付折扣

	CreatedAt time.Time `json:"created_at"`
}

func (Plan) TableName() string { return "plans" }
