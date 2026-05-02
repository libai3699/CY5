package model

import "time"

type VpnLine struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string    `gorm:"size:128;not null" json:"name"`
	Region      string    `gorm:"size:64" json:"region"`
	Protocol    string    `gorm:"size:32;not null" json:"protocol"`
	Address     string    `gorm:"size:255;not null" json:"address"`
	RawURI      string    `gorm:"type:text;not null" json:"raw_uri"`
	SortOrder   int       `gorm:"default:0" json:"sort_order"`
	IsDefault   int8      `gorm:"default:0;index" json:"is_default"`
	IsActive    int8      `gorm:"default:1;index" json:"is_active"`
	Description string    `gorm:"size:255" json:"description"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (VpnLine) TableName() string { return "vpn_lines" }
