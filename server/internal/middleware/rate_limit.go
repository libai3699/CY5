package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type rateBucket struct {
	Count     int
	ExpiresAt time.Time
}

var (
	rateMu      sync.Mutex
	rateBuckets = map[string]rateBucket{}
)

func IPRateLimit(name string, max int, window time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		now := time.Now()
		key := name + ":" + c.ClientIP()

		rateMu.Lock()
		bucket := rateBuckets[key]
		if bucket.ExpiresAt.Before(now) {
			bucket = rateBucket{ExpiresAt: now.Add(window)}
		}
		bucket.Count++
		rateBuckets[key] = bucket
		allowed := bucket.Count <= max
		rateMu.Unlock()

		if !allowed {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"code":    429,
				"message": "请求过于频繁，请稍后再试",
				"data":    nil,
			})
			return
		}
		c.Next()
	}
}
