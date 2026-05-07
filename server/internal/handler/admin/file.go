package admin

import (
	"bytes"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

var allowedFileKeys = map[string]string{
	"vpn_apk": "download_vpn_apk",
	"acc_apk": "download_acc_apk",
	"vpn_exe": "download_vpn_exe",
	"acc_exe": "download_acc_exe",
}

var allowedExts = map[string]bool{
	".apk": true,
	".exe": true,
}

var fixedFileNames = map[string]string{
	"vpn_apk": "cy5vpn_android.apk",
	"acc_apk": "cy5acc_android.apk",
	"vpn_exe": "cy5vpn_windows.exe",
	"acc_exe": "cy5acc_windows.exe",
}

const maxFileSize = 500 << 20
const maxImageSize = 5 << 20

func ListFiles(c *gin.Context) {
	keys := []string{"download_vpn_apk", "download_acc_apk", "download_vpn_exe", "download_acc_exe"}

	var configs []model.AppConfig
	database.DB.Where("key_name IN ?", keys).Find(&configs)

	result := make(map[string]string)
	for _, key := range keys {
		result[key] = ""
	}
	for _, cfg := range configs {
		result[cfg.KeyName] = cfg.Value
	}

	handler.OK(c, result)
}

func UploadFile(c *gin.Context) {
	fileKey := c.PostForm("file_key")
	configKey, ok := allowedFileKeys[fileKey]
	if !ok {
		handler.Fail(c, 400, fmt.Sprintf("file_key invalid, options: vpn_apk, acc_apk, vpn_exe, acc_exe"))
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxFileSize)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		handler.Fail(c, 400, "file read failed: "+err.Error())
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !allowedExts[ext] {
		handler.Fail(c, 400, "only .apk or .exe files are allowed")
		return
	}
	if !validBinaryHeader(file, ext) {
		handler.Fail(c, 400, "file content does not match extension")
		return
	}

	fileName := fixedFileNames[fileKey]
	if filepath.Ext(fileName) != ext {
		handler.Fail(c, 400, "file_key does not match file extension")
		return
	}

	if err := os.MkdirAll("uploads", 0755); err != nil {
		handler.Fail(c, 500, "create upload directory failed")
		return
	}

	savePath := filepath.Join("uploads", fileName)
	if err := c.SaveUploadedFile(header, savePath); err != nil {
		handler.Fail(c, 500, "file save failed: "+err.Error())
		return
	}

	url := "/uploads/" + fileName
	database.DB.Model(&model.AppConfig{}).
		Where("key_name = ?", configKey).
		Update("value", url)

	handler.OK(c, gin.H{"key": configKey, "url": url})
}

func UploadPaymentImage(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxImageSize)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		handler.Fail(c, 400, "image read failed: "+err.Error())
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(header.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp", ".gif":
	default:
		handler.Fail(c, 400, "only .jpg, .jpeg, .png, .webp or .gif images are allowed")
		return
	}
	if !validImageHeader(file, ext) {
		handler.Fail(c, 400, "image content does not match extension")
		return
	}

	if err := os.MkdirAll(filepath.Join("uploads", "payment"), 0755); err != nil {
		handler.Fail(c, 500, "create upload directory failed")
		return
	}

	fileName := fmt.Sprintf("payment_%d%s", time.Now().UnixNano(), ext)
	savePath := filepath.Join("uploads", "payment", fileName)
	if err := c.SaveUploadedFile(header, savePath); err != nil {
		handler.Fail(c, 500, "image save failed: "+err.Error())
		return
	}

	handler.OK(c, gin.H{"url": absoluteUploadURL(c, "/uploads/payment/" + fileName)})
}

func absoluteUploadURL(c *gin.Context, value string) string {
	if value == "" || strings.HasPrefix(value, "http://") || strings.HasPrefix(value, "https://") {
		return value
	}
	if !strings.HasPrefix(value, "/") {
		value = "/" + value
	}
	proto := c.GetHeader("X-Forwarded-Proto")
	if proto == "" {
		if c.Request.TLS != nil {
			proto = "https"
		} else {
			proto = "http"
		}
	}
	host := c.GetHeader("X-Forwarded-Host")
	if host == "" {
		host = c.Request.Host
	}
	if proto == "http" && !strings.HasPrefix(host, "localhost") && !strings.HasPrefix(host, "127.0.0.1") {
		proto = "https"
	}
	return proto + "://" + host + value
}

func validBinaryHeader(file multipartFile, ext string) bool {
	header := readHeader(file)
	switch ext {
	case ".apk":
		return len(header) >= 4 && bytes.Equal(header[:4], []byte{'P', 'K', 3, 4})
	case ".exe":
		return len(header) >= 2 && bytes.Equal(header[:2], []byte{'M', 'Z'})
	default:
		return false
	}
}

func validImageHeader(file multipartFile, ext string) bool {
	header := readHeader(file)
	switch ext {
	case ".jpg", ".jpeg":
		return len(header) >= 3 && bytes.Equal(header[:3], []byte{0xff, 0xd8, 0xff})
	case ".png":
		return len(header) >= 8 && bytes.Equal(header[:8], []byte{0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a})
	case ".gif":
		return len(header) >= 6 && (bytes.Equal(header[:6], []byte("GIF87a")) || bytes.Equal(header[:6], []byte("GIF89a")))
	case ".webp":
		return len(header) >= 12 && bytes.Equal(header[:4], []byte("RIFF")) && bytes.Equal(header[8:12], []byte("WEBP"))
	default:
		return false
	}
}

type multipartFile interface {
	Read([]byte) (int, error)
	Seek(int64, int) (int64, error)
}

func readHeader(file multipartFile) []byte {
	buf := make([]byte, 512)
	n, _ := file.Read(buf)
	file.Seek(0, 0)
	return buf[:n]
}

func DeleteFile(c *gin.Context) {
	key := c.Param("key")
	if _, ok := allowedFileKeys[key]; !ok {
		validConfigKeys := map[string]bool{
			"download_vpn_apk": true,
			"download_acc_apk": true,
			"download_vpn_exe": true,
			"download_acc_exe": true,
		}
		if !validConfigKeys[key] {
			handler.Fail(c, 400, "key invalid")
			return
		}
	}

	configKey := key
	if ck, ok := allowedFileKeys[key]; ok {
		configKey = ck
	}

	database.DB.Model(&model.AppConfig{}).
		Where("key_name = ?", configKey).
		Update("value", "")

	handler.OK(c, gin.H{"msg": "download url cleared"})
}
