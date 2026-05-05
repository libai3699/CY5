/**
 * DownloadCard 组件属性测试
 * Feature: official-website
 */

import * as React from 'react';
import * as fc from 'fast-check';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import DownloadCard from '../components/DownloadCard';

// ── 属性 4：卡片渲染包含必要信息 ─────────────────────────────────────────────

describe('属性 4：卡片渲染包含必要信息', () => {
  /**
   * Validates: Requirements 2.4
   *
   * Feature: official-website, Property 4: 卡片渲染包含必要信息
   * 对于任意非空版本号的 DownloadCardProps，渲染 DownloadCard 组件后，
   * 输出的 DOM 必须同时包含应用名称文本和版本号文本。
   */
  it('非空版本号时应同时渲染应用名和版本号', () => {
    fc.assert(
      fc.property(
        fc.record({
          appName: fc.string({ minLength: 1 }),
          version: fc.string({ minLength: 1 }), // 非空版本号
          downloadUrl: fc.webUrl(),
          disabled: fc.boolean(),
        }),
        (props) => {
          const { unmount } = render(
            <DownloadCard
              appName={props.appName}
              version={props.version}
              downloadUrl={props.downloadUrl}
              disabled={props.disabled}
            />,
          );

          // 应用名称必须存在
          const hasAppName = !!screen.queryByText(props.appName);
          // 版本号必须存在（格式为 v{version}）
          const hasVersion = !!screen.queryByText(`v${props.version}`);

          unmount();
          return hasAppName && hasVersion;
        },
      ),
      { numRuns: 100 },
    );
  });
});

// ── 版本号为空时不渲染版本号元素 ─────────────────────────────────────────────

describe('版本号为空时不渲染版本号元素', () => {
  it('version 为空字符串时不应渲染版本号', () => {
    render(
      <DownloadCard
        appName="9.9 VPN"
        version=""
        downloadUrl="https://example.com/vpn.apk"
        disabled={false}
      />,
    );

    // 不应该有 v 开头的版本号文本
    const versionElements = screen.queryAllByText(/^v\S+/);
    expect(versionElements).toHaveLength(0);
  });

  it('version 非空时应渲染版本号', () => {
    render(
      <DownloadCard
        appName="9.9 VPN"
        version="1.2.3"
        downloadUrl="https://example.com/vpn.apk"
        disabled={false}
      />,
    );

    expect(screen.getByText('v1.2.3')).toBeInTheDocument();
  });
});

// ── 按钮状态测试 ──────────────────────────────────────────────────────────────

describe('下载按钮状态', () => {
  it('disabled=true 时按钮应禁用并显示"暂未开放"', () => {
    render(
      <DownloadCard
        appName="9.9 VPN"
        version="1.0.0"
        downloadUrl=""
        disabled={true}
        testId="vpn-download-btn"
      />,
    );

    const btn = screen.getByTestId('vpn-download-btn');
    expect(btn).toBeDisabled();
    expect(btn).toHaveTextContent('暂未开放');
  });

  it('disabled=false 时应渲染下载链接并显示"立即下载"', () => {
    render(
      <DownloadCard
        appName="9.9 VPN"
        version="1.0.0"
        downloadUrl="https://example.com/vpn.apk"
        disabled={false}
        testId="vpn-download-btn"
      />,
    );

    const link = screen.getByTestId('vpn-download-btn');
    expect(link.tagName).toBe('A');
    expect(link).toHaveAttribute('href', 'https://example.com/vpn.apk');
    expect(link).toHaveTextContent('立即下载');
  });
});
