下载phpstudy 打开Mysql 
go run ./cmd/main.go
go mod tidy

 $env:GOOS="linux"; $env:GOARCH="amd64"; $env:CGO_ENABLED="0"; go build -o app
 ./cmd   //打包 放上宝塔 运行 ./app