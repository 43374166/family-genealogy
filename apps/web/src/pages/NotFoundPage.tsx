import { useNavigate } from 'react-router-dom';
import { Button } from '@douyinfe/semi-ui';
import { IconArrowLeft, IconHome } from '@douyinfe/semi-icons';
import { BrandMark } from '@/components/BrandMark';
import { useDocumentTitle } from '@/hooks/useDocumentTitle';
import './NotFoundPage.scss';

export default function NotFoundPage() {
  useDocumentTitle('页面未找到');
  const navigate = useNavigate();

  return (
    <div className="app-page not-found-page">
      <div className="not-found-page__art">
        <span className="not-found-page__mist" />
        <span className="not-found-page__mountain not-found-page__mountain--back" />
        <span className="not-found-page__mountain not-found-page__mountain--front" />
        <BrandMark size="lg" />
      </div>
      <p className="eyebrow">A LOST PAGE</p>
      <h1>这一页没有写进族谱</h1>
      <p className="not-found-page__desc">
        页面可能已经移动，或者从未被记录。回到家族首页，继续沿着世系寻找。
      </p>
      <div className="not-found-page__actions">
        <Button theme="solid" type="primary" icon={<IconHome />} onClick={() => navigate('/')}>
          回到家族首页
        </Button>
        <Button theme="light" icon={<IconArrowLeft />} onClick={() => navigate(-1)}>
          返回上一页
        </Button>
      </div>
      <span className="not-found-page__folio">FAMILY ARCHIVE · 404</span>
    </div>
  );
}
