/** 与 packages/api-contracts 及 Go 服务端保持一致的领域类型。 */

export type Role = 'owner' | 'admin' | 'member';
export type Gender = 'male' | 'female' | 'other' | 'unknown';
export type LifeStatus = 'living' | 'deceased' | 'unknown';
export type EditRequestStatus = 'pending' | 'approved' | 'rejected' | 'cancelled';
export type EditRequestType =
  | 'update_person'
  | 'update_person_profile'
  | 'create_person'
  | 'add_parent_child'
  | 'add_spouse'
  | 'end_parent_child'
  | 'end_spouse';

export interface User {
  id: string;
  displayName: string;
  loginName: string;
  phone?: string;
  status: string;
  termsAccepted: boolean;
}

export interface Family {
  id: string;
  name: string;
  surname: string;
  motto: string;
  region: string;
  description: string;
  status: 'active' | 'archived';
  memberCount: number;
  branchCount: number;
  version: number;
}

export interface Membership {
  id: string;
  role: Role;
  status: string;
  personId?: string;
  joinedAt: string;
}

export interface FamilyMembership {
  family: Family;
  membership: Membership;
}

export interface Me {
  user: User;
  membership: Membership;
  family: Family;
  families: FamilyMembership[];
}

export interface Session {
  token: string;
  expiresAt: string;
  user: User;
  family: Family;
}

export type QrLoginState =
  | 'pending'
  | 'scanned'
  | 'confirmed'
  | 'consumed'
  | 'expired'
  | 'cancelled';

export interface QrLoginCreate {
  id: string;
  secret: string;
  payload: string;
  status: QrLoginState;
  expiresAt: string;
  pollIntervalMs: number;
  requestIp?: string;
  requestCity?: string;
  requestRegion?: string;
  requestDevice?: string;
}

export interface QrLoginStatus {
  id: string;
  status: QrLoginState;
  expiresAt: string;
  scannedAt?: string;
  confirmedAt?: string;
  requestIp?: string;
  requestCity?: string;
  requestRegion?: string;
  requestDevice?: string;
  session?: Session;
}

export interface Branch {
  id: string;
  parentId?: string;
  name: string;
  sortOrder: number;
}

export interface PartialDate {
  year?: number;
  month?: number;
  day?: number;
  calendar?: 'gregorian' | 'lunar' | 'unknown';
  isLeapMonth?: boolean;
  text?: string;
}

export interface PersonSummary {
  id: string;
  fullName: string;
  surname: string;
  givenName: string;
  courtesyName?: string;
  alias?: string;
  gender: Gender;
  generationNo: number;
  generationName?: string;
  generationLabel: string;
  birthOrder?: number;
  branchId?: string;
  birth?: PartialDate;
  death?: PartialDate;
  lifeStatus: LifeStatus;
  status: string;
  version: number;
  hasAvatar: boolean;
}

export interface Relative {
  edgeId: string;
  personId: string;
  fullName: string;
  relation: string;
}

export interface Person extends PersonSummary {
  birthPlace?: string;
  residence?: string;
  occupation?: string;
  education?: string;
  biography?: string;
  parents?: Relative[];
  siblings?: Relative[];
  children?: Relative[];
  spouses?: Relative[];
  createdAt: string;
  updatedAt: string;
}

export interface ParentChildEdge {
  id: string;
  parentId: string;
  childId: string;
  parentRole: 'father' | 'mother' | 'parent' | 'adoptive' | 'step' | 'guardian';
  status: string;
}

export interface SpouseEdge {
  id: string;
  personAId: string;
  personBId: string;
  status: 'married' | 'divorced' | 'widowed' | 'unknown';
  startYear?: number;
  endYear?: number;
}

export interface FamilyTree {
  familyId: string;
  version: number;
  persons: PersonSummary[];
  parentChild: ParentChildEdge[];
  spouses: SpouseEdge[];
}

export interface PersonPage {
  items: PersonSummary[];
  nextCursor: string | null;
}

