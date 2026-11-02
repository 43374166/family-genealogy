export interface ApiFamily {
  id: string;
  name: string;
  surname: string;
  motto: string;
  region: string;
  description: string;
  status: string;
  memberCount: number;
  branchCount: number;
  version: number;
}

export interface ApiUser {
  id: string;
  displayName: string;
  loginName: string;
  status: string;
  termsAccepted: boolean;
}

export interface ApiMembership {
  id: string;
  role: string;
  status: string;
  personId?: string;
  joinedAt?: string;
}

export interface ApiFamilyEntry {
  family: ApiFamily;
  membership: ApiMembership;
}

export interface ApiLoginResult {
  token: string;
  expiresAt?: string;
  user: ApiUser;
  family: ApiFamily;
}

export interface ApiMeResult {
  user: ApiUser;
  membership: ApiMembership;
  family: ApiFamily;
  families: ApiFamilyEntry[];
}

export interface ApiPartialDate {
  year?: number;
  month?: number;
  day?: number;
  calendar?: string;
  isLeapMonth?: boolean;
  text?: string;
}

export interface ApiRelative {
  personId: string;
  fullName: string;
  relation: string;
  edgeId: string;
}

export interface ApiPerson {
  id: string;
  fullName: string;
  surname: string;
  givenName: string;
  courtesyName?: string;
  alias?: string;
  gender: string;
  generationNo: number;
  generationName?: string;
  generationLabel: string;
  birthOrder?: number;
  branchId?: string;
  birth?: ApiPartialDate;
  death?: ApiPartialDate;
  lifeStatus: string;
  status: string;
  version: number;
  hasAvatar?: boolean;
  birthPlace?: string;
  residence?: string;
  occupation?: string;
  education?: string;
  biography?: string;
  parents?: ApiRelative[];
  siblings?: ApiRelative[];
  children?: ApiRelative[];
  spouses?: ApiRelative[];
}

export interface ApiParentChildEdge {
  id: string;
  parentId: string;
  childId: string;
  parentRole: string;
  status: string;
}

export interface ApiSpouseEdge {
  id: string;
  personAId: string;
  personBId: string;
  status: string;
  startYear?: number;
  endYear?: number;
}

export interface ApiTree {
  familyId: string;
  version: number;
  persons: ApiPerson[];
  parentChild: ApiParentChildEdge[];
  spouses: ApiSpouseEdge[];
}

export interface ApiActivity {
  id: number;
  action: string;
  actorName: string;
  summary: string;
  detail: string;
  kind: string;
  needsReview?: boolean;
  createdAt: string;
}

export interface ApiActivityPage {
  items: ApiActivity[];
}

export interface ApiAnniversary {
  personId: string;
  fullName: string;
  kind: string;
  date: string;
  daysUntil: number;
  solarText: string;
  lunarText: string;
  age?: number;
  isLunar: boolean;
}

export interface ApiAnniversaryPage {
  items: ApiAnniversary[];
}

export interface ApiPersonPage {
  items: ApiPerson[];
  nextCursor?: string;
}

export interface ApiBranch {
  id: string;
  name: string;
  parentId?: string;
  sortOrder: number;
}

export interface ApiBranchPage {
  items: ApiBranch[];
}

export interface ApiProblem {
  title?: string;
  detail?: string;
  code?: string;
  status?: number;
}
