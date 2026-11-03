import { Button } from '@douyinfe/semi-ui';
import { IconRefresh } from '@douyinfe/semi-icons';

interface ErrorStateProps {
  title?: string;
  description?: string;
  onRetry?: () => void;
}

export function ErrorState({
  title = '暂时无法加载',
  description = '网络似乎开了小差，请稍后再试。',
  onRetry,
}: ErrorStateProps) {
  return (
    <div className="error-state">
      <div className="error-state__mark" aria-hidden>
        雨
      </div>
      <div>
        <h3>{title}</h3>
        <p>{description}</p>
        {onRetry ? (
          <Button icon={<IconRefresh />} theme="light" onClick={onRetry} className="error-state__btn">
            重新加载
          </Button>
        ) : null}
      </div>
    </div>
  );
}
