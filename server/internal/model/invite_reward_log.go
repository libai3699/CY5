package model

import "time"

// InviteRewardLog records traffic rewards granted by invitation actions.
type InviteRewardLog struct {
	ID          uint64    `gorm:"primaryKey;autoIncrement" json:"id"`
	InviterID   uint64    `gorm:"not null;index" json:"inviter_id"`
	InviteeID   uint64    `gorm:"not null;index" json:"invitee_id"`
	RewardType  string    `gorm:"size:32;not null;index" json:"reward_type"`
	RewardBytes int64     `gorm:"not null" json:"reward_bytes"`
	DeviceID    string    `gorm:"size:128;index" json:"device_id"`
	OrderID     *uint64   `gorm:"default:null;uniqueIndex" json:"order_id"`
	CreatedAt   time.Time `json:"created_at"`
}

func (InviteRewardLog) TableName() string { return "invite_reward_logs" }
