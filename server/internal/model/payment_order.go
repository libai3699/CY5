package model

import "time"

// PaymentOrder 是提交给第三方支付网关的订单。只有支付成功后才会生成 OrderRecord。
type PaymentOrder struct {
	ID             uint64     `gorm:"primaryKey;autoIncrement" json:"id"`
	OrderNo        string     `gorm:"size:40;not null;uniqueIndex" json:"order_no"`
	CheckoutToken  string     `gorm:"size:64;not null;uniqueIndex" json:"-"`
	UserID         uint64     `gorm:"not null;index" json:"user_id"`
	PlanID         uint       `gorm:"not null" json:"plan_id"`
	PlanName       string     `gorm:"size:64;not null" json:"plan_name"`
	BillingCycle   string     `gorm:"size:16;not null" json:"billing_cycle"`
	Months         int        `gorm:"not null" json:"months"`
	DurationDays   int        `gorm:"not null" json:"duration_days"`
	TrafficGB      *int       `gorm:"default:null" json:"traffic_gb"`
	AmountCents    int64      `gorm:"not null" json:"amount_cents"`
	PayType        string     `gorm:"size:16;not null" json:"pay_type"`
	Status         string     `gorm:"size:16;not null;default:pending;index" json:"status"`
	GatewayTradeNo string     `gorm:"size:128;index" json:"gateway_trade_no"`
	OrderRecordID  *uint64    `gorm:"default:null;uniqueIndex" json:"order_record_id"`
	PaidAt         *time.Time `gorm:"default:null" json:"paid_at"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

func (PaymentOrder) TableName() string { return "payment_orders" }
