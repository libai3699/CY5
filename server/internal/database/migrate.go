package database

import (
	"log"

	"cy5vpn/server/internal/model"
)

// Migrate 自动建表
func Migrate() {
	err := DB.AutoMigrate(
		&model.User{},
		&model.Device{},
		&model.Plan{},
		&model.OrderRecord{},
		&model.AppConfig{},
		&model.Notice{},
		&model.UserLoginLog{},
		&model.AdminLoginLog{},
	)
	if err != nil {
		log.Fatalf("[migrate] 建表失败: %v", err)
	}
	log.Println("[migrate] 数据表同步完成")

	seedPlans()
	seedConfigs()
}

// seedPlans 初始化套餐数据（幂等）
func seedPlans() {
	var count int64
	DB.Model(&model.Plan{}).Count(&count)
	if count > 0 {
		return
	}

	gb15 := 15
	gb50 := 50
	gb100 := 100

	plans := []model.Plan{
		{Name: "基础版", Price: 9.9, TrafficGB: &gb15, DurationDays: 30, SortOrder: 1, IsActive: 1},
		{Name: "标准版", Price: 19.9, TrafficGB: &gb50, DurationDays: 30, SortOrder: 2, IsActive: 1},
		{Name: "高级版", Price: 29.9, TrafficGB: &gb100, DurationDays: 30, SortOrder: 3, IsActive: 1},
		{Name: "无限版", Price: 69.9, TrafficGB: nil, DurationDays: 30, SortOrder: 4, IsActive: 1},
	}
	DB.Create(&plans)
	log.Println("[migrate] 套餐初始数据写入完成")
}

// seedConfigs 初始化配置数据（幂等）
func seedConfigs() {
	configs := []model.AppConfig{
		{KeyName: "subscription_url", Value: "", Label: "VPN 订阅链接", SortOrder: 1},
		{KeyName: "contact_wechat", Value: "", Label: "微信号", SortOrder: 10},
		{KeyName: "contact_telegram", Value: "", Label: "Telegram 链接", SortOrder: 11},
		{KeyName: "contact_email", Value: "", Label: "邮箱", SortOrder: 12},
		{KeyName: "contact_qq", Value: "", Label: "QQ 号", SortOrder: 13},
		{KeyName: "download_vpn_apk", Value: "", Label: "9点9 VPN APK 下载链接", SortOrder: 20},
		{KeyName: "download_acc_apk", Value: "", Label: "9点9 加速器 APK 下载链接", SortOrder: 21},
		{KeyName: "download_vpn_exe", Value: "", Label: "9点9 VPN EXE 下载链接", SortOrder: 22},
		{KeyName: "download_acc_exe", Value: "", Label: "9点9 加速器 EXE 下载链接", SortOrder: 23},
		{KeyName: "app_vpn_version", Value: "1.0.0", Label: "9点9 VPN 最新版本", SortOrder: 30},
		{KeyName: "app_acc_version", Value: "1.0.0", Label: "9点9 加速器最新版本", SortOrder: 31},
	}

	for _, cfg := range configs {
		// 只在 key 不存在时插入，已存在则跳过
		DB.Where(model.AppConfig{KeyName: cfg.KeyName}).FirstOrCreate(&cfg)
	}
	log.Println("[migrate] 配置初始数据写入完成")
}
