package model

import "time"

// OrderRecord 订单购买历史
type OrderRecord struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint64    `gorm:"not null;index" json:"user_id"`
	PlanID       uint      `gorm:"not null" json:"plan_id"`
	PlanName     string    `gorm:"size:64;not null" json:"plan_name"`      // 快照
	PlanPrice    float64   `gorm:"type:decimal(10,2);not null" json:"plan_price"` // 快照
	TrafficGB    *int      `gorm:"default:null" json:"traffic_gb"`         // 快照
	DurationDays int       `gorm:"not null" json:"duration_days"`          // 快照
	StartedAt    time.Time `gorm:"not null" json:"started_at"`
	ExpiredAt    time.Time `gorm:"not null;index" json:"expired_at"`
	PayMethod    string    `gorm:"size:32" json:"pay_method"`   // 预留
	PayTradeNo   string    `gorm:"size:128" json:"pay_trade_no"` // 预留
	Remark       string    `gorm:"size:255" json:"remark"`
	CreatedAt    time.Time `json:"created_at"`
}

func (OrderRecord) TableName() string { return "order_records" }
