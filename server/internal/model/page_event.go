package model

import "time"

// PageEvent 页面埋点事件
type PageEvent struct {
	ID        uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	Page      string    `gorm:"size:64;not null;index" json:"page"`       // 页面名称，如 purchase、payment
	Event     string    `gorm:"size:64;not null;index" json:"event"`      // 事件类型：enter/leave/click
	UserID    *uint64   `gorm:"default:null;index" json:"user_id"`        // 登录用户ID，未登录为null
	Username  string    `gorm:"size:64" json:"username"`                  // 用户名快照
	DeviceID  string    `gorm:"size:128;index" json:"device_id"`          // 设备内部ID
	DisplayID string    `gorm:"size:16" json:"display_id"`                // 7位展示ID
	PlanName  string    `gorm:"size:128" json:"plan_name"`                // 选中的套餐名
	PlanPrice float64   `gorm:"default:0" json:"plan_price"`              // 套餐价格
	Cycle     string    `gorm:"size:32" json:"cycle"`                     // 付款周期
	StayMs    int64     `gorm:"default:0" json:"stay_ms"`                 // 停留时长（毫秒）
	IP        string    `gorm:"size:64" json:"ip"`
	CreatedAt time.Time `json:"created_at"`
}

func (PageEvent) TableName() string { return "page_events" }
