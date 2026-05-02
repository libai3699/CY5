package database

import (
	"log"

	"cy5vpn/server/internal/model"
	"golang.org/x/crypto/bcrypt"
)

// Migrate 自动建表
func Migrate() {
	err := DB.AutoMigrate(
		&model.Admin{},
		&model.User{},
		&model.Device{},
		&model.Plan{},
		&model.VpnLine{},
		&model.OrderRecord{},
		&model.AppConfig{},
		&model.Notice{},
		&model.UserLoginLog{},
		&model.AdminLoginLog{},
		&model.UserNoticeRead{},
	)
	if err != nil {
		log.Fatalf("[migrate] 建表失败: %v", err)
	}
	log.Println("[migrate] 数据表同步完成")

	seedAdmin()
	seedPlans()
	seedLines()
	seedConfigs()
}

// seedAdmin 初始化管理员账号（幂等）
func seedAdmin() {
	var count int64
	DB.Model(&model.Admin{}).Count(&count)
	if count > 0 {
		return
	}

	// 默认密码 admin123456
	hash, err := bcrypt.GenerateFromPassword([]byte("admin123456"), 12)
	if err != nil {
		log.Fatalf("[migrate] 生成管理员密码失败: %v", err)
	}

	admin := model.Admin{
		Username: "admin",
		Password: string(hash),
		Status:   1,
	}
	DB.Create(&admin)
	log.Println("[migrate] 管理员账号初始化完成 admin/admin123456")
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
		{Name: "基础版", Price: 9.9, TrafficGB: &gb15, DurationDays: 30, MaxDevices: 1, SortOrder: 1, IsActive: 1},
		{Name: "标准版", Price: 19.9, TrafficGB: &gb50, DurationDays: 30, MaxDevices: 2, SortOrder: 2, IsActive: 1},
		{Name: "高级版", Price: 29.9, TrafficGB: &gb100, DurationDays: 30, MaxDevices: 3, SortOrder: 3, IsActive: 1},
		{Name: "无限版", Price: 69.9, TrafficGB: nil, DurationDays: 30, MaxDevices: 5, SortOrder: 4, IsActive: 1},
	}
	DB.Create(&plans)
	log.Println("[migrate] 套餐初始数据写入完成")
}

func seedLines() {
	var count int64
	DB.Model(&model.VpnLine{}).Count(&count)
	if count > 0 {
		return
	}

	line := model.VpnLine{
		Name:        "默认线路",
		Region:      "Auto",
		Protocol:    "SUBSCRIPTION",
		Address:     "dash.xn--cp3a08l.com",
		RawURI:      "https://dash.xn--cp3a08l.com/api/v1/pq/f2d013d8cfe32512bc9d23f13592a5a0",
		SortOrder:   1,
		IsDefault:   1,
		IsActive:    1,
		Description: "系统初始化默认线路，请在后台替换为真实可用线路。",
	}
	DB.Create(&line)
	log.Println("[migrate] 线路初始数据写入完成")
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
