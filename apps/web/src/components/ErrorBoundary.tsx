import { Component, type ErrorInfo, type ReactNode } from 'react';
import { Button } from '@douyinfe/semi-ui';
import { BrandMark } from './BrandMark';

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('页面渲染失败', error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="crash-page">
          <BrandMark size="lg" />
          <p className="eyebrow">A PAGE TURNED BLANK</p>
          <h1>这一页暂时空白</h1>
          <p>页面遇到了一点意外，刷新后可以继续浏览家族记忆。</p>
          <Button theme="solid" type="primary" onClick={() => window.location.reload()}>
            刷新页面
          </Button>
        </div>
      );
    }
    return this.props.children;
  }
}
