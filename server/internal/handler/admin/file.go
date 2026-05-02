package admin

import (
	"fmt"
	"net/http"
	"path/filepath"
	"strings"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// 允许的文件类型和对应的 config key
var allowedFileKeys = map[string]string{
	"vpn_apk": "download_vpn_apk",
	"acc_apk": "download_acc_apk",
	"vpn_exe": "download_vpn_exe",
	"acc_exe": "download_acc_exe",
}

// 允许的扩展名
var allowedExts = map[string]bool{
	".apk": true,
	".exe": true,
}

const maxFileSize = 500 << 20 // 500MB

// ListFiles 查看4个安装包当前状态
func ListFiles(c *gin.Context) {
	keys := []string{"download_vpn_apk", "download_acc_apk", "download_vpn_exe", "download_acc_exe"}

	var configs []model.AppConfig
	database.DB.Where("key_name IN ?", keys).Find(&configs)

	result := make(map[string]string)
	for _, cfg := range configs {
		result[cfg.KeyName] = cfg.Value
	}

	handler.OK(c, result)
}

// UploadFile 上传安装包（multipart/form-data）
// 字段：file_key（vpn_apk/acc_apk/vpn_exe/acc_exe），file（文件）
func UploadFile(c *gin.Context) {
	fileKey := c.PostForm("file_key")
	configKey, ok := allowedFileKeys[fileKey]
	if !ok {
		handler.Fail(c, 400, fmt.Sprintf("file_key 无效，可选值: vpn_apk, acc_apk, vpn_exe, acc_exe"))
		return
	}

	// 限制文件大小
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxFileSize)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		handler.Fail(c, 400, "文件读取失败: "+err.Error())
		return
	}
	defer file.Close()

	// 验证扩展名
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !allowedExts[ext] {
		handler.Fail(c, 400, "只允许上传 .apk 或 .exe 文件")
		return
	}

	// TODO: 云存储上传（待接入，当前返回占位提示）
	// 接入云存储后，替换此处逻辑：
	//   url, err := storage.Upload(fileKey+ext, file)
	//   if err != nil { ... }
	//   更新 app_configs[configKey] = url

	// 临时：返回提示，等云存储配置好后实现
	_ = configKey
	handler.Fail(c, 501, "云存储未配置，请先在 .env 中设置 STORAGE_PROVIDER")
}

// DeleteFile 删除文件（清空对应配置链接）
func DeleteFile(c *gin.Context) {
	key := c.Param("key")
	if _, ok := allowedFileKeys[key]; !ok {
		// 也支持直接传 config key
		validConfigKeys := map[string]bool{
			"download_vpn_apk": true,
			"download_acc_apk": true,
			"download_vpn_exe": true,
			"download_acc_exe": true,
		}
		if !validConfigKeys[key] {
			handler.Fail(c, 400, "key 无效")
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

	handler.OK(c, gin.H{"msg": "已清空下载链接"})
}
