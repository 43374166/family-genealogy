import { useEffect, useState } from 'react';
import { Button, Input, InputNumber, SideSheet, TextArea, Toast } from '@douyinfe/semi-ui';
import { SafeSelect as Select } from '@/components/SafeSelect';
import type { Branch, CreatePersonInput, Person, UpdatePersonInput } from '@/types/api';
import { personsApi } from '@/api/persons';
import { useAppSelector } from '@/store/hooks';
import { toErrorMessage } from '@/utils/error';
import { cn } from '@/utils/cn';
import './PersonFormDrawer.scss';

type FormMode = 'create' | 'edit';

interface PersonFormState {
  surname: string;
  givenName: string;
  courtesyName: string;
  alias: string;
  gender: string;
  generationNo: string;
  generationName: string;
  branchId: string;
  birthOrder: string;
  birthYear: string;
  birthMonth: string;
  birthDay: string;
  deathYear: string;
  deathMonth: string;
  deathDay: string;
  lifeStatus: string;
  birthPlace: string;
  residence: string;
  occupation: string;
  education: string;
  biography: string;
}

function initialForm(
  person: Person | null,
  defaultSurname: string,
  defaultGeneration: number,
  defaultBranchId: string,
): PersonFormState {
  return {
    surname: person?.surname ?? defaultSurname,
    givenName: person?.givenName ?? '',
    courtesyName: person?.courtesyName ?? '',
    alias: person?.alias ?? '',
    gender: person?.gender ?? 'male',
    generationNo: String(person?.generationNo ?? defaultGeneration),
    generationName: person?.generationName ?? '',
    branchId: person?.branchId ?? defaultBranchId,
    birthOrder: person?.birthOrder ? String(person.birthOrder) : '',
    birthYear: person?.birth ? String(person.birth.year ?? '') : '',
    birthMonth: person?.birth?.month ? String(person.birth.month) : '',
    birthDay: person?.birth?.day ? String(person.birth.day) : '',
    deathYear: person?.death ? String(person.death.year ?? '') : '',
    deathMonth: person?.death?.month ? String(person.death.month) : '',
    deathDay: person?.death?.day ? String(person.death.day) : '',
    lifeStatus: person?.lifeStatus ?? 'living',
    birthPlace: person?.birthPlace ?? '',
    residence: person?.residence ?? '',
    occupation: person?.occupation ?? '',
    education: person?.education ?? '',
    biography: person?.biography ?? '',
  };
}

