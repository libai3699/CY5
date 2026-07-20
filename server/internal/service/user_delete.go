package service

import (
	"fmt"
	"log"
	"time"

	"cy5vpn/server/internal/model"

	"gorm.io/gorm"
)

// DeleteUserCompletely 与后台「删除用户」一致，清理全部关联数据。
func DeleteUserCompletely(tx *gorm.DB, user *model.User) error {
	if err := tx.Where("user_id = ?", user.ID).Delete(&model.Device{}).Error; err != nil {
		return err
	}
	if err := tx.Model(&model.User{}).
		Where("inviter_id = ?", user.ID).
		Update("inviter_id", nil).Error; err != nil {
		return err
	}
	if err := tx.Where("inviter_id = ? OR invitee_id = ?", user.ID, user.ID).
		Delete(&model.InviteRewardLog{}).Error; err != nil {
		return err
	}
	if err := tx.Where("target_user_id = ?", user.ID).
		Delete(&model.Notice{}).Error; err != nil {
		return err
	}
	if err := tx.Where("user_id = ?", user.ID).
		Delete(&model.UserNoticeRead{}).Error; err != nil {
		return err
	}
	if err := tx.Where("user_id = ?", user.ID).
		Delete(&model.UserLoginLog{}).Error; err != nil {
		return err
	}
	if err := tx.Where("user_id = ?", user.ID).
		Delete(&model.DurationLog{}).Error; err != nil {
		return err
	}
	if err := tx.Where("user_id = ?", user.ID).
		Delete(&model.OrderRecord{}).Error; err != nil {
		return err
	}
	if err := tx.Where("user_id = ?", user.ID).
		Delete(&model.PaymentOrder{}).Error; err != nil {
		return err
	}
	return tx.Delete(user).Error
}

// DeleteUserByID 按用户 ID 完整删除。
func DeleteUserByID(db *gorm.DB, userID uint64) error {
	return db.Transaction(func(tx *gorm.DB) error {
		var user model.User
		if err := tx.First(&user, userID).Error; err != nil {
			return err
		}
		return DeleteUserCompletely(tx, &user)
	})
}

const defaultInactiveUserDays = 45

// UserLastActiveAt 取注册、最后登录、设备最后在线三者中最晚时间。
func UserLastActiveAt(user model.User, maxDeviceSeen *time.Time) time.Time {
	last := user.CreatedAt
	if user.LastLoginAt != nil && user.LastLoginAt.After(last) {
		last = *user.LastLoginAt
	}
	if maxDeviceSeen != nil && maxDeviceSeen.After(last) {
		last = *maxDeviceSeen
	}
	return last
}

// FindInactiveUserIDs 查找超过 inactiveDays 未活跃的用户 ID。
func FindInactiveUserIDs(db *gorm.DB, inactiveDays int) ([]uint64, error) {
	if inactiveDays <= 0 {
		inactiveDays = defaultInactiveUserDays
	}
	cutoff := time.Now().AddDate(0, 0, -inactiveDays)

	type row struct {
		ID              uint64
		CreatedAt       time.Time
		LastLoginAt     *time.Time
		MaxDeviceSeenAt *time.Time
	}
	var rows []row
	err := db.Table("users u").
		Select(`u.id, u.created_at, u.last_login_at,
			(SELECT MAX(d.last_seen_at) FROM devices d WHERE d.user_id = u.id) AS max_device_seen_at`).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	ids := make([]uint64, 0)
	for _, r := range rows {
		user := model.User{ID: r.ID, CreatedAt: r.CreatedAt, LastLoginAt: r.LastLoginAt}
		if UserLastActiveAt(user, r.MaxDeviceSeenAt).Before(cutoff) {
			ids = append(ids, r.ID)
		}
	}
	return ids, nil
}

// CleanupInactiveUsers 删除长期未登录用户，返回成功删除数量。
func CleanupInactiveUsers(db *gorm.DB, inactiveDays int) (int, error) {
	ids, err := FindInactiveUserIDs(db, inactiveDays)
	if err != nil {
		return 0, err
	}
	deleted := 0
	for _, id := range ids {
		if err := DeleteUserByID(db, id); err != nil {
			log.Printf("[INACTIVE_USER] 删除用户 %d 失败: %v", id, err)
			continue
		}
		deleted++
		log.Printf("[INACTIVE_USER] 已删除长期未登录用户 id=%d", id)
	}
	if deleted > 0 {
		log.Printf("[INACTIVE_USER] 本次共删除 %d 个超过 %d 天未活跃账户", deleted, inactiveDays)
	}
	return deleted, nil
}

// StartInactiveUserCleanup 启动定时任务：启动时执行一次，之后每天检查。
func StartInactiveUserCleanup(db *gorm.DB, inactiveDays int) {
	if inactiveDays <= 0 {
		inactiveDays = defaultInactiveUserDays
	}
	days := inactiveDays
	run := func() {
		if _, err := CleanupInactiveUsers(db, days); err != nil {
			log.Printf("[INACTIVE_USER] 清理任务失败: %v", err)
		}
	}
	go func() {
		// 避免与迁移/启动高峰重叠
		time.Sleep(30 * time.Second)
		run()
		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			run()
		}
	}()
	log.Printf("[INACTIVE_USER] 已启动自动清理任务（%d 天未登录）", days)
}

// InactiveUserDaysFromEnv 读取配置天数，默认 45。
func InactiveUserDaysFromEnv(getEnv func(string, string) string) int {
	raw := getEnv("INACTIVE_USER_DAYS", fmt.Sprintf("%d", defaultInactiveUserDays))
	days := 0
	if _, err := fmt.Sscanf(raw, "%d", &days); err != nil || days <= 0 {
		return defaultInactiveUserDays
	}
	return days
}
