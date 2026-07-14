package model

import "time"

// DiscoveryItem is an H5 application configured by administrators.
type DiscoveryItem struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name      string    `gorm:"size:80;not null" json:"name"`
	IconURL   string    `gorm:"size:500;not null" json:"icon_url"`
	H5URL     string    `gorm:"size:1000;not null" json:"h5_url"`
	IsActive  int8      `gorm:"default:1" json:"is_active"`
	SortOrder int       `gorm:"default:0" json:"sort_order"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (DiscoveryItem) TableName() string { return "discovery_items" }