export interface Activity {
  id: number;
  action: string;
  actorName: string;
  summary: string;
  detail: string;
  kind: 'person' | 'family' | 'member' | 'request' | 'system' | string;
  needsReview: boolean;
  createdAt: string;
}

export interface ActivityPage {
  items: Activity[];
}

export interface Anniversary {
  personId: string;
  fullName: string;
  kind: 'birthday' | 'memorial' | string;
  date: string;
  daysUntil: number;
  solarText: string;
  lunarText: string;
  age?: number;
  isLunar: boolean;
}

export interface NotificationItem {
  id: number;
  kind: string;
  title: string;
  body: string;
  targetType: string;
  targetId?: string;
  isRead: boolean;
  createdAt: string;
}

export interface NotificationPage {
  items: NotificationItem[];
  unreadCount: number;
}

export interface PhotoPerson {
  personId: string;
  fullName: string;
}

export interface Photo {
  id: string;
  familyId: string;
  personId?: string;
  personName?: string;
  persons?: PhotoPerson[];
  uploadedByUserId: string;
  uploadedByName: string;
  contentType: string;
  sizeBytes: number;
  caption: string;
  takenAt?: string;
  createdAt: string;
  contentPath?: string;
}

export interface PhotoPage {
  items: Photo[];
}

export interface Story {
  id: string;
  familyId: string;
  authorUserId: string;
  authorName: string;
  personId?: string;
  personName?: string;
  title: string;
  body: string;
  photos?: Photo[];
  createdAt: string;
  updatedAt: string;
}

export interface StoryPage {
  items: Story[];
}

export interface PersonEditChanges {
  birthPlace?: string;
  residence?: string;
  occupation?: string;
  education?: string;
  biography?: string;
}

export interface EditRequest {
  id: string;
  familyId: string;
  requesterUserId: string;
  requesterName: string;
  requestType: EditRequestType | string;
  targetPersonId?: string;
  targetName: string;
  baseVersion?: number;
  changes: PersonEditChanges;
  changedFields: string[] | null;
  payload?: Record<string, unknown>;
  summary?: string;
  status: EditRequestStatus;
  reviewerUserId?: string;
  reviewerName?: string;
  reviewNote?: string;
  submittedAt: string;
  reviewedAt?: string;
}

export interface EditRequestPage {
  items: EditRequest[];
}

export interface Invite {
  id: string;
  code: string;
  role: Role;
  branchId?: string;
  branchName?: string;
  maxUses: number;
  usedCount: number;
  expiresAt: string;
  status: string;
}

export interface InvitePage {
  items: Invite[];
}

export interface FamilyAccount {
  userId: string;
  loginName: string;
  displayName: string;
  role: Role;
  personName?: string;
}

export interface FamilyAccountPage {
  items: FamilyAccount[];
}

export interface GenerationName {
  generationNo: number;
  name: string;
}

export interface GenerationNameSet {
  items: GenerationName[];
  poem: string;
}

export interface Problem {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  code: string;
  requestId?: string;
  errors?: { field: string; message: string }[];
}

/** 写接口通用的日期字段（服务端是扁平字段，不是 PartialDate 对象）。 */
export interface PartialDateFields {
  birthYear?: number | null;
  birthMonth?: number | null;
  birthDay?: number | null;
  birthCalendar?: string;
  birthIsLeapMonth?: boolean;
  deathYear?: number | null;
  deathMonth?: number | null;
  deathDay?: number | null;
  deathCalendar?: string;
  deathIsLeapMonth?: boolean;
}

export interface CreatePersonInput extends PartialDateFields {
  surname: string;
  givenName: string;
  courtesyName?: string;
  alias?: string;
  gender: Gender;
  generationNo: number;
  generationName?: string;
  branchId: string;
  birthOrder?: number | null;
  lifeStatus: LifeStatus;
  biography?: string;
}

export interface UpdatePersonInput extends CreatePersonInput {
  birthPlace: string;
  residence: string;
  occupation: string;
  education: string;
  version: number;
}
