package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	// 数据库
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string

	// JWT
	JWTSecret      string
	AdminJWTSecret string

	// 管理员
	AdminUsername      string
	AdminPasswordHash  string
	AdminCaptchaSecret string
	AdminRole          string

	// AES + HMAC 密钥
	AppSecret string

	// 服务
	ServerPort string
	GinMode    string

	// 云存储
	StorageProvider string

	// 阿里云 OSS
	OSSEndpoint        string
	OSSAccessKeyID     string
	OSSAccessKeySecret string
	OSSBucket          string

	// 腾讯云 COS
	COSRegion    string
	COSSecretID  string
	COSSecretKey string
	COSBucket    string

	// MinIO
	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOBucket    string
	MinIOUseSSL    string

	// 易支付（支付宝/微信聚合支付）
	EPayGatewayURL string
	EPayPID        string
	EPayKey        string
	EPayNotifyURL  string
	EPayReturnURL  string
	EPaySiteName   string
}

var App Config

func Load() {
	_ = godotenv.Load(".env.local")
	if err := godotenv.Load(); err != nil {
		log.Println("[config] .env 文件未找到，使用系统环境变量")
	}

	App = Config{
		DBHost:     getEnv("DB_HOST", "127.0.0.1"),
		DBPort:     getEnv("DB_PORT", "3306"),
		DBUser:     getEnv("DB_USER", "root"),
		DBPassword: getEnv("DB_PASSWORD", "root"),
		DBName:     getEnv("DB_NAME", "cy5_vpn"),

		JWTSecret:      mustEnv("JWT_SECRET"),
		AdminJWTSecret: mustEnv("ADMIN_JWT_SECRET"),

		AdminUsername:      getEnv("ADMIN_USERNAME", "admin"),
		AdminPasswordHash:  mustEnv("ADMIN_PASSWORD_HASH"),
		AdminCaptchaSecret: mustEnv("ADMIN_CAPTCHA_SECRET"),
		AdminRole:          getEnv("ADMIN_ROLE", "super_admin"),

		AppSecret: mustEnv("APP_SECRET"),

		ServerPort:      getEnv("SERVER_PORT", "8080"),
		GinMode:         getEnv("GIN_MODE", "debug"),
		StorageProvider: getEnv("STORAGE_PROVIDER", ""),

		OSSEndpoint:        getEnv("OSS_ENDPOINT", ""),
		OSSAccessKeyID:     getEnv("OSS_ACCESS_KEY_ID", ""),
		OSSAccessKeySecret: getEnv("OSS_ACCESS_KEY_SECRET", ""),
		OSSBucket:          getEnv("OSS_BUCKET", ""),

		COSRegion:    getEnv("COS_REGION", ""),
		COSSecretID:  getEnv("COS_SECRET_ID", ""),
		COSSecretKey: getEnv("COS_SECRET_KEY", ""),
		COSBucket:    getEnv("COS_BUCKET", ""),

		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", ""),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", ""),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", ""),
		MinIOBucket:    getEnv("MINIO_BUCKET", ""),
		MinIOUseSSL:    getEnv("MINIO_USE_SSL", "false"),

		EPayGatewayURL: getEnv("EPAY_GATEWAY_URL", "https://www.ezfpy.cn/submit.php"),
		EPayPID:        getEnv("EPAY_PID", ""),
		EPayKey:        getEnv("EPAY_KEY", ""),
		EPayNotifyURL:  getEnv("EPAY_NOTIFY_URL", ""),
		EPayReturnURL:  getEnv("EPAY_RETURN_URL", ""),
		EPaySiteName:   getEnv("EPAY_SITENAME", "CY5"),
	}
}

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("[config] 必填环境变量 %s 未设置", key)
	}
	return v
}
