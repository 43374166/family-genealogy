import { useEffect, useState } from 'react';
import { Button, Input, SideSheet, TextArea, Toast } from '@douyinfe/semi-ui';
import type { Person, PersonEditChanges } from '@/types/api';
import { contentApi } from '@/api/content';
import { toErrorMessage } from '@/utils/error';
import './PersonFormDrawer.scss';

interface RequestForm {
  birthPlace: string;
  residence: string;
  occupation: string;
  education: string;
  biography: string;
}

const FIELD_LABELS: Record<keyof RequestForm, string> = {
  birthPlace: '籍贯',
  residence: '现居地',
  occupation: '职业',
  education: '教育',
  biography: '生平简介',
};

export function ProfileRequestDrawer({
  visible,
  person,
  onClose,
  onSubmitted,
}: {
  visible: boolean;
  person: Person;
  onClose: () => void;
  onSubmitted: () => void;
}) {
  const [form, setForm] = useState<RequestForm>({
    birthPlace: person.birthPlace ?? '',
    residence: person.residence ?? '',
    occupation: person.occupation ?? '',
    education: person.education ?? '',
    biography: person.biography ?? '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;
    setForm({
      birthPlace: person.birthPlace ?? '',
      residence: person.residence ?? '',
      occupation: person.occupation ?? '',
      education: person.education ?? '',
      biography: person.biography ?? '',
    });
    setError(null);
  }, [person, visible]);

  const update = (key: keyof RequestForm, value: string) => {
    setForm((current) => ({ ...current, [key]: value }));
    setError(null);
  };

  const handleSubmit = async () => {
    const changes: PersonEditChanges = {};
    const original: RequestForm = {
      birthPlace: person.birthPlace ?? '',
      residence: person.residence ?? '',
      occupation: person.occupation ?? '',
      education: person.education ?? '',
      biography: person.biography ?? '',
    };

    (Object.keys(form) as (keyof RequestForm)[]).forEach((key) => {
      if (form[key].trim() !== original[key].trim()) {
        changes[key] = form[key].trim();
      }
    });

    if (!Object.keys(changes).length) {
      setError('请至少修改一个字段后再提交');
      return;
    }

    setSaving(true);
    try {
      await contentApi.createEditRequest({
        targetPersonId: person.id,
        baseVersion: person.version,
        changes,
      });
      Toast.success({ content: '资料申请已提交，等待族长或管理员审核', duration: 3 });
      onSubmitted();
      onClose();
    } catch (submitError) {
      setError(toErrorMessage(submitError, '提交失败，请稍后重试'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <SideSheet
      visible={visible}
      placement="right"
      width={540}
      title="申请修改人物资料"
      onCancel={onClose}
      closeOnEsc
      maskClosable={false}
      className="person-form-sheet"
      footer={
        <div className="person-form__footer">
          <Button theme="borderless" onClick={onClose} disabled={saving}>
            取消
          </Button>
          <Button theme="solid" type="primary" loading={saving} onClick={handleSubmit}>
            提交审核
          </Button>
        </div>
      }
    >
      <div className="person-form">
        <p className="person-form__intro">
          普通成员不直接修改正式档案。提交后由族长或管理员审核，通过后才会写入族谱。
          本次修改目标：<strong>{person.fullName}</strong>。
        </p>

        <section className="person-form__section">
          <h4>可申请修改的字段</h4>
          <div className="person-form__row">
            <label className="person-form__field">
              <span>{FIELD_LABELS.birthPlace}</span>
              <Input
                value={form.birthPlace}
                onChange={(value) => update('birthPlace', value)}
                maxLength={160}
                placeholder="例如：江南 · 青溪"
              />
            </label>
            <label className="person-form__field">
              <span>{FIELD_LABELS.residence}</span>
              <Input
                value={form.residence}
                onChange={(value) => update('residence', value)}
                maxLength={160}
                placeholder="现居住地"
              />
            </label>
          </div>
          <div className="person-form__row">
            <label className="person-form__field">
              <span>{FIELD_LABELS.occupation}</span>
              <Input
                value={form.occupation}
                onChange={(value) => update('occupation', value)}
                maxLength={160}
                placeholder="职业"
              />
            </label>
            <label className="person-form__field">
              <span>{FIELD_LABELS.education}</span>
              <Input
                value={form.education}
                onChange={(value) => update('education', value)}
                maxLength={160}
                placeholder="教育经历"
              />
            </label>
          </div>
          <label className="person-form__field">
            <span>{FIELD_LABELS.biography}</span>
            <TextArea
              value={form.biography}
              onChange={(value) => update('biography', value)}
              maxLength={2000}
              autosize={{ minRows: 5, maxRows: 10 }}
              placeholder="补充这个人的生平、性格与家族记忆…"
            />
          </label>
        </section>

        {error ? <div className="person-form__error">{error}</div> : null}
      </div>
    </SideSheet>
  );
}
