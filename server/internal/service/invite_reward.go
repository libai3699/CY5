package service

import (
	"crypto/rand"
	"errors"
	"fmt"
	"strings"

	"cy5vpn/server/internal/model"

	"gorm.io/gorm"
)

const (
	InviteRegisterRewardBytes = int64(1063004406)  // 0.99 GiB
	InvitePurchaseRewardBytes = int64(10630044057) // 9.9 GiB
)

const inviteAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func GenerateInviteCode(db *gorm.DB) (string, error) {
	for i := 0; i < 20; i++ {
		code, err := randomInviteCode(7)
		if err != nil {
			return "", err
		}
		var count int64
		if err := db.Model(&model.User{}).Where("invite_code = ?", code).Count(&count).Error; err != nil {
			return "", err
		}
		if count == 0 {
			return code, nil
		}
	}
	return "", fmt.Errorf("invite code exhausted")
}

func FindEligibleInviter(db *gorm.DB, inviteCode string, deviceID string, sameDeviceUserCount int64) (*model.User, error) {
	code := strings.ToUpper(strings.TrimSpace(inviteCode))
	if code == "" || sameDeviceUserCount > 0 {
		return nil, nil
	}

	var inviter model.User
	if err := db.Where("invite_code = ?", code).First(&inviter).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	if inviter.DeviceID != "" && inviter.DeviceID == deviceID {
		return nil, nil
	}
	return &inviter, nil
}

func GrantRegisterReward(db *gorm.DB, inviterID uint64, inviteeID uint64, deviceID string) error {
	return grantTrafficReward(db, inviterID, inviteeID, "register", InviteRegisterRewardBytes, deviceID, nil)
}

func GrantPurchaseReward(db *gorm.DB, invitee model.User, orderID uint64) error {
	if invitee.InviterID == nil || *invitee.InviterID == 0 {
		return nil
	}
	return grantTrafficReward(db, *invitee.InviterID, invitee.ID, "purchase", InvitePurchaseRewardBytes, invitee.DeviceID, &orderID)
}

func grantTrafficReward(db *gorm.DB, inviterID uint64, inviteeID uint64, rewardType string, rewardBytes int64, deviceID string, orderID *uint64) error {
	var count int64
	query := db.Model(&model.InviteRewardLog{}).
		Where("inviter_id = ? AND invitee_id = ? AND reward_type = ?", inviterID, inviteeID, rewardType)
	if orderID != nil {
		query = db.Model(&model.InviteRewardLog{}).Where("order_id = ?", *orderID)
	}
	if err := query.Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}

	return db.Transaction(func(tx *gorm.DB) error {
		log := model.InviteRewardLog{
			InviterID:   inviterID,
			InviteeID:   inviteeID,
			RewardType:  rewardType,
			RewardBytes: rewardBytes,
			DeviceID:    deviceID,
			OrderID:     orderID,
		}
		if err := tx.Create(&log).Error; err != nil {
			return err
		}
		return tx.Model(&model.User{}).
			Where("id = ?", inviterID).
			Update("traffic_limit_bytes", gorm.Expr("CASE WHEN traffic_limit_bytes IS NULL AND current_plan_id IS NOT NULL THEN NULL ELSE COALESCE(traffic_limit_bytes, 0) + ? END", rewardBytes)).
			Error
	})
}

func randomInviteCode(length int) (string, error) {
	buf := make([]byte, length)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	out := make([]byte, length)
	for i, b := range buf {
		out[i] = inviteAlphabet[int(b)%len(inviteAlphabet)]
	}
	return string(out), nil
}
