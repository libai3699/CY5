package middleware

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"time"

	"cy5vpn/server/internal/config"

	"github.com/gin-gonic/gin"
)

var (
	nonceMu    sync.Mutex
	nonceStore = map[string]time.Time{}
)

// SignRequired 接口签名验证（设备注册、心跳等无需登录的高频接口）
// 请求头：X-Device-Id, X-Timestamp, X-Nonce, X-Sign
func SignRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		deviceID := c.GetHeader("X-Device-Id")
		timestampStr := c.GetHeader("X-Timestamp")
		nonce := c.GetHeader("X-Nonce")
		sign := c.GetHeader("X-Sign")

		if deviceID == "" || timestampStr == "" || nonce == "" || sign == "" {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"code": 400, "msg": "缺少签名头"})
			return
		}

		// 验证时间戳（±300秒）
		ts, err := strconv.ParseInt(timestampStr, 10, 64)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"code": 400, "msg": "时间戳格式错误"})
			return
		}
		diff := time.Now().Unix() - ts
		if diff > 300 || diff < -300 {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"code": 400, "msg": "请求已过期"})
			return
		}
		if !consumeNonce(deviceID, nonce, time.Unix(ts, 0).Add(5*time.Minute)) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"code": 403, "msg": "请求已被重放"})
			return
		}

		// 验证签名
		expected := calcSign(deviceID, timestampStr, nonce)
		if !hmac.Equal([]byte(sign), []byte(expected)) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"code": 403, "msg": "签名验证失败"})
			return
		}

		c.Set("device_id_from_sign", deviceID)
		c.Next()
	}
}

func consumeNonce(deviceID, nonce string, expiresAt time.Time) bool {
	now := time.Now()
	key := deviceID + ":" + nonce

	nonceMu.Lock()
	defer nonceMu.Unlock()

	for k, exp := range nonceStore {
		if exp.Before(now) {
			delete(nonceStore, k)
		}
	}
	if _, exists := nonceStore[key]; exists {
		return false
	}
	nonceStore[key] = expiresAt
	return true
}

// calcSign 计算 HMAC-SHA256 签名
func calcSign(deviceID, timestamp, nonce string) string {
	message := fmt.Sprintf("%s:%s:%s", deviceID, timestamp, nonce)
	mac := hmac.New(sha256.New, []byte(config.App.AppSecret))
	mac.Write([]byte(message))
	return hex.EncodeToString(mac.Sum(nil))
}
