package model

import "time"

// PaymentConfig 支付配置表
type PaymentConfig struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Type      string    `gorm:"size:32;not null;uniqueIndex" json:"type"` // usdt_trc20, usdt_bep20, wechat, alipay
	Label     string    `gorm:"size:64;not null" json:"label"`            // 显示名称
	Address   string    `gorm:"size:255" json:"address"`                  // USDT地址或收款账号
	QRCode    string    `gorm:"size:255" json:"qr_code"`                  // 二维码图片URL
	IsActive  int8      `gorm:"default:1" json:"is_active"`               // 1启用 0禁用
	SortOrder int       `gorm:"default:0" json:"sort_order"`              // 排序
	Remark    string    `gorm:"type:text" json:"remark"`                  // 备注说明
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (PaymentConfig) TableName() string { return "payment_configs" }
