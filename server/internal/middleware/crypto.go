package middleware

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"io"
	"net/http"

	"cy5vpn/server/internal/config"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/hkdf"
)

// deriveAESKey 从 APP_SECRET 派生 32 字节 AES 密钥
func deriveAESKey() []byte {
	secret := []byte(config.App.AppSecret)
	salt := []byte("cy5vpn-aes-key-v1")
	info := []byte("aes-256-gcm")

	reader := hkdf.New(sha256.New, secret, salt, info)
	key := make([]byte, 32)
	if _, err := io.ReadFull(reader, key); err != nil {
		panic("derive aes key failed: " + err.Error())
	}
	return key
}

// AESEncrypt 加密数据，返回 Base64(IV + CipherText + Tag)
func AESEncrypt(plaintext []byte) (string, error) {
	key := deriveAESKey()

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	iv := make([]byte, gcm.NonceSize()) // 12 字节
	if _, err = io.ReadFull(rand.Reader, iv); err != nil {
		return "", err
	}

	// Seal 会把 Tag 附在密文末尾
	ciphertext := gcm.Seal(iv, iv, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// AESDecrypt 解密 Base64(IV + CipherText + Tag)
func AESDecrypt(encoded string) ([]byte, error) {
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, err
	}

	key := deriveAESKey()
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return nil, errors.New("ciphertext too short")
	}

	iv, ciphertext := data[:nonceSize], data[nonceSize:]
	return gcm.Open(nil, iv, ciphertext, nil)
}

// responseWriter 包装 gin.ResponseWriter，拦截响应 body
type responseWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	return rw.body.Write(b)
}

// CryptoMiddleware 自动解密请求 body，加密响应 body
func CryptoMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// ── 解密请求 body ──────────────────────────────────────────
		if c.Request.ContentLength != 0 && c.Request.Body != nil {
			raw, err := io.ReadAll(c.Request.Body)
			if err != nil {
				c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"code": 400, "msg": "读取请求体失败"})
				return
			}

			if len(raw) > 0 {
				plaintext, err := AESDecrypt(string(raw))
				if err != nil {
					c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"code": 400, "msg": "请求解密失败"})
					return
				}
				// 替换 body 为解密后的明文
				c.Request.Body = io.NopCloser(bytes.NewBuffer(plaintext))
				c.Request.ContentLength = int64(len(plaintext))
				c.Request.Header.Set("Content-Type", "application/json")
			}
		}

		// ── 拦截响应 body ──────────────────────────────────────────
		rw := &responseWriter{
			ResponseWriter: c.Writer,
			body:           &bytes.Buffer{},
		}
		c.Writer = rw

		c.Next()

		// ── 加密响应 body ──────────────────────────────────────────
		if rw.body.Len() > 0 {
			encrypted, err := AESEncrypt(rw.body.Bytes())
			if err != nil {
				// 加密失败时降级返回明文（不应发生）
				rw.ResponseWriter.Write(rw.body.Bytes())
				return
			}
			rw.ResponseWriter.Header().Set("Content-Type", "text/plain; charset=utf-8")
			rw.ResponseWriter.WriteHeader(rw.Status())
			rw.ResponseWriter.Write([]byte(encrypted))
		}
	}
}
