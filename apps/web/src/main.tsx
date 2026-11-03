import ReactDOM from 'react-dom/client';
import { Provider } from 'react-redux';
import { BrowserRouter } from 'react-router-dom';
import '@fontsource/noto-serif-sc/600.css';
import '@fontsource/noto-serif-sc/700.css';
import '@douyinfe/semi-ui/lib/es/_base/base.css';
import '@xyflow/react/dist/style.css';
import '@/styles/index.scss';
import App from './App';
import { store } from '@/store';

// Semi Design 的部分组件仍依赖 findDOMNode；StrictMode 会放大兼容警告。
// 生产构建不受影响，这里去掉 StrictMode 以保持控制台干净。
ReactDOM.createRoot(document.getElementById('root')!).render(
  <Provider store={store}>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </Provider>,
);
