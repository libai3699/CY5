import type { Config } from 'jest';

const config: Config = {
  projects: [
    // Node 环境：加解密模块 + Route Handler 测试
    {
      displayName: 'node',
      testEnvironment: 'node',
      testMatch: ['**/__tests__/crypto.test.ts', '**/__tests__/route.test.ts'],
      transform: {
        '^.+\\.tsx?$': ['ts-jest', {
          tsconfig: {
            module: 'commonjs',
            esModuleInterop: true,
          },
        }],
      },
      moduleNameMapper: {
        '^@/(.*)$': '<rootDir>/$1',
      },
    },
    // jsdom 环境：React 组件测试
    {
      displayName: 'jsdom',
      testEnvironment: 'jest-environment-jsdom',
      testMatch: ['**/__tests__/*.test.tsx'],
      transform: {
        '^.+\\.tsx?$': ['ts-jest', {
          tsconfig: {
            module: 'commonjs',
            esModuleInterop: true,
            jsx: 'react-jsx',
          },
        }],
      },
      moduleNameMapper: {
        '^@/(.*)$': '<rootDir>/$1',
      },
      setupFilesAfterFramework: ['<rootDir>/jest.setup.ts'],
    },
  ],
};

export default config;
