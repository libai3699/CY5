package admin

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

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