function toNumber(value: string): number | undefined {
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export function PersonFormDrawer({
  visible,
  mode,
  person,
  branches,
  onClose,
  onSaved,
}: {
  visible: boolean;
  mode: FormMode;
  person?: Person | null;
  branches: Branch[];
  onClose: () => void;
  onSaved: (person: Person) => void;
}) {
  const auth = useAppSelector((state) => state.auth);
  const [form, setForm] = useState<PersonFormState>(() =>
    initialForm(
      person ?? null,
      auth.family?.surname ?? '',
      1,
      branches[0]?.id ?? '',
    ),
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;
    setForm(
      initialForm(
        person ?? null,
        auth.family?.surname ?? '',
        1,
        branches[0]?.id ?? '',
      ),
    );
    setError(null);
  }, [auth.family?.surname, branches, person, visible]);

  const update = <K extends keyof PersonFormState>(key: K, value: PersonFormState[K]) => {
    setForm((current) => ({ ...current, [key]: value }));
    setError(null);
  };

  const validate = (): string | null => {
    if (!form.surname.trim()) return '请填写姓氏';
    if (!form.givenName.trim()) return '请填写名字';
    if (!form.branchId) return '请选择所属家支';
    const generation = toNumber(form.generationNo);
    if (!generation || generation < 1 || generation > 99) return '世代需在 1–99 之间';
    if (!form.birthYear && (form.birthMonth || form.birthDay)) return '填写出生月份或日期前，请先填写出生年份';
    if (!form.birthMonth && form.birthDay) return '填写出生日期前，请先填写出生月份';
    if (!form.deathYear && (form.deathMonth || form.deathDay)) return '填写逝世月份或日期前，请先填写逝世年份';
    if (!form.deathMonth && form.deathDay) return '填写逝世日期前，请先填写逝世月份';
    return null;
  };

  const handleSubmit = async () => {
    const message = validate();
    if (message) {
      setError(message);
      return;
    }

    const generationNo = toNumber(form.generationNo) ?? 1;
    const birthYear = toNumber(form.birthYear);
    const birthMonth = toNumber(form.birthMonth);
    const birthDay = toNumber(form.birthDay);
    const deathYear = toNumber(form.deathYear);
    const deathMonth = toNumber(form.deathMonth);
    const deathDay = toNumber(form.deathDay);

    const common: CreatePersonInput = {
      surname: form.surname.trim(),
      givenName: form.givenName.trim(),
      courtesyName: form.courtesyName.trim(),
      alias: form.alias.trim(),
      gender: form.gender as CreatePersonInput['gender'],
      generationNo,
      generationName: form.generationName.trim(),
      branchId: form.branchId,
      birthOrder: toNumber(form.birthOrder),
      lifeStatus: form.lifeStatus as CreatePersonInput['lifeStatus'],
      biography: form.biography.trim(),
      ...(birthYear !== undefined
        ? {
            birthYear,
            birthMonth,
            birthDay,
            birthCalendar: 'gregorian',
            birthIsLeapMonth: false,
          }
        : {}),
      ...(deathYear !== undefined
        ? {
            deathYear,
            deathMonth,
            deathDay,
            deathCalendar: 'gregorian',
            deathIsLeapMonth: false,
          }
        : {}),
    };

    setSaving(true);
    try {
      let saved: Person;
      if (mode === 'edit' && person) {
        const payload: UpdatePersonInput = {
          ...common,
          birthPlace: form.birthPlace.trim(),
          residence: form.residence.trim(),
          occupation: form.occupation.trim(),
          education: form.education.trim(),
          biography: form.biography.trim(),
          version: person.version,
        };
        saved = await personsApi.updatePerson(person.id, payload);
        Toast.success({ content: '人物资料已更新', duration: 2.2 });
      } else {
        saved = await personsApi.createPerson(common);
        Toast.success({ content: `${saved.fullName} 已加入族谱`, duration: 2.4 });
      }
      onSaved(saved);
      onClose();
    } catch (submitError) {
      setError(toErrorMessage(submitError, '保存失败，请稍后重试'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <SideSheet
      visible={visible}
      placement="right"
      width={560}
      title={mode === 'edit' ? '编辑人物资料' : '新增家族成员'}
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
            {mode === 'edit' ? '保存修改' : '加入族谱'}
          </Button>
        </div>
      }
    >
      <div className="person-form">
        <p className="person-form__intro">
          只填写已知信息即可。族谱支持“生卒未详”，不需要为了完整而编造日期。
        </p>

        <section className="person-form__section">
          <h4>基本信息</h4>
          <div className="person-form__row">
            <label className="person-form__field">
              <span>姓氏 <em>*</em></span>
              <Input value={form.surname} onChange={(value) => update('surname', value)} placeholder="例如：张" maxLength={20} />
            </label>
            <label className="person-form__field">
              <span>名字 <em>*</em></span>
              <Input value={form.givenName} onChange={(value) => update('givenName', value)} placeholder="例如：明远" maxLength={60} />
            </label>
          </div>
          <div className="person-form__row">
            <label className="person-form__field">
              <span>字号</span>
              <Input value={form.courtesyName} onChange={(value) => update('courtesyName', value)} placeholder="字 / 号" maxLength={80} />
            </label>
            <label className="person-form__field">
              <span>别名</span>
              <Input value={form.alias} onChange={(value) => update('alias', value)} placeholder="俗称、小名等" maxLength={80} />
            </label>
          </div>
          <div className="person-form__row person-form__row--three">
            <label className="person-form__field">
              <span>性别</span>
              <Select
                value={form.gender}
                onChange={(value) => update('gender', String(value))}
                optionList={[
                  { value: 'male', label: '男' },
                  { value: 'female', label: '女' },
                  { value: 'other', label: '其他' },
                  { value: 'unknown', label: '未详' },
                ]}
              />
            </label>
            <label className="person-form__field">
              <span>世代 <em>*</em></span>
              <InputNumber
                value={form.generationNo ? Number(form.generationNo) : undefined}
                min={1}
                max={99}
                onChange={(value) => update('generationNo', value === undefined ? '' : String(value))}
                placeholder="如 8"
                style={{ width: '100%' }}
              />
            </label>
            <label className="person-form__field">
              <span>排行</span>
              <InputNumber
                value={form.birthOrder ? Number(form.birthOrder) : undefined}
                min={1}
                max={99}
                onChange={(value) => update('birthOrder', value === undefined ? '' : String(value))}
                placeholder="如 1"
                style={{ width: '100%' }}
              />
            </label>
          </div>
          <div className="person-form__row">
            <label className="person-form__field">
              <span>所属家支 <em>*</em></span>
              <Select
                value={form.branchId || undefined}
                placeholder="请选择家支"
                optionList={branches.map((branch) => ({ value: branch.id, label: branch.name }))}
                onChange={(value) => update('branchId', String(value))}
                showClear={false}
              />
            </label>
            <label className="person-form__field">
              <span>字辈</span>
              <Input value={form.generationName} onChange={(value) => update('generationName', value)} placeholder="如：德" maxLength={20} />
            </label>
          </div>
          <div className="person-form__row">
            <label className="person-form__field">
              <span>在世状态</span>
              <Select
                value={form.lifeStatus}
                onChange={(value) => update('lifeStatus', String(value))}
                optionList={[
                  { value: 'living', label: '在世' },
                  { value: 'deceased', label: '已故' },
                  { value: 'unknown', label: '未详' },
                ]}
              />
            </label>
            <span className="person-form__field person-form__hint-field">
              <span>提示</span>
              <em>修改世代会同步影响族谱树中的位置。</em>
            </span>
          </div>
        </section>

        <section className="person-form__section">
          <h4>出生与逝世</h4>
          <p className="person-form__section-note">只填年份也可以，月份和日期请从左到右填写。</p>
          <div className="person-form__date-row">
            <span className="person-form__date-label">出生</span>
            <Input value={form.birthYear} onChange={(value) => update('birthYear', value)} placeholder="年" />
            <Input value={form.birthMonth} onChange={(value) => update('birthMonth', value)} placeholder="月" />
            <Input value={form.birthDay} onChange={(value) => update('birthDay', value)} placeholder="日" />
          </div>
          <div className="person-form__date-row">
            <span className="person-form__date-label">逝世</span>
            <Input value={form.deathYear} onChange={(value) => update('deathYear', value)} placeholder="年" />
            <Input value={form.deathMonth} onChange={(value) => update('deathMonth', value)} placeholder="月" />
            <Input value={form.deathDay} onChange={(value) => update('deathDay', value)} placeholder="日" />
          </div>
        </section>

        {mode === 'edit' ? (
          <section className="person-form__section">
            <h4>生平信息</h4>
            <div className="person-form__row">
              <label className="person-form__field">
                <span>籍贯</span>
                <Input value={form.birthPlace} onChange={(value) => update('birthPlace', value)} maxLength={160} />
              </label>
              <label className="person-form__field">
                <span>现居地</span>
                <Input value={form.residence} onChange={(value) => update('residence', value)} maxLength={160} />
              </label>
            </div>
            <div className="person-form__row">
              <label className="person-form__field">
                <span>职业</span>
                <Input value={form.occupation} onChange={(value) => update('occupation', value)} maxLength={160} />
              </label>
              <label className="person-form__field">
                <span>教育</span>
                <Input value={form.education} onChange={(value) => update('education', value)} maxLength={160} />
              </label>
            </div>
            <label className="person-form__field">
              <span>生平简介</span>
              <TextArea
                value={form.biography}
                onChange={(value) => update('biography', value)}
                placeholder="记录这个人的性格、经历与家族记忆…"
                maxLength={2000}
                autosize={{ minRows: 3, maxRows: 7 }}
              />
            </label>
          </section>
        ) : (
          <section className="person-form__section">
            <h4>生平简介</h4>
            <label className="person-form__field">
              <span>简介</span>
              <TextArea
                value={form.biography}
                onChange={(value) => update('biography', value)}
                placeholder="可稍后在人物档案中补充"
                maxLength={2000}
                autosize={{ minRows: 3, maxRows: 7 }}
              />
            </label>
          </section>
        )}

        {error ? <div className="person-form__error">{error}</div> : null}
        {!branches.length ? (
          <div className={cn('person-form__error', 'person-form__error--info')}>
            当前家族还没有家支，请先在「家族管理」中创建家支。
          </div>
        ) : null}
      </div>
    </SideSheet>
  );
}
