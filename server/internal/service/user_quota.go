package service

import (
	"time"

	"cy5vpn/server/internal/model"
)

// PlanQuotaView 套餐时长/流量展示口径（联动后）。
type PlanQuotaView struct {
	HasPlan          bool
	RemainingSeconds int
	TrafficRemaining string
	TrafficLeftBytes int64
	TrafficUnlimited bool
}

// BuildPlanQuotaView 计算展示值；任一项为 0，则另一项也视为 0。
func BuildPlanQuotaView(user model.User, formatGB func(int64) string) PlanQuotaView {
	now := time.Now()
	hasPlan := user.PlanExpiredAt != nil && user.PlanExpiredAt.After(now)
	if !hasPlan {
		return PlanQuotaView{
			HasPlan:          false,
			RemainingSeconds: 0,
			TrafficRemaining: "0 GB",
			TrafficLeftBytes: 0,
		}
	}

	secs := int(time.Until(*user.PlanExpiredAt).Seconds())
	if secs < 0 {
		secs = 0
	}

	trafficUnlimited := user.TrafficLimitBytes == nil
	trafficLeft := int64(0)
	trafficText := "0 GB"
	if trafficUnlimited {
		trafficText = "不限流量"
		trafficLeft = -1
	} else {
		trafficLeft = *user.TrafficLimitBytes - user.TrafficUsedBytes
		if trafficLeft < 0 {
			trafficLeft = 0
		}
		trafficText = formatGB(trafficLeft)
	}

	timeZero := secs <= 0
	trafficZero := !trafficUnlimited && trafficLeft <= 0
	if timeZero || trafficZero {
		return PlanQuotaView{
			HasPlan:          false,
			RemainingSeconds: 0,
			TrafficRemaining: "0 GB",
			TrafficLeftBytes: 0,
		}
	}

	return PlanQuotaView{
		HasPlan:          true,
		RemainingSeconds: secs,
		TrafficRemaining: trafficText,
		TrafficLeftBytes: trafficLeft,
		TrafficUnlimited: trafficUnlimited,
	}
}

// QuotaCouplingUpdates 任一项耗尽/清零时，同步把另一项也归零到数据库。
func QuotaCouplingUpdates(user model.User) map[string]interface{} {
	now := time.Now()
	hasPlan := user.PlanExpiredAt != nil && user.PlanExpiredAt.After(now)
	if !hasPlan {
		return nil
	}

	secs := int(time.Until(*user.PlanExpiredAt).Seconds())
	if secs < 0 {
		secs = 0
	}

	trafficZero := false
	if user.TrafficLimitBytes != nil {
		left := *user.TrafficLimitBytes - user.TrafficUsedBytes
		trafficZero = left <= 0
	}

	timeZero := secs <= 0
	if !timeZero && !trafficZero {
		return nil
	}

	updates := map[string]interface{}{
		"plan_expired_at": now,
	}
	if user.TrafficLimitBytes != nil {
		updates["traffic_limit_bytes"] = user.TrafficUsedBytes
	}
	return updates
}

// ApplyAdminQuotaCoupling 管理员把时长或流量清零时，联动清零另一项。
func ApplyAdminQuotaCoupling(user model.User, remainingSeconds, trafficRemainingBytes *int64, updates map[string]interface{}) {
	if remainingSeconds != nil && *remainingSeconds == 0 {
		updates["plan_expired_at"] = time.Now()
		updates["traffic_limit_bytes"] = user.TrafficUsedBytes
	}
	if trafficRemainingBytes != nil && *trafficRemainingBytes == 0 {
		updates["plan_expired_at"] = time.Now()
		updates["traffic_limit_bytes"] = user.TrafficUsedBytes
	}
}
