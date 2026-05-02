package main

import (
	"fmt"
	"os"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	password := "admin123456"
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		panic(err)
	}
	result := string(hash)
	fmt.Printf("password: %s\nhash: %s\n", password, result)
	os.WriteFile("hash_result.txt", []byte(result), 0644)
	fmt.Println("已写入 hash_result.txt")
}
