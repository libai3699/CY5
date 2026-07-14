# 易支付接入与测试

本实现对应易支付当前的[页面跳转支付](https://www.ezfpy.cn/doc)和[支付结果通知](https://www.ezfpy.cn/doc/result)协议。

## 1. 必须手动准备和确认

向易支付服务商取得并确认以下信息：

- 商户 PID 和商户密钥 KEY。
- 收银台地址。当前默认是 `https://www.ezfpy.cn/submit.php`，必须向服务商确认该域名确实属于你的服务商。
- 支付类型使用 `alipay`、`wxpay` 和 `qqpay`，签名方式为“参数字典序拼接后追加 KEY，再做 MD5”。
- 异步通知成功时是否要求响应纯文本 `success`。
- 商户后台已经启用支付宝、微信和 QQ 通道，并且允许你的服务器域名作为通知域名。

生产环境必须有一个外网可访问的 HTTPS API 域名，例如 `https://api.example.com`。`localhost`、局域网 IP 和 App 自定义协议都不能作为异步通知地址。

## 2. 服务端环境变量

在服务器的 `.env` 或运行环境中加入：

```dotenv
EPAY_GATEWAY_URL=https://www.ezfpy.cn/submit.php
EPAY_PID=服务商提供的PID
EPAY_KEY=服务商提供的KEY
EPAY_NOTIFY_URL=https://api.example.com/api/public/payment/notify
EPAY_RETURN_URL=https://api.example.com/api/public/payment/return
EPAY_SITENAME=CY5
```

不要把 `EPAY_KEY` 写入 Flutter、后台前端、Git 仓库或聊天截图。修改后重启 Go 服务。启动时 `AutoMigrate` 会自动创建 `payment_orders` 表。

反向代理需要把上述两个回调路径原样转发到 Go 服务，不能要求 JWT、验证码或登录，也不要将网关的 POST 表单改成 JSON。

## 3. 不花真钱的联调

先登录 App，或者用登录接口拿到 JWT。以下 PowerShell 示例会创建一笔真实的“待支付订单”，但不会访问第三方收银台：

```powershell
$token = '登录后拿到的JWT'
$headers = @{ Authorization = "Bearer $token" }
$body = @{ plan_id = 1; billing_cycle = 'month'; pay_type = 'alipay' } | ConvertTo-Json
$result = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8080/api/public/payment/orders' -Headers $headers -ContentType 'application/json' -Body $body
$result.data
```

记下返回的 `order_no` 和 `amount`，在另一个 PowerShell 窗口模拟一条签名正确的成功通知：

```powershell
$env:EPAY_PID='你的PID'
$env:EPAY_KEY='你的KEY'
& 'C:\Program Files\Go\bin\go.exe' run ./cmd/mock_epay_callback -base-url http://127.0.0.1:8080 -order '上一步的order_no' -money '上一步的amount' -trade 'MOCK-001'
```

预期输出是 `HTTP 200: success`。然后检查：

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/public/payment/orders/上一步的order_no" -Headers $headers
```

预期 `data.status` 为 `paid`。App 用户状态中套餐和到期时间应更新，购买记录中应新增一条订单。

再次运行完全相同的模拟通知，确认仍返回 `success`，但 `order_records` 只能有一条对应记录、套餐时长不能再次增加。这是在验证重复通知幂等。

再做两项反向测试：将 `-money` 改错，或临时使用错误的 `EPAY_KEY`。预期回调返回 `fail`，订单保持 `pending`，用户套餐不变化。

## 4. App 和真实支付测试

1. 重新执行 `flutter pub get` 并重新构建 App；本次新增了系统浏览器打开能力。
2. 使用测试账号登录，选择最低价套餐。
3. 选择支付宝或微信，点击“前往在线支付”。浏览器会先短暂打开你的 `EPAY_NOTIFY_URL` 同域收银台桥接页，再以 POST 跳到 `EPAY_GATEWAY_URL`。确认最终域名、订单号、商品名和金额正确。
4. 完成一笔小额真实付款，回到 App 点击“检查到账”。正常结果是提示“支付已到账，套餐已自动开通”。
5. 在易支付商户后台确认异步通知 HTTP 状态为 200、响应正文为 `success`；在服务器日志中不应出现 `[EPAY] notify rejected`。
6. 确认数据库 `payment_orders.status=paid`、`gateway_trade_no` 已保存、`order_records` 新增一条，用户 `plan_expired_at` 和流量额度正确。
7. 确认服务商重发通知不会重复开通；确认未付款/取消付款的订单保持 `pending`。

USDT 仍是原有的人工转账和联系客服流程，不会触发自动到账。

## 5. 上线前检查清单

- 回调域名是有效 HTTPS，公网可访问，证书链正常。
- PID、KEY、网关 URL 都从商户后台复制并二次核对，KEY 未进入客户端或日志。
- Nginx/CDN/WAF 没有拦截网关回调，且保留查询参数和表单字段。
- 服务器时区和数据库备份正常；先用最低金额套餐完成一笔真实闭环。
- 商户后台的实收金额、CY5 `payment_orders.amount_cents`、购买记录金额三者一致。
- 真实支付成功、取消支付、错误金额、错误签名、重复通知五种场景均按预期完成。
