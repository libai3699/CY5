// 配置项
const envDev = require('./env/dev.js');
const envProd = require('./env/prod.js');

const compileEnv = process.env.APP_ENV || 'dev';

// 环境配置字典
const config = {
  // 开发环境配置
  dev: envDev,
  // 生产环境配置
  prod: envProd
};

// 最终应用的环境 - 编译环境
let CONFIG = config[compileEnv];

// 公共配置
const configCommon = {
  // 默认分页大小
  pageSize: 10
};

// 合并公共配置
CONFIG = Object.assign({}, configCommon, CONFIG);

module.exports = CONFIG;
module.exports.compileEnv = compileEnv;
module.exports.APP_ENV = process.env.APP_ENV || 'dev';
