/**
 * DownloadSection 组件属性测试
 * Feature: official-website
 */

import * as React from 'react';
import * as fc from 'fast-check';
import { render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import DownloadSection from '../components/DownloadSection';
import type { DownloadConfig } from '../types';

// Mock fetch
const mockFetch = jest.fn();
global.fetch = mockFetch;

beforeEach(() => {
  mockFetch.mockReset();
});

// ── 辅助函数 ──────────────────────────────────────────────────────────────────

function mockFetchSuccess(config: DownloadConfig) {
  mockFetch.mockResolvedValueOnce({
    ok: true,
    status: 200,
    json: async () => config,
  } as Response);
}

function mockFetchError() {
  mockFetch.mockRejectedValueOnce(new Error('Network error'));
}

// ── 属性 3：空链接导致对应按钮禁用 ───────────────────────────────────────────

describe('属性 3：空链接导致对应按钮禁用', () => {
  /**
   * Validates: Requirements 1.5, 2.4
   *
   * Feature: official-website, Property 3: 空链接导致对应按钮禁用
   * 对于任意 DownloadConfig，若 vpn_apk 为空字符串，则 VPN 下载按钮必须处于禁用状态；
   * 若 acc_apk 为空字符串，则加速器下载按钮必须处于禁用状态；
   * 非空链接对应的按钮必须处于启用状态。
   */
  it('空链接应禁用对应按钮，非空链接应启用对应按钮', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.record({
          vpn_apk: fc.oneof(fc.constant(''), fc.webUrl()),
          acc_apk: fc.oneof(fc.constant(''), fc.webUrl()),
          vpn_version: fc.string(),
          acc_version: fc.string(),
          contact_wechat: fc.constant(''),
          contact_telegram: fc.constant(''),
          contact_qq: fc.constant(''),
          contact_email: fc.constant(''),
        }),
        async (config) => {
          mockFetchSuccess(config);

          const { unmount } = render(<DownloadSection />);

          // 等待加载完成
          await waitFor(() => {
            expect(screen.queryByTestId('vpn-download-btn')).toBeInTheDocument();
          }, { timeout: 3000 });

          const vpnBtn = screen.getByTestId('vpn-download-btn');
          const accBtn = screen.getByTestId('acc-download-btn');

          const vpnCorrect =
            config.vpn_apk === ''
              ? vpnBtn.hasAttribute('disabled')
              : !vpnBtn.hasAttribute('disabled');

          const accCorrect =
            config.acc_apk === ''
              ? accBtn.hasAttribute('disabled')
              : !accBtn.hasAttribute('disabled');

          unmount();
          return vpnCorrect && accCorrect;
        },
      ),
      { numRuns: 50 }, // 减少迭代次数，因为每次都需要渲染和等待
    );
  });
});

// ── 错误状态测试 ──────────────────────────────────────────────────────────────

describe('错误状态展示', () => {
  it('fetch 失败时应展示错误提示', async () => {
    mockFetchError();

    render(<DownloadSection />);

    await waitFor(() => {
      expect(
        screen.getByText('暂时无法获取下载链接，请稍后重试'),
      ).toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('fetch 失败时两个按钮都应禁用', async () => {
    mockFetchError();

    render(<DownloadSection />);

    await waitFor(() => {
      const vpnBtn = screen.getByTestId('vpn-download-btn');
      const accBtn = screen.getByTestId('acc-download-btn');
      expect(vpnBtn).toBeDisabled();
      expect(accBtn).toBeDisabled();
    }, { timeout: 3000 });
  });
});

// ── 加载状态测试 ──────────────────────────────────────────────────────────────

describe('加载状态', () => {
  it('加载完成后应展示下载卡片', async () => {
    const config: DownloadConfig = {
      vpn_apk: 'https://example.com/vpn.apk',
      acc_apk: 'https://example.com/acc.apk',
      vpn_version: '1.0.0',
      acc_version: '1.0.0',
      contact_wechat: '',
      contact_telegram: '',
      contact_qq: '',
      contact_email: '',
    };
    mockFetchSuccess(config);

    render(<DownloadSection />);

    await waitFor(() => {
      expect(screen.getByText('9.9 VPN')).toBeInTheDocument();
      expect(screen.getByText('9.9 加速器')).toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('加载完成后应展示说明文案', async () => {
    const config: DownloadConfig = {
      vpn_apk: 'https://example.com/vpn.apk',
      acc_apk: '',
      vpn_version: '',
      acc_version: '',
      contact_wechat: '',
      contact_telegram: '',
      contact_qq: '',
      contact_email: '',
    };
    mockFetchSuccess(config);

    render(<DownloadSection />);

    await waitFor(() => {
      expect(
        screen.getByText(/两款应用功能完全一致/),
      ).toBeInTheDocument();
    }, { timeout: 3000 });
  });
});
