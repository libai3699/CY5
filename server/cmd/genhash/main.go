package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	password := "admin123456"
	// 验证 .env 里的哈希
	storedHash := "$2a$12$Nztcu89rzq1upVvQwePBIuFrP5sHziRiYqDc2T07EYeqgAQj.twEG"
	err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(password))
	if err != nil {
		fmt.Println("验证失败:", err)
		// 重新生成
		hash, _ := bcrypt.GenerateFromPassword([]byte(password), 12)
		fmt.Println("新哈希:", string(hash))
	} else {
		fmt.Println("验证成功！哈希正确")
	}
}
