package main

import (
	"fmt"
	"os"

	"golang.org/x/crypto/bcrypt"
)

// 用于生成管理员密码的 bcrypt 哈希值
// 使用方法: go run tools/gen_password_hash.go <密码>
// 例如: go run tools/gen_password_hash.go admin123456
func main() {
	if len(os.Args) < 2 {
		fmt.Println("使用方法: go run tools/gen_password_hash.go <密码>")
		fmt.Println("例如: go run tools/gen_password_hash.go admin123456")
		os.Exit(1)
	}

	password := os.Args[1]
	
	// 生成 bcrypt 哈希（cost=12）
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		fmt.Printf("生成哈希失败: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("密码:", password)
	fmt.Println("哈希值:", string(hash))
	fmt.Println("\n将以下内容添加到 .env 文件:")
	fmt.Printf("ADMIN_PASSWORD_HASH=%s\n", string(hash))
}
