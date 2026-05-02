package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// OK 成功响应
func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, gin.H{
		"code":    0,
		"message": "ok",
		"data":    data,
	})
}

// Fail 失败响应
func Fail(c *gin.Context, code int, msg string) {
	c.JSON(http.StatusOK, gin.H{
		"code":    code,
		"message": msg,
		"data":    nil,
	})
}

// FailStatus 带 HTTP 状态码的失败响应
func FailStatus(c *gin.Context, httpStatus int, code int, msg string) {
	c.JSON(httpStatus, gin.H{
		"code":    code,
		"message": msg,
		"data":    nil,
	})
}
