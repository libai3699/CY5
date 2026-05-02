// 测试脚本：直接查看登录接口的原始响应
const http = require('http');

const postData = JSON.stringify({
  username: 'vben',
  password: '123456'
});

const options = {
  hostname: 'localhost',
  port: 5320,
  path: '/api/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

const req = http.request(options, (res) => {
  console.log('=== 响应状态码 ===');
  console.log(res.statusCode);
  
  console.log('\n=== 响应头 ===');
  console.log(JSON.stringify(res.headers, null, 2));
  
  let rawData = '';
  
  res.on('data', (chunk) => {
    rawData += chunk;
  });
  
  res.on('end', () => {
    console.log('\n=== 原始响应 Body (字符串) ===');
    console.log(rawData);
    
    console.log('\n=== 原始响应 Body (十六进制) ===');
    console.log(Buffer.from(rawData).toString('hex'));
    
    try {
      const parsed = JSON.parse(rawData);
      console.log('\n=== 解析后的 JSON ===');
      console.log(JSON.stringify(parsed, null, 2));
    } catch (e) {
      console.log('\n=== JSON 解析失败 ===');
      console.log(e.message);
    }
  });
});

req.on('error', (e) => {
  console.error(`请求遇到问题: ${e.message}`);
});

req.write(postData);
req.end();
