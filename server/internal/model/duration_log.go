package model

import "time"

// DurationLog 追加时长/流量记录
type DurationLog struct {
	ID           uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       uint64    `gorm:"index;not null" json:"user_id"`
	Username     string    `gorm:"size:64" json:"username"`
	Seconds      int64     `gorm:"default:0" json:"seconds"`        // 追加秒数
	TrafficBytes int64     `gorm:"default:0" json:"traffic_bytes"`  // 追加流量字节
	Remark       string    `gorm:"size:255" json:"remark"`          // 备注
	OperatorName string    `gorm:"size:64" json:"operator_name"`    // 操作人
	CreatedAt    time.Time `json:"created_at"`
}

func (DurationLog) TableName() string { return "duration_logs" }
