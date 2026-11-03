import type { ReactNode } from 'react';
import { IconArrowRight, IconBookOpenStroked, IconBranch, IconGallery } from '@douyinfe/semi-icons';
import { BrandMark } from '@/components/BrandMark';
import heroInk from '@/assets/hero-ink.jpg';
import './Auth.scss';

const features = [
  {
    icon: <IconBranch />,
    title: '世系清晰',
    description: '以族谱树串起每一代人的来处与延续。',
  },
  {
    icon: <IconGallery />,
    title: '影像长存',
    description: '把老照片、旧故事安放在家族共同的空间。',
  },
  {
    icon: <IconBookOpenStroked />,
    title: '家风可传',
    description: '一段文字、一张照片，都是留给后人的线索。',
  },
];

export function AuthLayout({
  children,
  eyebrow,
  title,
  description,
}: {
  children: ReactNode;
  eyebrow: string;
  title: string;
  description: string;
}) {
  return (
    <div className="auth-page">
      <section className="auth-showcase" aria-label="家族族谱介绍">
        <div className="auth-showcase__bg" style={{ backgroundImage: `url(${heroInk})` }} />
        <div className="auth-showcase__wash" />
        <header className="auth-showcase__brand">
          <BrandMark size="md" />
          <div>
            <strong>家族族谱</strong>
            <span>FAMILY GENEALOGY</span>
          </div>
        </header>

        <div className="auth-showcase__body">
          <p className="auth-showcase__eyebrow">WELCOME BACK TO YOUR ROOTS</p>
          <h1>
            一纸家谱
            <br />
            千年血脉
          </h1>
          <div className="auth-showcase__poem">
            <span />
            <p>
              参天之木，必有其根
              <br />
              怀山之水，必有其源
            </p>
          </div>
        </div>

        <div className="auth-showcase__features">
          {features.map((feature) => (
            <article key={feature.title}>
              <span className="auth-showcase__feature-icon">{feature.icon}</span>
              <div>
                <strong>{feature.title}</strong>
                <p>{feature.description}</p>
              </div>
            </article>
          ))}
        </div>

        <footer className="auth-showcase__footer">
          <span>族谱 · 相册 · 故事 · 传承</span>
          <span>© {new Date().getFullYear()} Family Tree</span>
        </footer>
      </section>

      <section className="auth-panel">
        <div className="auth-panel__mobile-brand">
          <BrandMark size="sm" />
          <span>家族族谱</span>
        </div>
        <div className="auth-card">
          <div className="auth-card__heading">
            <p className="eyebrow">{eyebrow}</p>
            <h2>{title}</h2>
            <p>{description}</p>
          </div>
          {children}
        </div>
        <p className="auth-panel__notice">
          <span className="auth-panel__notice-dot" />
          家族资料仅对已加入的成员可见
          <IconArrowRight size="small" />
        </p>
      </section>
    </div>
  );
}
