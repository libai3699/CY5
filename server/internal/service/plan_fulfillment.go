package service

import (
	"fmt"
	"time"

	"cy5vpn/server/internal/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// FulfillPlanPurchase 为用户开通套餐（时长叠加、流量累加），并写入订单记录。
func FulfillPlanPurchase(db *gorm.DB, userID uint64, planID uint, billingCycle, payMethod, remark string) (*model.OrderRecord, error) {
	var plan model.Plan
	if err := db.Where("id = ? AND is_active = 1", planID).First(&plan).Error; err != nil {
		return nil, fmt.Errorf("套餐不存在或已下架")
	}

	months, amountCents, err := PurchaseTerms(plan, billingCycle)
	if err != nil {
		return nil, err
	}

	durationDays := plan.DurationDays * months
	planPrice := float64(amountCents) / 100

	var created model.OrderRecord
	err = db.Transaction(func(tx *gorm.DB) error {
		var user model.User
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&user, userID).Error; err != nil {
			return fmt.Errorf("用户不存在")
		}

		now := time.Now()
		startsAt := now
		if user.PlanExpiredAt != nil && user.PlanExpiredAt.After(startsAt) {
			startsAt = *user.PlanExpiredAt
		}
		expiredAt := startsAt.AddDate(0, 0, durationDays)

		var trafficLimit *int64
		var trafficGB *int
		if plan.TrafficGB != nil {
			gb := *plan.TrafficGB * months
			trafficGB = &gb
			bytes := int64(gb) * 1024 * 1024 * 1024
			if user.TrafficLimitBytes != nil && *user.TrafficLimitBytes > user.TrafficUsedBytes {
				bytes += *user.TrafficLimitBytes - user.TrafficUsedBytes
			}
			trafficLimit = &bytes
		}

		record := model.OrderRecord{
			UserID:       userID,
			PlanID:       plan.ID,
			PlanName:     plan.Name,
			PlanPrice:    planPrice,
			TrafficGB:    trafficGB,
			DurationDays: durationDays,
			StartedAt:    now,
			ExpiredAt:    expiredAt,
			PayMethod:    payMethod,
			Remark:       remark,
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}

		if err := tx.Model(&user).Updates(map[string]interface{}{
			"current_plan_id":     plan.ID,
			"plan_expired_at":     expiredAt,
			"traffic_used_bytes":  0,
			"traffic_limit_bytes": trafficLimit,
		}).Error; err != nil {
			return err
		}

		created = record
		return nil
	})
	if err != nil {
		return nil, err
	}

	var user model.User
	if db.First(&user, userID).Error == nil {
		_ = GrantPurchaseReward(db, user, created.ID)
	}
	return &created, nil
}
