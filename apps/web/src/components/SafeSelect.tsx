import type { ComponentType, CSSProperties, ReactNode } from 'react';
import { Select } from '@douyinfe/semi-ui';

/**
 * Semi 2.104 的 Select 泛型在 TS 5.8 下会对动态 optionList 触发
 * “Type instantiation is excessively deep”。这里保留运行时的 Semi Select，
 * 仅把对外 props 收敛成组件实际使用的稳定子集，避免页面被迫写 any。
 */
export interface SafeSelectOption {
  label: ReactNode;
  value: string | number;
  disabled?: boolean;
}

export interface SafeSelectProps {
  className?: string;
  style?: CSSProperties;
  placeholder?: string;
  value?: string | number | Array<string | number> | undefined;
  onChange?: (value: string | number | Array<string | number>) => void;
  onClear?: () => void;
  optionList?: SafeSelectOption[];
  showClear?: boolean;
  filter?: boolean;
  multiple?: boolean;
  maxTagCount?: number;
  disabled?: boolean;
  size?: 'small' | 'default' | 'large';
  'aria-label'?: string;
}

export const SafeSelect = Select as unknown as ComponentType<SafeSelectProps>;
