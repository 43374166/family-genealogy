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

export interface ApiPhotoPerson {
  personId: string;
  fullName: string;
}

export interface ApiPhoto {
  id: string;
  personId?: string;
  personName: string;
  uploadedByUserId: string;
  uploadedByName: string;
  caption: string;
  contentPath: string;
  createdAt?: string;
  takenAt?: string;
  persons: ApiPhotoPerson[];
}

export interface ApiPhotoPage {
  items: ApiPhoto[];
}

export interface ApiStory {
  id: string;
  authorUserId: string;
  authorName: string;
  personId?: string;
  personName: string;
  title: string;
  body: string;
  createdAt?: string;
  updatedAt?: string;
  photos: ApiPhoto[];
}

export interface ApiStoryPage {
  items: ApiStory[];
}

export interface ApiNotification {
  id: number;
  kind: string;
  title: string;
  body: string;
  targetType: string;
  targetId: string;
  isRead: boolean;
  createdAt?: string;
}

export interface ApiNotificationPage {
  items: ApiNotification[];
  unreadCount: number;
}

export interface ApiEditRequest {
  id: string;
  requesterName: string;
  targetPersonId?: string;
  targetName: string;
  requestType: string;
  summary: string;
  status: string;
  reviewNote?: string;
  submittedAt?: string;
  reviewedAt?: string;
}

export interface ApiEditRequestPage {
  items: ApiEditRequest[];
}

export interface ApiBindingRequest {
  id: string;
  requesterName: string;
  personId: string;
  personName: string;
  status: string;
  reviewNote?: string;
  reviewerName?: string;
  submittedAt?: string;
  reviewedAt?: string;
}

export interface ApiBindingRequestPage {
  items: ApiBindingRequest[];
}

export interface ApiMergePerson {
  id: string;
  fullName: string;
  generationNo: number;
  generationName: string;
  gender: string;
  lifeStatus: string;
  branchName: string;
  birthYear?: number;
}

export interface ApiMergeStory {
  id: string;
  title: string;
  personName: string;
  photoCount: number;
  createdAt?: string;
}

export interface ApiMergePhoto {
  id: string;
  caption: string;
  personNames: string[];
  createdAt?: string;
}

export interface ApiFamilyMergeRequest {
  id: string;
  sourceFamilyId: string;
  sourceFamilyName: string;
  targetFamilyId: string;
  targetFamilyName: string;
  requesterUserId: string;
  requesterName: string;
  status: string;
  reviewNote?: string;
  personCount: number;
  storyCount: number;
  photoCount: number;
  createdAt?: string;
  reviewedAt?: string;
  targetBranchId?: string;
  startGeneration?: number;
  attachParentId?: string;
  selectedPersonIds?: string[];
  selectedStoryIds?: string[];
  selectedPhotoIds?: string[];
}

export interface ApiFamilyMergeRequestPage {
  items: ApiFamilyMergeRequest[];
}

export interface ApiFamilyMergeDetail {
  request: ApiFamilyMergeRequest;
  persons: ApiMergePerson[];
  stories: ApiMergeStory[];
  photos: ApiMergePhoto[];
  branches: ApiBranch[];
  minGeneration: number;
  maxGeneration: number;
}

export interface ApiFamilyMergeResult {
  request: ApiFamilyMergeRequest;
  importedPersons: number;
  importedStories: number;
  importedPhotos: number;
  sourceArchived: boolean;
}

export interface ApiImportPackage {
  code: string;
  sourceFamilyName: string;
  rootName: string;
  personCount: number;
  relationshipCount: number;
  expiresAt?: string;
}

export interface ApiImportPersonPreview {
  fullName: string;
  generationNo: number;
  relation: string;
}

export interface ApiImportPreview {
  code: string;
  sourceFamilyName: string;
  rootName: string;
  personCount: number;
  relationshipCount: number;
  expiresAt?: string;
  persons: ApiImportPersonPreview[];
}

export interface ApiImportResult {
  sourceFamilyName: string;
  personCount: number;
  rootName: string;
  rootGeneration: number;
}

export interface ApiFamilyListPage {
  items: ApiFamilyEntry[];
}

export interface ApiJoinResult {
  user: ApiUser;
  membership: ApiMembership;
  family: ApiFamily;
  families: ApiFamilyEntry[];
  archivedFamilies?: ApiFamily[];
  mergeRequests?: ApiFamilyMergeRequest[];
}

export interface ApiFamilyAccount {
  userId: string;
  loginName: string;
  displayName: string;
  role: string;
  personName: string;
}

export interface ApiFamilyAccountPage {
  items: ApiFamilyAccount[];
}

export interface ApiInvite {
  id: string;
  code: string;
  role: string;
  branchName: string;
  maxUses: number;
  usedCount: number;
  expiresAt?: string;
  status: string;
}

export interface ApiInvitePage {
  items: ApiInvite[];
}

export interface ApiRegistration {
  user: ApiUser;
  family: ApiFamily;
}
