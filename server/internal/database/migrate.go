package database

import (
	"log"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/model"
	"cy5vpn/server/internal/service"
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
		&model.InviteRewardLog{},
		&model.AppConfig{},
		&model.Notice{},
		&model.UserLoginLog{},
		&model.AdminLoginLog{},
		&model.UserNoticeRead{},
		&model.Quote{},
		&model.PaymentConfig{},
		&model.DurationLog{},
		&model.PageEvent{},
	)
	if err != nil {
		log.Fatalf("[migrate] 建表失败: %v", err)
	}
	log.Println("[migrate] 数据表同步完成")

	seedAdmin()
	seedPlans()
	seedLines()
	seedConfigs()
	seedQuotes()
	seedPaymentConfigs()
	backfillInviteCodes()
}

// seedAdmin 初始化管理员账号（幂等）
func seedAdmin() {
	var count int64
	DB.Model(&model.Admin{}).Count(&count)
	if count > 0 {
		return
	}

	admin := model.Admin{
		Username: config.App.AdminUsername,
		Password: config.App.AdminPasswordHash,
		Status:   1,
	}
	DB.Create(&admin)
	log.Println("[migrate] 管理员账号初始化完成")
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
		Address:     "example.invalid",
		RawURI:      "",
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

// seedQuotes 初始化精选语录数据（幂等）
func seedQuotes() {
	var count int64
	DB.Model(&model.Quote{}).Count(&count)
	if count > 0 {
		return
	}

	quotes := []model.Quote{
		{Content: "生活不止眼前的苟且，还有诗和远方的田野。", Author: "高晓松", IsActive: 1, SortOrder: 1},
		{Content: "世界那么大，我想去看看。", Author: "", IsActive: 1, SortOrder: 2},
		{Content: "自由不是想做什么就做什么，而是不想做什么就不做什么。", Author: "康德", IsActive: 1, SortOrder: 3},
		{Content: "互联网让世界变成了地球村。", Author: "", IsActive: 1, SortOrder: 4},
		{Content: "科技改变生活，网络连接世界。", Author: "", IsActive: 1, SortOrder: 5},
	}
	DB.Create(&quotes)
	log.Println("[migrate] 精选语录初始数据写入完成")
}

// seedPaymentConfigs 初始化支付配置数据（幂等）
func seedPaymentConfigs() {
	configs := []model.PaymentConfig{
		{Type: "usdt_trc20", Label: "USDT (TRC20)", Address: "", QRCode: "", IsActive: 1, SortOrder: 1, Remark: "请填写TRC20网络的USDT收款地址"},
		{Type: "usdt_bep20", Label: "USDT (BEP20)", Address: "", QRCode: "", IsActive: 1, SortOrder: 2, Remark: "请填写BEP20网络的USDT收款地址"},
		{Type: "usdt_erc20", Label: "USDT (ERC20)", Address: "", QRCode: "", IsActive: 1, SortOrder: 3, Remark: "请填写ERC20网络的USDT收款地址"},
		{Type: "wechat", Label: "微信支付", Address: "", QRCode: "", IsActive: 1, SortOrder: 4, Remark: "请上传微信收款二维码"},
		{Type: "alipay", Label: "支付宝", Address: "", QRCode: "", IsActive: 1, SortOrder: 5, Remark: "请上传支付宝收款二维码"},
	}

	for _, cfg := range configs {
		// 只在 type 不存在时插入，已存在则跳过
		DB.Where(model.PaymentConfig{Type: cfg.Type}).FirstOrCreate(&cfg)
	}
	log.Println("[migrate] 支付配置初始数据写入完成")
}

func backfillInviteCodes() {
	var users []model.User
	if err := DB.Where("invite_code = '' OR invite_code IS NULL").Find(&users).Error; err != nil {
		log.Printf("[migrate] 查询邀请码待补用户失败: %v", err)
		return
	}
	for _, user := range users {
		code, err := service.GenerateInviteCode(DB)
		if err != nil {
			log.Printf("[migrate] 用户 %d 邀请码生成失败: %v", user.ID, err)
			continue
		}
		if err := DB.Model(&model.User{}).Where("id = ?", user.ID).Update("invite_code", code).Error; err != nil {
			log.Printf("[migrate] 用户 %d 邀请码回填失败: %v", user.ID, err)
		}
	}
	if len(users) > 0 {
		log.Printf("[migrate] 已回填邀请码用户数: %d", len(users))
	}
}
