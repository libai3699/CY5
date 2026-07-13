package service

import (
	"crypto/md5"
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"math"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	"cy5vpn/server/internal/model"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// EPaySignString 按易支付协议排序并拼接待签名参数。
func EPaySignString(values url.Values) string {
	keys := make([]string, 0, len(values))
	for key := range values {
		if key == "sign" || key == "sign_type" || values.Get(key) == "" {
			continue
		}
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		parts = append(parts, key+"="+values.Get(key))
	}
	return strings.Join(parts, "&")
}

func EPaySign(values url.Values, key string) string {
	sum := md5.Sum([]byte(EPaySignString(values) + key))
	return hex.EncodeToString(sum[:])
}

func VerifyEPaySign(values url.Values, key string) bool {
	received := strings.ToLower(values.Get("sign"))
	expected := EPaySign(values, key)
	if len(received) != len(expected) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(received), []byte(expected)) == 1
}

func BuildEPayURL(gatewayURL string, values url.Values, key string) (string, error) {
	gateway, err := url.Parse(gatewayURL)
	if err != nil || gateway.Scheme == "" || gateway.Host == "" {
		return "", fmt.Errorf("invalid EPAY_GATEWAY_URL")
	}
	values.Set("sign", EPaySign(values, key))
	values.Set("sign_type", "MD5")
	gateway.RawQuery = values.Encode()
	return gateway.String(), nil
}

// ParseMoneyCents 严格解析网关金额，避免浮点取整把 9.904 误认为 9.90。
func ParseMoneyCents(value string) (int64, error) {
	parts := strings.Split(strings.TrimSpace(value), ".")
	if len(parts) > 2 || parts[0] == "" {
		return 0, fmt.Errorf("invalid money")
	}
	whole, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil || whole < 0 {
		return 0, fmt.Errorf("invalid money")
	}
	fraction := int64(0)
	if len(parts) == 2 {
		if len(parts[1]) == 0 || len(parts[1]) > 2 {
			return 0, fmt.Errorf("invalid money")
		}
		fraction, err = strconv.ParseInt(parts[1], 10, 64)
		if err != nil || fraction < 0 {
			return 0, fmt.Errorf("invalid money")
		}
		if len(parts[1]) == 1 {
			fraction *= 10
		}
	}
	if whole > (math.MaxInt64-fraction)/100 {
		return 0, fmt.Errorf("money overflow")
	}
	return whole*100 + fraction, nil
}

// PurchaseTerms 始终在服务端计算，客户端传入的金额不会参与支付。
func PurchaseTerms(plan model.Plan, cycle string) (months int, amountCents int64, err error) {
	discount := 1.0
	switch cycle {
	case "month":
		months = 1
	case "quarter":
		months = 3
		if plan.DiscountQuarter == nil {
			return 0, 0, fmt.Errorf("该套餐不支持季付")
		}
		discount = *plan.DiscountQuarter
	case "half_year":
		months = 6
		if plan.DiscountHalfYear == nil {
			return 0, 0, fmt.Errorf("该套餐不支持半年付")
		}
		discount = *plan.DiscountHalfYear
	case "year":
		months = 12
		if plan.DiscountYear == nil {
			return 0, 0, fmt.Errorf("该套餐不支持年付")
		}
		discount = *plan.DiscountYear
	default:
		return 0, 0, fmt.Errorf("不支持的购买周期")
	}
	if plan.Price <= 0 || discount <= 0 || discount > 1 {
		return 0, 0, fmt.Errorf("套餐价格配置无效")
	}
	amountCents = int64(math.Round(plan.Price * float64(months) * discount * 100))
	if amountCents <= 0 {
		return 0, 0, fmt.Errorf("订单金额无效")
	}
	return months, amountCents, nil
}

func NewPaymentOrderNo() (string, error) {
	random := make([]byte, 5)
	if _, err := rand.Read(random); err != nil {
		return "", err
	}
	return time.Now().Format("20060102150405") + strings.ToUpper(hex.EncodeToString(random)), nil
}

func NewPaymentCheckoutToken() (string, error) {
	random := make([]byte, 16)
	if _, err := rand.Read(random); err != nil {
		return "", err
	}
	return hex.EncodeToString(random), nil
}

// CompletePayment 在一个事务内锁定支付订单、生成购买记录并更新套餐，保证重复通知不会重复到账。
func CompletePayment(db *gorm.DB, orderNo, gatewayTradeNo string) (*model.PaymentOrder, error) {
	var completed model.PaymentOrder
	err := db.Transaction(func(tx *gorm.DB) error {
		var payment model.PaymentOrder
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("order_no = ?", orderNo).First(&payment).Error; err != nil {
			return err
		}
		if payment.Status == "paid" {
			completed = payment
			return nil
		}

		var user model.User
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&user, payment.UserID).Error; err != nil {
			return err
		}
		now := time.Now()
		startsAt := now
		if user.PlanExpiredAt != nil && user.PlanExpiredAt.After(startsAt) {
			startsAt = *user.PlanExpiredAt
		}
		expiresAt := startsAt.AddDate(0, 0, payment.DurationDays)

		var trafficLimit *int64
		if payment.TrafficGB != nil {
			bytes := int64(*payment.TrafficGB) * 1024 * 1024 * 1024
			if user.TrafficLimitBytes != nil && *user.TrafficLimitBytes > user.TrafficUsedBytes {
				bytes += *user.TrafficLimitBytes - user.TrafficUsedBytes
			}
			trafficLimit = &bytes
		}

		record := model.OrderRecord{
			UserID: payment.UserID, PlanID: payment.PlanID, PlanName: payment.PlanName,
			PlanPrice: float64(payment.AmountCents) / 100, TrafficGB: payment.TrafficGB,
			DurationDays: payment.DurationDays, StartedAt: now, ExpiredAt: expiresAt,
			PayMethod: payment.PayType, PayTradeNo: gatewayTradeNo,
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}
		if err := tx.Model(&user).Updates(map[string]interface{}{
			"current_plan_id": payment.PlanID, "plan_expired_at": expiresAt,
			"traffic_used_bytes": 0, "traffic_limit_bytes": trafficLimit,
		}).Error; err != nil {
			return err
		}
		paidAt := now
		if err := tx.Model(&payment).Updates(map[string]interface{}{
			"status": "paid", "gateway_trade_no": gatewayTradeNo,
			"order_record_id": record.ID, "paid_at": paidAt,
		}).Error; err != nil {
			return err
		}
		payment.Status = "paid"
		payment.GatewayTradeNo = gatewayTradeNo
		payment.OrderRecordID = &record.ID
		payment.PaidAt = &paidAt
		completed = payment
		return nil
	})
	if err != nil {
		return nil, err
	}

	var user model.User
	if completed.OrderRecordID != nil && db.First(&user, completed.UserID).Error == nil {
		_ = GrantPurchaseReward(db, user, *completed.OrderRecordID)
	}
	return &completed, nil
}
