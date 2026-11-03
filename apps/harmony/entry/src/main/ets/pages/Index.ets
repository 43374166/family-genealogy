import { promptAction } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import pasteboard from '@ohos.pasteboard';
import { AppServices } from '../service/ApiClient';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { AuthImage } from '../components/AuthImage';
import {
  ApiActivity,
  ApiAnniversary,
  ApiBindingRequest,
  ApiBranch,
  ApiEditRequest,
  ApiFamilyAccount,
  ApiFamilyEntry,
  ApiFamilyMergeDetail,
  ApiFamilyMergeRequest,
  ApiImportPackage,
  ApiImportPersonPreview,
  ApiImportPreview,
  ApiImportResult,
  ApiInvite,
  ApiMeResult,
  ApiMergePerson,
  ApiMergePhoto,
  ApiMergeStory,
  ApiNotification,
  ApiPerson,
  ApiPhoto,
  ApiPhotoPerson,
  ApiRelative,
  ApiStory,
  ApiTree,
  UpdatePersonPayload
} from '../model/Types';
import { PersonBox, TreeLayoutBuilder, TreeLayoutResult } from '../model/TreeLayout';

const DEFAULT_SERVER: string = 'https://family.fishdream.xyz:10443';
const LAN_SERVER: string = 'http://192.168.1.36:10080/family-api';

PersistentStorage.persistProp('familytree_token', '');
PersistentStorage.persistProp('familytree_server', DEFAULT_SERVER);

@Entry
@Component
struct Index {
  @StorageLink('familytree_token') private token: string = '';
  @StorageLink('familytree_server') private savedServer: string = DEFAULT_SERVER;

  @State private booting: boolean = true;
  @State private loggedIn: boolean = false;
  @State private page: string = 'tabs';
  @State private tab: number = 0;
  @State private busy: boolean = false;
  @State private error: string = '';

  @State private loginName: string = 'linglei';
  @State private password: string = '';
  @State private serverDraft: string = DEFAULT_SERVER;
  @State private serverMode: number = 0;
  @State private authPage: string = 'login';
  @State private authBusy: boolean = false;
  @State private authError: string = '';

  @State private phoneLoginPhone: string = '';
  @State private phoneLoginCode: string = '';
  @State private phoneCodeSent: boolean = false;

  @State private regLoginName: string = '';
  @State private regDisplayName: string = '';
  @State private regPassword: string = '';
  @State private regConfirm: string = '';
  @State private regInviteCode: string = '';
  @State private regFamilyName: string = '';
  @State private regSurname: string = '';
  @State private regPhone: string = '';
  @State private regAcceptTerms: boolean = false;

  @State private resetLoginName: string = '';
  @State private resetRecoveryCode: string = '';
  @State private resetNewPassword: string = '';

  @State private displayName: string = '';
  @State private currentUserId: string = '';
  @State private role: string = '';
  @State private linkedPersonId: string = '';
  @State private familyName: string = '';
  @State private familySurname: string = '';
  @State private familyMotto: string = '';
  @State private familyId: string = '';
  @State private memberCount: number = 0;
  @State private branchCount: number = 0;
  @State private myGeneration: string = '';

  @State private tree: ApiTree | null = null;
  @State private treeSelectedId: string = '';
  @State private treeGenerationFilter: number = 0;
  @State private treeScale: number = 1;
  @State private treeOffsetX: number = 0;
  @State private treeOffsetY: number = 0;
  @State private treePanBaseX: number = 0;
  @State private treePanBaseY: number = 0;
  @State private treePinchBase: number = 1;
  @State private treeViewportWidth: number = 0;
  @State private treeViewportHeight: number = 0;
  @State private treeFitted: boolean = false;
  @State private layout: TreeLayoutResult | null = null;
  @State private activities: ApiActivity[] = [];
  @State private anniversaries: ApiAnniversary[] = [];
  @State private query: string = '';
  @State private selected: ApiPerson | null = null;
  @State private detailBusy: boolean = false;
  @State private personPhotos: ApiPhoto[] = [];
  @State private relationTypeIndex: number = 0;
  @State private relationPersonIndex: number = 0;
  @State private relationBusy: boolean = false;
  @State private relationError: string = '';
  @State private profileReqBirthPlace: string = '';
  @State private profileReqResidence: string = '';
  @State private profileReqOccupation: string = '';
  @State private profileReqEducation: string = '';
  @State private profileReqBiography: string = '';
  @State private profileReqBusy: boolean = false;
  @State private profileReqError: string = '';
  @State private editSurname: string = '';
  @State private editGivenName: string = '';
  @State private editCourtesyName: string = '';
  @State private editAlias: string = '';
  @State private editGender: string = 'male';
  @State private editGeneration: string = '1';
  @State private editBranchIndex: number = 0;
  @State private editLifeStatus: string = 'living';
  @State private editBirthYear: string = '';
  @State private editBirthPlace: string = '';
  @State private editResidence: string = '';
  @State private editOccupation: string = '';
  @State private editEducation: string = '';
  @State private editBiography: string = '';
  @State private editVersion: number = 1;
  @State private editBusy: boolean = false;
  @State private editError: string = '';

  @State private albumPhotos: ApiPhoto[] = [];
  @State private albumBusy: boolean = false;
  @State private albumError: string = '';
  @State private albumFilterIndex: number = 0;
  @State private viewerPhoto: ApiPhoto | null = null;
  @State private viewerBusy: boolean = false;
  @State private photoFormUris: string[] = [];
  @State private photoFormCaption: string = '';
  @State private photoFormTakenAt: string = '';
  @State private photoFormPersonIds: string[] = [];
  @State private photoFormEditingId: string = '';
  @State private photoFormBusy: boolean = false;
  @State private photoFormError: string = '';

  @State private avatarSource: image.PixelMap | undefined = undefined;
  @State private avatarZoom: number = 1;
  @State private avatarBusy: boolean = false;
  @State private avatarError: string = '';
  @State private avatarRevision: number = 0;

  @State private stories: ApiStory[] = [];
  @State private storiesBusy: boolean = false;
  @State private storiesError: string = '';
  @State private selectedStory: ApiStory | null = null;
  @State private storyDetailBusy: boolean = false;
  @State private storyTitle: string = '';
  @State private storyBody: string = '';
  @State private storyPersonIndex: number = 0;
  @State private storyPhotoUris: string[] = [];
  @State private storySaving: boolean = false;
  @State private storyStatus: string = '';
  @State private storyError: string = '';
  @State private storyEditingId: string = '';
  @State private storyExistingPhotos: ApiPhoto[] = [];
  @State private storyViewerPhoto: ApiPhoto | null = null;

  @State private inboxTab: number = 0;
  @State private notifications: ApiNotification[] = [];
  @State private unreadCount: number = 0;
  @State private inboxBusy: boolean = false;
  @State private inboxError: string = '';
  @State private editReviews: ApiEditRequest[] = [];
  @State private bindingReviews: ApiBindingRequest[] = [];
  @State private myRequests: ApiEditRequest[] = [];
  @State private reviewKind: string = '';
  @State private reviewId: string = '';
  @State private reviewLabel: string = '';
  @State private reviewApprove: boolean = true;
  @State private reviewNote: string = '';
  @State private reviewError: string = '';
  @State private reviewBusy: boolean = false;

  @State private mergeRequests: ApiFamilyMergeRequest[] = [];
  @State private mergesBusy: boolean = false;
  @State private mergesError: string = '';
  @State private mergeDetail: ApiFamilyMergeDetail | null = null;
  @State private mergeDetailBusy: boolean = false;
  @State private mergePersonIds: string[] = [];
  @State private mergeStoryIds: string[] = [];
  @State private mergePhotoIds: string[] = [];
  @State private mergeBranchIndex: number = 0;
  @State private mergeStartGeneration: number = 1;
  @State private mergeAttachIndex: number = 0;
  @State private mergeNote: string = '';
  @State private mergeError: string = '';
  @State private mergeSubmitting: boolean = false;

  @State private dataBranches: ApiBranch[] = [];
  @State private dataBusy: boolean = false;
  @State private dataError: string = '';
  @State private exportBusy: boolean = false;
  @State private exportCode: string = '';
  @State private exportPackage: ApiImportPackage | null = null;
  @State private exportRootIndex: number = 0;
  @State private importCode: string = '';
  @State private importPreview: ApiImportPreview | null = null;
  @State private importPreviewBusy: boolean = false;
  @State private importBusy: boolean = false;
  @State private importBranchIndex: number = 0;
  @State private importGeneration: number = 1;
  @State private importParentIndex: number = 0;
  @State private importParentRole: string = 'father';

  @State private familyCenterBusy: boolean = false;
  @State private familyCenterError: string = '';
  @State private familyEntries: ApiFamilyEntry[] = [];
  @State private familyJoinCode: string = '';
  @State private newFamilyName: string = '';
  @State private newFamilySurname: string = '';
  @State private newFamilyMotto: string = '';
  @State private familyAccounts: ApiFamilyAccount[] = [];
  @State private familyInvites: ApiInvite[] = [];
  @State private accountOldPassword: string = '';
  @State private accountNewPassword: string = '';
  @State private accountDeletePassword: string = '';
  @State private bindPhoneNumber: string = '';
  @State private bindPhoneCode: string = '';
  @State private recoveryCodeDisplay: string = '';
  @State private archiveConfirmName: string = '';
  @State private archivePassword: string = '';

  @State private branches: ApiBranch[] = [];
  @State private addSurname: string = '';
  @State private addGiven: string = '';
  @State private addGender: string = 'male';
  @State private addGeneration: string = '';
  @State private addBranchIndex: number = 0;

  private api = AppServices.api;
  private canvasCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear(): void {
    this.serverDraft = this.savedServer;
    this.serverMode = this.savedServer === LAN_SERVER ? 1 : 0;
    if (this.token.length > 0) {
      this.api.setSession(this.savedServer, this.token);
      this.bootstrap();
    } else {
      this.booting = false;
    }
  }

  private errorText(error: Object): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return '操作失败，请稍后重试';
  }

  private async bootstrap(): Promise<void> {
    this.booting = true;
    this.error = '';
    try {
      const me = await this.api.me();
      this.applyMe(me);
      await this.loadTree();
      await this.loadHome();
      this.loggedIn = true;
    } catch (error) {
      this.token = '';
      this.error = this.errorText(error);
    } finally {
      this.booting = false;
    }
  }

  private applyMe(me: ApiMeResult): void {
    this.displayName = me.user.displayName;
    this.currentUserId = me.user.id;
    this.familyName = me.family.name;
    this.familyId = me.family.id;
    this.familySurname = me.family.surname;
    this.familyMotto = me.family.motto;
    this.memberCount = me.family.memberCount;
    this.branchCount = me.family.branchCount;
    this.role = me.membership.role;
    this.linkedPersonId = me.membership.personId === undefined ? '' : me.membership.personId;
  }

  private async loadTree(): Promise<void> {
    const tree = await this.api.tree();
    this.tree = tree;
    this.layout = TreeLayoutBuilder.build(tree);
    this.treeFitted = false;
    this.treeSelectedId = '';
    this.resetTreeFit();
    const linked = this.linkedPersonId;
    if (linked.length > 0) {
      const self = tree.persons.find((person: ApiPerson) => person.id === linked);
      if (self !== undefined) {
        this.myGeneration = self.generationLabel;
      }
    }
  }

  private async loadHome(): Promise<void> {
    const activity = await this.api.activity();
    this.activities = activity.items;
    const anniversary = await this.api.anniversaries();
    this.anniversaries = anniversary.items;
    await this.refreshUnread();
  }

  private isHostError(message: string): boolean {
    return message.includes('主机') || message.includes('host') ||
      message.includes('Host') || message.includes('解析') ||
      message.includes('resolve');
  }

  private async loginWith(server: string): Promise<void> {
    this.api.setServer(server);
    const result = await this.api.login(this.loginName, this.password);
    this.token = result.token;
    this.serverDraft = server;
    this.savedServer = server;
    this.serverMode = server === LAN_SERVER ? 1 : 0;
    this.api.setSession(server, result.token);
    this.applyMe(await this.api.me());
    await this.loadTree();
    await this.loadHome();
    this.loggedIn = true;
    this.password = '';
  }

  private async doLogin(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.error = '';
    try {
      await this.loginWith(this.serverDraft);
    } catch (error) {
      const firstMessage = this.errorText(error);
      // The public domain currently has an IPv6-only DNS record. On networks
      // without IPv6 HarmonyOS reports "could not resolve host". Fall back to
      // the LAN HTTP endpoint so the same credentials can still log in at home.
      if (this.serverDraft !== LAN_SERVER && this.isHostError(firstMessage)) {
        try {
          await this.loginWith(LAN_SERVER);
          this.toast('已切换到家庭局域网登录');
          return;
        } catch (lanError) {
          this.error = firstMessage + '；局域网登录也失败：' + this.errorText(lanError);
          return;
        }
      }
      this.error = firstMessage;
    } finally {
      this.busy = false;
    }
  }

  private async completeAuthenticatedSession(server: string, token: string): Promise<void> {
    this.token = token;
    this.serverDraft = server;
    this.savedServer = server;
    this.serverMode = server === LAN_SERVER ? 1 : 0;
    this.api.setSession(server, token);
    this.applyMe(await this.api.me());
    await this.loadTree();
    await this.loadHome();
    this.loggedIn = true;
    this.authPage = 'login';
    this.password = '';
    this.authError = '';
  }

  private async doRegister(): Promise<void> {
    if (this.authBusy) return;
    if (this.regLoginName.trim().length === 0 ||
      this.regDisplayName.trim().length === 0) {
      this.authError = '请填写登录名和显示名';
      return;
    }
    if (this.regPassword.length < 8) {
      this.authError = '密码至少 8 位';
      return;
    }
    if (this.regPassword !== this.regConfirm) {
      this.authError = '两次密码不一致';
      return;
    }
    if (!this.regAcceptTerms) {
      this.authError = '请先同意用户协议和隐私政策';
      return;
    }
    this.authBusy = true;
    this.authError = '';
    try {
      this.api.setServer(this.serverDraft);
      await this.api.register(
        this.regLoginName.trim(),
        this.regPassword,
        this.regDisplayName.trim(),
        this.regInviteCode.trim().toUpperCase(),
        this.regPhone.trim(),
        this.regFamilyName.trim(),
        this.regSurname.trim(),
        true
      );
      const result = await this.api.login(
        this.regLoginName.trim(),
        this.regPassword
      );
      await this.completeAuthenticatedSession(this.serverDraft, result.token);
      this.toast('注册成功，已进入家族');
    } catch (error) {
      this.authError = this.errorText(error);
    } finally {
      this.authBusy = false;
    }
  }

  private async sendPhoneLoginCode(): Promise<void> {
    const phone = this.phoneLoginPhone.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      this.authError = '请使用国际格式手机号，例如 +8613800000000';
      return;
    }
    this.authBusy = true;
    this.authError = '';
    try {
      this.api.setServer(this.serverDraft);
      await this.api.sendLoginCode(phone);
      this.phoneCodeSent = true;
      this.toast('验证码已发送');
    } catch (error) {
      this.authError = this.errorText(error);
    } finally {
      this.authBusy = false;
    }
  }

  private async doPhoneLogin(): Promise<void> {
    if (this.authBusy) return;
    if (this.phoneLoginCode.trim().length !== 6) {
      this.authError = '请输入 6 位验证码';
      return;
    }
    this.authBusy = true;
    this.authError = '';
    try {
      this.api.setServer(this.serverDraft);
      const result = await this.api.loginWithPhone(
        this.phoneLoginPhone.trim(),
        this.phoneLoginCode.trim()
      );
      await this.completeAuthenticatedSession(this.serverDraft, result.token);
      this.toast('手机号登录成功');
    } catch (error) {
      this.authError = this.errorText(error);
    } finally {
      this.authBusy = false;
    }
  }

  private async doResetPassword(): Promise<void> {
    if (this.authBusy) return;
    if (this.resetLoginName.trim().length === 0 ||
      this.resetRecoveryCode.trim().length === 0 ||
      this.resetNewPassword.length < 8) {
      this.authError = '请填写登录名、找回码和至少 8 位的新密码';
      return;
    }
    this.authBusy = true;
    this.authError = '';
    try {
      this.api.setServer(this.serverDraft);
      await this.api.resetPassword(
        this.resetLoginName.trim(),
        this.resetRecoveryCode.trim(),
        this.resetNewPassword
      );
      this.loginName = this.resetLoginName.trim();
      this.authPage = 'login';
      this.authError = '';
      this.toast('密码已重置，请用新密码登录');
    } catch (error) {
      this.authError = this.errorText(error);
    } finally {
      this.authBusy = false;
    }
  }

  private logout(): void {
    this.token = '';
    this.loggedIn = false;
    this.page = 'tabs';
    this.tab = 0;
    this.tree = null;
    this.layout = null;
    this.selected = null;
    this.activities = [];
    this.anniversaries = [];
  }

  private async refreshAll(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      this.applyMe(await this.api.me());
      await this.loadTree();
      await this.loadHome();
      this.drawTree();
    } catch (error) {
      this.toast(this.errorText(error));
    } finally {
      this.busy = false;
    }
  }

  private async openPerson(personId: string): Promise<void> {
    this.detailBusy = true;
    this.page = 'detail';
    this.error = '';
    try {
      this.selected = await this.api.person(personId);
      this.personPhotos = [];
      try {
        const photos = await this.api.photos(personId);
        this.personPhotos = photos.items;
      } catch (_) {
        // The profile is still usable if the photo list is unavailable.
      }
    } catch (error) {
      this.error = this.errorText(error);
    } finally {
      this.detailBusy = false;
    }
  }

  private async openAdd(): Promise<void> {
    this.error = '';
    this.addSurname = this.familySurname;
    this.addGiven = '';
    this.addGender = 'male';
    this.addGeneration = this.tree !== null && this.tree.persons.length > 0
      ? String(this.highestGeneration()) : '1';
    this.addBranchIndex = 0;
    this.page = 'add';
    try {
      const page = await this.api.branches();
      this.branches = page.items;
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private highestGeneration(): number {
    if (this.tree === null) return 1;
    let value = 1;
    this.tree.persons.forEach((person: ApiPerson) => {
      value = Math.max(value, person.generationNo);
    });
    return value;
  }

  private async createPerson(): Promise<void> {
    if (this.busy) return;
    if (this.addSurname.trim().length === 0 || this.addGiven.trim().length === 0) {
      this.toast('请填写姓和名');
      return;
    }
    const generation = Number(this.addGeneration);
    if (!Number.isInteger(generation) || generation < 1 || generation > 99) {
      this.toast('世代需为 1-99 的数字');
      return;
    }
    if (this.branches.length === 0) {
      this.toast('还没有可用的家支');
      return;
    }
    this.busy = true;
    try {
      const branch = this.branches[Math.min(this.addBranchIndex, this.branches.length - 1)];
      await this.api.createPerson(
        this.addSurname.trim(),
        this.addGiven.trim(),
        this.addGender,
        generation,
        branch.id
      );
      await this.loadTree();
      this.page = 'tabs';
      this.tab = 1;
      this.drawTree();
      this.toast('人物已加入族谱');
    } catch (error) {
      this.toast(this.errorText(error));
    } finally {
      this.busy = false;
    }
  }

  private confirmDelete(): void {
    const person = this.selected;
    if (person === null) return;
    AlertDialog.show({
      title: '删除人物',
      message: '确定从族谱中删除 ' + person.fullName + ' 吗？\n\n亲属关系会结束，账号绑定和照片人物标记会解除，操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B4423D',
        action: () => {
          this.deleteSelected(person.id);
        }
      }
    });
  }

  private async deleteSelected(personId: string): Promise<void> {
    this.busy = true;
    try {
      await this.api.deletePerson(personId);
      await this.loadTree();
      this.selected = null;
      this.page = 'tabs';
      this.tab = 1;
      this.drawTree();
      this.toast('人物已从族谱删除');
    } catch (error) {
      this.toast(this.errorText(error));
    } finally {
      this.busy = false;
    }
  }

  private toast(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 2200 });
    } catch (_) {
      this.error = message;
    }
  }

  private async openAlbum(): Promise<void> {
    this.page = 'album';
    this.viewerPhoto = null;
    await this.loadPhotos();
  }

  private openMembers(): void {
    this.page = 'members';
  }

  private openAlbumForPerson(personId: string): void {
    if (this.tree !== null) {
      const index = this.tree.persons.findIndex(
        (person: ApiPerson) => person.id === personId
      );
      if (index >= 0) {
        this.albumFilterIndex = index + 1;
      }
    }
    this.openAlbum();
  }

  private albumPersonId(): string {
    if (this.albumFilterIndex <= 0 || this.tree === null) return '';
    const index = this.albumFilterIndex - 1;
    if (index >= this.tree.persons.length) return '';
    return this.tree.persons[index].id;
  }

  private async loadPhotos(): Promise<void> {
    this.albumBusy = true;
    this.albumError = '';
    try {
      const page = await this.api.photos(this.albumPersonId());
      this.albumPhotos = page.items;
    } catch (error) {
      this.albumError = this.errorText(error);
    } finally {
      this.albumBusy = false;
    }
  }

  private async pickAndUploadPhotos(): Promise<void> {
    if (this.albumBusy) return;
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 20
      });
      if (result.photoUris.length === 0) return;
      this.photoFormUris = result.photoUris;
      this.photoFormEditingId = '';
      this.photoFormCaption = '';
      this.photoFormTakenAt = '';
      this.photoFormPersonIds = this.albumPersonId().length > 0
        ? [this.albumPersonId()] : [];
      this.photoFormError = '';
      this.page = 'photoForm';
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private openEditPhotoForm(photo: ApiPhoto): void {
    this.photoFormUris = [];
    this.photoFormEditingId = photo.id;
    this.photoFormCaption = photo.caption;
    this.photoFormTakenAt = photo.takenAt !== undefined
      ? photo.takenAt!.substring(0, 10) : '';
    this.photoFormPersonIds = photo.persons.map(
      (item: ApiPhotoPerson) => item.personId
    );
    this.photoFormError = '';
    this.page = 'photoForm';
  }

  private togglePhotoPerson(personId: string): void {
    if (this.photoFormPersonIds.includes(personId)) {
      this.photoFormPersonIds = this.photoFormPersonIds.filter(
        (id: string) => id !== personId
      );
    } else {
      this.photoFormPersonIds = this.photoFormPersonIds.concat([personId]);
    }
  }

  private async savePhotoForm(): Promise<void> {
    if (this.photoFormBusy) return;
    if (this.photoFormTakenAt.length > 0 &&
      !/^\d{4}-\d{2}-\d{2}$/.test(this.photoFormTakenAt)) {
      this.photoFormError = '拍摄日期格式应为 YYYY-MM-DD';
      return;
    }
    this.photoFormBusy = true;
    this.photoFormError = '';
    try {
      if (this.photoFormEditingId.length > 0) {
        await this.api.updatePhoto(
          this.photoFormEditingId,
          this.photoFormPersonIds,
          this.photoFormCaption.trim(),
          this.photoFormTakenAt.trim()
        );
      } else {
        for (const uri of this.photoFormUris) {
          await this.api.uploadPhotoTagged(
            uri,
            this.photoFormPersonIds,
            this.photoFormCaption.trim(),
            this.photoFormTakenAt.trim()
          );
        }
      }
      const count = this.photoFormUris.length;
      this.viewerPhoto = null;
      await this.loadPhotos();
      this.page = 'album';
      this.toast(this.photoFormEditingId.length > 0
        ? '照片信息已更新'
        : '已上传 ' + String(count) + ' 张照片');
    } catch (error) {
      this.photoFormError = this.errorText(error);
    } finally {
      this.photoFormBusy = false;
    }
  }

  private async pickAvatar(): Promise<void> {
    const person = this.selected;
    if (person === null) return;
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) return;
      const source = image.createImageSource(result.photoUris[0]);
      const pixelMap = await source.createPixelMap();
      await source.release();
      this.avatarSource = pixelMap;
      this.avatarZoom = 1;
      this.avatarError = '';
      this.page = 'avatar';
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private async confirmAvatar(): Promise<void> {
    const person = this.selected;
    const source = this.avatarSource;
    if (person === null || source === undefined) return;
    this.avatarBusy = true;
    this.avatarError = '';
    try {
      const info = await source.getImageInfo();
      const side = Math.max(
        1,
        Math.floor(Math.min(info.size.width, info.size.height) / this.avatarZoom)
      );
      const region: image.Region = {
        x: Math.floor((info.size.width - side) / 2),
        y: Math.floor((info.size.height - side) / 2),
        size: { width: side, height: side }
      };
      await source.crop(region);
      const packer = image.createImagePacker();
      const buffer = await packer.packing(source, {
        format: 'image/jpeg',
        quality: 90
      });
      packer.release();
      await this.api.uploadAvatarBuffer(buffer, person.id);
      this.avatarRevision++;
      await this.openPerson(person.id);
      this.avatarSource = undefined;
      this.toast('头像已更新');
    } catch (error) {
      this.avatarError = this.errorText(error);
    } finally {
      this.avatarBusy = false;
    }
  }

  private confirmDeleteAvatar(): void {
    const person = this.selected;
    if (person === null) return;
    AlertDialog.show({
      title: '移除头像',
      message: '确定移除 ' + person.fullName + ' 的头像吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: '#B4423D',
        action: () => {
          this.deleteAvatar(person.id);
        }
      }
    });
  }

  private async deleteAvatar(personId: string): Promise<void> {
    try {
      await this.api.deleteAvatar(personId);
      this.avatarRevision++;
      await this.openPerson(personId);
      this.toast('头像已移除');
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private confirmDeleteRelation(item: ApiRelative, group: string): void {
    const canWrite = this.canDelete();
    const edgeType = group === '配偶' ? 'spouse' : 'parent_child';
    AlertDialog.show({
      title: canWrite ? '删除亲属关系' : '申请删除亲属关系',
      message: canWrite
        ? '确定删除与 ' + item.fullName + ' 的' + item.relation + '关系吗？只删除关系，不删除人物。'
        : '提交删除与 ' + item.fullName + ' 的' + item.relation +
          '关系的申请，等待族长或管理员审核。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: canWrite ? '删除关系' : '提交申请',
        fontColor: '#B4423D',
        action: () => {
          this.deleteRelation(item, group, edgeType, canWrite);
        }
      }
    });
  }

  private async deleteRelation(
    item: ApiRelative,
    group: string,
    edgeType: string,
    canWrite: boolean
  ): Promise<void> {
    try {
      if (canWrite) {
        if (edgeType === 'spouse') {
          await this.api.deleteSpouse(item.edgeId);
        } else {
          await this.api.deleteParentChild(item.edgeId);
        }
        await this.loadTree();
        await this.openPerson(item.personId);
        this.toast('关系已删除');
      } else {
        await this.api.createRelationshipEndRequest(edgeType, item.edgeId);
        this.toast('关系纠错申请已提交');
      }
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private openAddRelation(): void {
    this.relationTypeIndex = 0;
    this.relationPersonIndex = 0;
    this.relationError = '';
    this.page = 'addRelation';
  }

  private relationPersonOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '选择人物' }];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        if (this.selected === null || person.id !== this.selected.id) {
          options.push({ value: person.fullName + ' · ' + person.generationLabel });
        }
      });
    }
    return options;
  }

  private relationTargetId(): string {
    if (this.tree === null || this.relationPersonIndex <= 0) return '';
    const filtered = this.tree.persons.filter((person: ApiPerson) =>
      this.selected === null || person.id !== this.selected.id
    );
    const index = this.relationPersonIndex - 1;
    return index < filtered.length ? filtered[index].id : '';
  }

  private async addRelation(): Promise<void> {
    if (this.selected === null || this.relationBusy) return;
    const targetId = this.relationTargetId();
    if (targetId.length === 0) {
      this.relationError = '请选择关联人物';
      return;
    }
    this.relationBusy = true;
    this.relationError = '';
    try {
      if (this.relationTypeIndex === 2) {
        await this.api.addSpouse(this.selected.id, targetId);
      } else if (this.relationTypeIndex === 3) {
        await this.api.addParentChild(
          this.selected.id,
          targetId,
          this.selected.gender === 'female' ? 'mother' : 'father'
        );
      } else {
        await this.api.addParentChild(
          targetId,
          this.selected.id,
          this.relationTypeIndex === 1 ? 'mother' : 'father'
        );
      }
      const personId = this.selected.id;
      await this.loadTree();
      await this.openPerson(personId);
      this.page = 'detail';
      this.toast('亲属关系已添加');
    } catch (error) {
      this.relationError = this.errorText(error);
    } finally {
      this.relationBusy = false;
    }
  }

  private confirmBindPerson(): void {
    const person = this.selected;
    if (person === null) return;
    AlertDialog.show({
      title: '绑定族谱人物',
      message: '确定把自己绑定为“' + person.fullName +
        '”吗？提交后需要族长或管理员审核。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '提交申请',
        action: () => {
          this.bindToPerson(person.id);
        }
      }
    });
  }

  private async bindToPerson(personId: string): Promise<void> {
    try {
      await this.api.createBindingRequest(personId);
      this.toast('绑定申请已提交');
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private async openEditPerson(): Promise<void> {
    const person = this.selected;
    if (person === null) return;
    this.editSurname = person.surname;
    this.editGivenName = person.givenName;
    this.editCourtesyName = person.courtesyName === undefined ? '' : person.courtesyName!;
    this.editAlias = person.alias === undefined ? '' : person.alias!;
    this.editGender = person.gender;
    this.editGeneration = String(person.generationNo);
    this.editLifeStatus = person.lifeStatus;
    this.editBirthYear = person.birth !== undefined && person.birth!.year !== undefined
      ? String(person.birth!.year) : '';
    this.editBirthPlace = person.birthPlace === undefined ? '' : person.birthPlace!;
    this.editResidence = person.residence === undefined ? '' : person.residence!;
    this.editOccupation = person.occupation === undefined ? '' : person.occupation!;
    this.editEducation = person.education === undefined ? '' : person.education!;
    this.editBiography = person.biography === undefined ? '' : person.biography!;
    this.editVersion = person.version;
    this.editError = '';
    this.page = 'editPerson';
    try {
      const page = await this.api.branches();
      this.dataBranches = page.items;
      this.editBranchIndex = 0;
      if (person.branchId !== undefined) {
        const index = page.items.findIndex(
          (branch: ApiBranch) => branch.id === person.branchId
        );
        if (index >= 0) this.editBranchIndex = index;
      }
    } catch (_) {
      // Keep an empty branch list; save will report the problem.
    }
  }

  private openProfileRequest(): void {
    const person = this.selected;
    if (person === null) return;
    this.profileReqBirthPlace = person.birthPlace === undefined ? '' : person.birthPlace!;
    this.profileReqResidence = person.residence === undefined ? '' : person.residence!;
    this.profileReqOccupation = person.occupation === undefined ? '' : person.occupation!;
    this.profileReqEducation = person.education === undefined ? '' : person.education!;
    this.profileReqBiography = person.biography === undefined ? '' : person.biography!;
    this.profileReqError = '';
    this.page = 'profileRequest';
  }

  private async submitProfileRequest(): Promise<void> {
    const person = this.selected;
    if (person === null || this.profileReqBusy) return;
    const changes: Record<string, string> = {};
    const originalBirthPlace = person.birthPlace === undefined ? '' : person.birthPlace!;
    const originalResidence = person.residence === undefined ? '' : person.residence!;
    const originalOccupation = person.occupation === undefined ? '' : person.occupation!;
    const originalEducation = person.education === undefined ? '' : person.education!;
    const originalBiography = person.biography === undefined ? '' : person.biography!;
    if (this.profileReqBirthPlace.trim() !== originalBirthPlace) {
      changes['birthPlace'] = this.profileReqBirthPlace.trim();
    }
    if (this.profileReqResidence.trim() !== originalResidence) {
      changes['residence'] = this.profileReqResidence.trim();
    }
    if (this.profileReqOccupation.trim() !== originalOccupation) {
      changes['occupation'] = this.profileReqOccupation.trim();
    }
    if (this.profileReqEducation.trim() !== originalEducation) {
      changes['education'] = this.profileReqEducation.trim();
    }
    if (this.profileReqBiography.trim() !== originalBiography) {
      changes['biography'] = this.profileReqBiography.trim();
    }
    if (Object.keys(changes).length === 0) {
      this.profileReqError = '还没有修改任何资料';
      return;
    }
    this.profileReqBusy = true;
    this.profileReqError = '';
    try {
      await this.api.createProfileRequest(person.id, person.version, changes);
      this.page = 'detail';
      this.toast('资料修改申请已提交，等待审核');
    } catch (error) {
      this.profileReqError = this.errorText(error);
    } finally {
      this.profileReqBusy = false;
    }
  }

  private async saveEditedPerson(): Promise<void> {    const person = this.selected;
    if (person === null || this.editBusy) return;
    const generation = Number(this.editGeneration);
    if (this.editSurname.trim().length === 0 ||
      this.editGivenName.trim().length === 0 ||
      !Number.isInteger(generation) || generation < 1 || generation > 99) {
      this.editError = '请填写姓、名和 1-99 的世代';
      return;
    }
    if (this.dataBranches.length === 0) {
      this.editError = '没有可用家支';
      return;
    }
    const branchIndex = Math.min(this.editBranchIndex, this.dataBranches.length - 1);
    const birthYear = Number(this.editBirthYear);
    const payload: UpdatePersonPayload = {
      surname: this.editSurname.trim(),
      givenName: this.editGivenName.trim(),
      courtesyName: this.editCourtesyName.trim(),
      alias: this.editAlias.trim(),
      gender: this.editGender,
      generationNo: generation,
      generationName: person.generationName === undefined ? '' : person.generationName!,
      branchId: this.dataBranches[branchIndex].id,
      birthCalendar: 'solar',
      deathCalendar: 'solar',
      lifeStatus: this.editLifeStatus,
      birthPlace: this.editBirthPlace.trim(),
      residence: this.editResidence.trim(),
      occupation: this.editOccupation.trim(),
      education: this.editEducation.trim(),
      biography: this.editBiography.trim(),
      version: this.editVersion
    };
    if (this.editBirthYear.trim().length > 0 && Number.isFinite(birthYear)) {
      payload.birthYear = birthYear;
    }
    this.editBusy = true;
    this.editError = '';
    try {
      const updated = await this.api.updatePerson(person.id, payload);
      this.selected = updated;
      await this.loadTree();
      this.page = 'detail';
      this.toast('人物资料已更新');
    } catch (error) {
      this.editError = this.errorText(error);
    } finally {
      this.editBusy = false;
    }
  }

  private confirmDeletePhoto(): void {
    const photo = this.viewerPhoto;
    if (photo === null) return;
    AlertDialog.show({
      title: '删除照片',
      message: '确定从家族相册删除这张照片吗？此操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B4423D',
        action: () => {
          this.deletePhoto(photo.id);
        }
      }
    });
  }

  private async deletePhoto(photoId: string): Promise<void> {
    this.viewerBusy = true;
    try {
      await this.api.deletePhoto(photoId);
      this.viewerPhoto = null;
      await this.loadPhotos();
      this.toast('照片已删除');
    } catch (error) {
      this.toast(this.errorText(error));
    } finally {
      this.viewerBusy = false;
    }
  }

  private async openStories(): Promise<void> {
    this.page = 'stories';
    this.selectedStory = null;
    await this.loadStories();
  }

  private async loadStories(): Promise<void> {
    this.storiesBusy = true;
    this.storiesError = '';
    try {
      const page = await this.api.stories();
      this.stories = page.items;
    } catch (error) {
      this.storiesError = this.errorText(error);
    } finally {
      this.storiesBusy = false;
    }
  }

  private async openStory(story: ApiStory): Promise<void> {
    this.selectedStory = story;
    this.page = 'storyDetail';
    this.storyDetailBusy = true;
    try {
      this.selectedStory = await this.api.story(story.id);
    } catch (error) {
      this.storiesError = this.errorText(error);
    } finally {
      this.storyDetailBusy = false;
    }
  }

  private openStoryEditor(): void {
    this.storyEditingId = '';
    this.storyExistingPhotos = [];
    this.storyTitle = '';
    this.storyBody = '';
    this.storyPersonIndex = 0;
    this.storyPhotoUris = [];
    this.storyStatus = '';
    this.storyError = '';
    this.page = 'storyEdit';
  }

  private openEditStory(story: ApiStory): void {
    this.storyEditingId = story.id;
    this.storyExistingPhotos = story.photos;
    this.storyTitle = story.title;
    this.storyBody = story.body;
    this.storyPersonIndex = 0;
    if (story.personId !== undefined && this.tree !== null) {
      const index = this.tree.persons.findIndex(
        (person: ApiPerson) => person.id === story.personId
      );
      if (index >= 0) this.storyPersonIndex = index + 1;
    }
    this.storyPhotoUris = [];
    this.storyStatus = '';
    this.storyError = '';
    this.page = 'storyEdit';
  }

  private storyPersonOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '不关联人物' }];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        options.push({ value: person.fullName });
      });
    }
    return options;
  }

  private storyPersonId(): string {
    if (this.storyPersonIndex <= 0 || this.tree === null) return '';
    const index = this.storyPersonIndex - 1;
    if (index >= this.tree.persons.length) return '';
    return this.tree.persons[index].id;
  }

  private async pickStoryPhotos(): Promise<void> {
    const remaining = 9 - this.storyExistingPhotos.length - this.storyPhotoUris.length;
    if (remaining <= 0) {
      this.storyError = '故事最多附带 9 张图片';
      return;
    }
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: remaining
      });
      if (result.photoUris.length > 0) {
        const merged = this.storyPhotoUris.concat(result.photoUris);
        this.storyPhotoUris = merged.slice(0, 9);
        this.storyError = '';
      }
    } catch (error) {
      this.storyError = this.errorText(error);
    }
  }

  private async saveStory(): Promise<void> {
    if (this.storySaving) return;
    const title = this.storyTitle.trim();
    const body = this.storyBody.trim();
    if (title.length === 0 || body.length === 0) {
      this.storyError = '标题和正文都要填写';
      return;
    }
    if (title.length > 120) {
      this.storyError = '标题不能超过 120 个字';
      return;
    }
    this.storySaving = true;
    this.storyError = '';
    this.storyStatus = '';
    try {
      const personId = this.storyPersonId();
      const photoIds: string[] = this.storyExistingPhotos.map(
        (photo: ApiPhoto) => photo.id
      );
      for (let i = 0; i < this.storyPhotoUris.length; i++) {
        this.storyStatus = '正在上传图片 ' + String(i + 1) + '/' +
          String(this.storyPhotoUris.length);
        const uploaded = await this.api.uploadPhoto(this.storyPhotoUris[i], personId);
        photoIds.push(uploaded.id);
      }
      this.storyStatus = '正在保存故事...';
      if (this.storyEditingId.length > 0) {
        await this.api.updateStory(
          this.storyEditingId,
          title,
          body,
          personId,
          photoIds
        );
      } else {
        await this.api.createStory(title, body, personId, photoIds);
      }
      await this.loadStories();
      this.page = 'stories';
      this.toast(this.storyEditingId.length > 0 ? '故事已更新' : '故事已发布');
    } catch (error) {
      this.storyError = this.errorText(error);
    } finally {
      this.storySaving = false;
      this.storyStatus = '';
    }
  }

  private confirmDeleteStory(): void {
    const story = this.selectedStory;
    if (story === null) return;
    AlertDialog.show({
      title: '删除故事',
      message: '确定删除《' + story.title + '》吗？图片会保留在家族相册。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#B4423D',
        action: () => {
          this.deleteStory(story.id);
        }
      }
    });
  }

  private async deleteStory(storyId: string): Promise<void> {
    try {
      await this.api.deleteStory(storyId);
      this.selectedStory = null;
      await this.loadStories();
      this.page = 'stories';
      this.toast('故事已删除');
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private async openInbox(): Promise<void> {
    this.page = 'inbox';
    this.inboxTab = 0;
    await this.loadInbox();
  }

  private async loadInbox(): Promise<void> {
    this.inboxBusy = true;
    this.inboxError = '';
    try {
      const page = await this.api.notifications();
      this.notifications = page.items;
      this.unreadCount = page.unreadCount;
      if (this.canDelete()) {
        const edits = await this.api.editRequests('pending');
        this.editReviews = edits.items;
        const bindings = await this.api.bindingRequests('pending');
        this.bindingReviews = bindings.items;
      } else {
        const mine = await this.api.editRequests('', true);
        this.myRequests = mine.items;
      }
    } catch (error) {
      this.inboxError = this.errorText(error);
    } finally {
      this.inboxBusy = false;
    }
  }

  private async refreshUnread(): Promise<void> {
    try {
      this.unreadCount = await this.api.unreadNotificationCount();
    } catch (_) {
      // A missing badge must not block the home page.
    }
  }

  private async markAllNotificationsRead(): Promise<void> {
    try {
      await this.api.markNotificationRead(0, true);
      this.unreadCount = 0;
      this.notifications = this.notifications.map((item: ApiNotification) => {
        item.isRead = true;
        return item;
      });
      this.toast('已全部标为已读');
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private async markNotificationRead(item: ApiNotification): Promise<void> {
    if (!item.isRead) {
      try {
        await this.api.markNotificationRead(item.id, false);
        item.isRead = true;
        this.notifications = this.notifications.slice();
        this.unreadCount = Math.max(0, this.unreadCount - 1);
      } catch (error) {
        this.toast(this.errorText(error));
        return;
      }
    }
    if (item.targetType === 'person' && item.targetId.length > 0) {
      this.openPerson(item.targetId);
    } else if (item.targetType === 'story' && item.targetId.length > 0) {
      try {
        const story = await this.api.story(item.targetId);
        this.openStory(story);
      } catch (_) {
        this.openStories();
      }
    } else if (item.targetType === 'photo') {
      this.openAlbum();
    } else if (item.targetType === 'edit_request' ||
      item.targetType === 'binding_request') {
      await this.openInbox();
      this.inboxTab = 1;
    } else if (item.targetType === 'merge_request') {
      this.openMerges();
    }
  }

  private async showEditRequestDetail(item: ApiEditRequest): Promise<void> {
    try {
      const detail = await this.api.editRequest(item.id);
      let message = '申请人：' + detail.requesterName + '\n' +
        '内容：' + detail.summary;
      const changes = detail.changes;
      if (changes !== undefined) {
        const keys = Object.keys(changes);
        if (keys.length > 0) {
          message += '\n\n修改内容：';
          keys.forEach((key: string) => {
            const label = this.changeFieldLabel(key);
            message += '\n' + label + '：' + changes[key];
          });
        }
      }
      if (detail.reviewNote !== undefined && detail.reviewNote!.length > 0) {
        message += '\n\n审核意见：' + detail.reviewNote;
      }
      AlertDialog.show({
        title: '申请详情',
        message: message,
        confirm: {
          value: '知道了',
          action: () => {
          }
        }
      });
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private changeFieldLabel(key: string): string {
    if (key === 'birthPlace') return '籍贯';
    if (key === 'residence') return '现居地';
    if (key === 'occupation') return '职业';
    if (key === 'education') return '教育';
    if (key === 'biography') return '生平简介';
    return key;
  }

  private startReview(kind: string, id: string, label: string, approve: boolean): void {    this.reviewKind = kind;
    this.reviewId = id;
    this.reviewLabel = label;
    this.reviewApprove = approve;
    this.reviewNote = '';
    this.reviewError = '';
  }

  private cancelReview(): void {
    this.reviewKind = '';
    this.reviewId = '';
    this.reviewLabel = '';
    this.reviewNote = '';
    this.reviewError = '';
  }

  private async submitReview(): Promise<void> {
    if (this.reviewBusy || this.reviewId.length === 0) return;
    const note = this.reviewNote.trim();
    if (!this.reviewApprove && note.length === 0) {
      this.reviewError = '拒绝时必须填写原因';
      return;
    }
    this.reviewBusy = true;
    this.reviewError = '';
    try {
      if (this.reviewKind === 'edit') {
        await this.api.reviewEditRequest(this.reviewId, this.reviewApprove, note);
        await this.loadTree();
        this.applyMe(await this.api.me());
      } else {
        await this.api.reviewBindingRequest(this.reviewId, this.reviewApprove, note);
        await this.loadTree();
        this.applyMe(await this.api.me());
      }
      const message = this.reviewApprove ? '已通过申请' : '已拒绝申请';
      this.cancelReview();
      await this.loadInbox();
      this.toast(message);
    } catch (error) {
      this.reviewError = this.errorText(error);
    } finally {
      this.reviewBusy = false;
    }
  }

  private async openMerges(): Promise<void> {
    this.page = 'merges';
    await this.loadMerges();
  }

  private async loadMerges(): Promise<void> {
    this.mergesBusy = true;
    this.mergesError = '';
    try {
      const page = await this.api.mergeRequests();
      this.mergeRequests = page.items;
    } catch (error) {
      this.mergesError = this.errorText(error);
    } finally {
      this.mergesBusy = false;
    }
  }

  private async openMerge(request: ApiFamilyMergeRequest): Promise<void> {
    this.page = 'mergeDetail';
    this.mergeDetail = null;
    this.mergeDetailBusy = true;
    this.mergeError = '';
    try {
      const detail = await this.api.mergeDetail(request.id);
      this.mergeDetail = detail;
      const pending = detail.request.status === 'pending';
      const selectedPersons = detail.request.selectedPersonIds;
      const selectedStories = detail.request.selectedStoryIds;
      const selectedPhotos = detail.request.selectedPhotoIds;
      this.mergePersonIds = selectedPersons !== undefined && selectedPersons.length > 0
        ? selectedPersons
        : (pending ? detail.persons.map((person: ApiMergePerson) => person.id) : []);
      this.mergeStoryIds = selectedStories !== undefined && selectedStories.length > 0
        ? selectedStories
        : (pending ? detail.stories.map((story: ApiMergeStory) => story.id) : []);
      this.mergePhotoIds = selectedPhotos !== undefined && selectedPhotos.length > 0
        ? selectedPhotos
        : (pending ? detail.photos.map((photo: ApiMergePhoto) => photo.id) : []);
      this.mergeBranchIndex = 0;
      if (detail.request.targetBranchId !== undefined) {
        const found = detail.branches.findIndex(
          (branch: ApiBranch) => branch.id === detail.request.targetBranchId
        );
        if (found >= 0) this.mergeBranchIndex = found;
      }
      this.mergeStartGeneration = detail.request.startGeneration !== undefined
        ? detail.request.startGeneration
        : Math.min(99, this.highestGeneration() + 1);
      this.mergeAttachIndex = 0;
      this.mergeNote = detail.request.reviewNote === undefined
        ? '' : detail.request.reviewNote;
    } catch (error) {
      this.mergesError = this.errorText(error);
    } finally {
      this.mergeDetailBusy = false;
    }
  }

  private mergeBranchId(): string {
    const detail = this.mergeDetail;
    if (detail === null || detail.branches.length === 0) return '';
    const index = Math.min(this.mergeBranchIndex, detail.branches.length - 1);
    return detail.branches[index].id;
  }

  private mergeAttachOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '不挂靠父辈' }];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        options.push({ value: person.fullName });
      });
    }
    return options;
  }

  private mergeAttachParentId(): string {
    if (this.mergeAttachIndex <= 0 || this.tree === null) return '';
    const index = this.mergeAttachIndex - 1;
    if (index >= this.tree.persons.length) return '';
    return this.tree.persons[index].id;
  }

  private toggleMergeId(ids: string[], id: string): string[] {
    if (ids.includes(id)) {
      return ids.filter((item: string) => item !== id);
    }
    return ids.concat([id]);
  }

  private toggleMergePerson(id: string): void {
    this.mergePersonIds = this.toggleMergeId(this.mergePersonIds, id);
  }

  private toggleMergeStory(id: string): void {
    this.mergeStoryIds = this.toggleMergeId(this.mergeStoryIds, id);
  }

  private toggleMergePhoto(id: string): void {
    this.mergePhotoIds = this.toggleMergeId(this.mergePhotoIds, id);
  }

  private approveMergeTap(): void {
    const detail = this.mergeDetail;
    if (detail === null) return;
    if (this.mergePersonIds.length + this.mergeStoryIds.length +
      this.mergePhotoIds.length === 0) {
      this.mergeError = '请至少选择一位人物、一篇故事或一张照片';
      return;
    }
    const start = Math.max(1, Math.min(99, this.mergeStartGeneration));
    if (detail.minGeneration > 0 &&
      start + detail.maxGeneration - detail.minGeneration > 99) {
      this.mergeError = '合并后的世代会超过第 99 世，请调小起始世代';
      return;
    }
    if (this.mergeBranchId().length === 0) {
      this.mergeError = '请选择目标家支';
      return;
    }
    this.mergeError = '';
    AlertDialog.show({
      title: '确认合并',
      message: '将把 ' + String(this.mergePersonIds.length) + ' 位人物、' +
        String(this.mergeStoryIds.length) + ' 篇故事、' +
        String(this.mergePhotoIds.length) + ' 张照片合并到当前家族。\n\n' +
        '合并后原家族没有其他成员时会被归档。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认合并',
        action: () => {
          this.doApproveMerge();
        }
      }
    });
  }

  private async doApproveMerge(): Promise<void> {
    const detail = this.mergeDetail;
    if (detail === null || this.mergeSubmitting) return;
    this.mergeSubmitting = true;
    this.mergeError = '';
    try {
      const result = await this.api.approveMerge(
        detail.request.id,
        this.mergePersonIds,
        this.mergeStoryIds,
        this.mergePhotoIds,
        this.mergeBranchId(),
        Math.max(1, Math.min(99, this.mergeStartGeneration)),
        this.mergeAttachParentId(),
        this.mergeNote.trim()
      );
      await this.loadTree();
      this.applyMe(await this.api.me());
      await this.loadMerges();
      AlertDialog.show({
        title: '合并完成',
        message: '已合并 ' + String(result.importedPersons) + ' 位人物、' +
          String(result.importedStories) + ' 篇故事、' +
          String(result.importedPhotos) + ' 张照片。' +
          (result.sourceArchived ? '原家族已归档。' : '原家族仍有其他成员，继续保持独立。'),
        confirm: {
          value: '知道了',
          action: () => {
            this.page = 'merges';
          }
        }
      });
    } catch (error) {
      this.mergeError = this.errorText(error);
    } finally {
      this.mergeSubmitting = false;
    }
  }

  private rejectMergeTap(): void {
    if (this.mergeDetail === null) return;
    if (this.mergeNote.trim().length === 0) {
      this.mergeError = '拒绝合并时必须填写原因';
      return;
    }
    AlertDialog.show({
      title: '拒绝合并',
      message: '确定拒绝这个家族合并申请吗？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认拒绝',
        fontColor: '#B4423D',
        action: () => {
          this.doRejectMerge();
        }
      }
    });
  }

  private async doRejectMerge(): Promise<void> {
    const detail = this.mergeDetail;
    if (detail === null || this.mergeSubmitting) return;
    this.mergeSubmitting = true;
    this.mergeError = '';
    try {
      await this.api.rejectMerge(detail.request.id, this.mergeNote.trim());
      await this.loadMerges();
      this.page = 'merges';
      this.toast('已拒绝合并申请');
    } catch (error) {
      this.mergeError = this.errorText(error);
    } finally {
      this.mergeSubmitting = false;
    }
  }

  private async openData(): Promise<void> {
    this.page = 'data';
    this.dataError = '';
    this.dataBusy = true;
    try {
      const page = await this.api.branches();
      this.dataBranches = page.items;
    } catch (error) {
      this.dataError = this.errorText(error);
    } finally {
      this.dataBusy = false;
    }
  }

  private exportRootOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '选择根人物' }];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        options.push({ value: person.fullName });
      });
    }
    return options;
  }

  private exportRootId(): string {
    if (this.exportRootIndex <= 0 || this.tree === null) return '';
    const index = this.exportRootIndex - 1;
    if (index >= this.tree.persons.length) return '';
    return this.tree.persons[index].id;
  }

  private async generateImportCode(): Promise<void> {
    const rootId = this.exportRootId();
    if (rootId.length === 0) {
      this.dataError = '请先选择要导出的根人物';
      return;
    }
    this.exportBusy = true;
    this.dataError = '';
    try {
      this.exportPackage = await this.api.createImportPackage(rootId);
      this.exportCode = this.exportPackage.code;
    } catch (error) {
      this.dataError = this.errorText(error);
    } finally {
      this.exportBusy = false;
    }
  }

  private async copyExportCode(): Promise<void> {
    if (this.exportCode.length === 0) return;
    try {
      const data = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        this.exportCode
      );
      await pasteboard.getSystemPasteboard().setData(data);
      this.toast('导入码已复制');
    } catch (error) {
      this.toast(this.errorText(error));
    }
  }

  private async exportFamilyData(): Promise<void> {
    if (this.exportBusy) return;
    this.exportBusy = true;
    this.dataError = '';
    try {
      const json = await this.api.exportFamilyJSON(this.familyId);
      if (json.length === 0) {
        throw new Error('服务器返回了空数据');
      }
      let baseName = this.familyName.length > 0 ? this.familyName : '家族';
      baseName = baseName.replace(/[\\/:*?"<>|]/g, '_');
      const filename = baseName + '_族谱数据_' + String(Date.now()) + '.json';
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.save({ newFileNames: [filename] });
      if (uris.length === 0) {
        throw new Error('没有选择保存位置');
      }
      const file = fs.openSync(
        uris[0],
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );
      try {
        fs.writeSync(file.fd, json);
      } finally {
        fs.closeSync(file);
      }
      this.toast('家族数据已导出');
    } catch (error) {
      this.dataError = this.errorText(error);
    } finally {
      this.exportBusy = false;
    }
  }

  private importParentOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '不挂靠父辈' }];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        options.push({ value: person.fullName });
      });
    }
    return options;
  }

  private importParentId(): string {
    if (this.importParentIndex <= 0 || this.tree === null) return '';
    const index = this.importParentIndex - 1;
    if (index >= this.tree.persons.length) return '';
    return this.tree.persons[index].id;
  }

  private async previewImport(): Promise<void> {
    const code = this.importCode.trim().toUpperCase();
    if (code.length < 6) {
      this.dataError = '请输入有效导入码';
      return;
    }
    this.importPreviewBusy = true;
    this.dataError = '';
    try {
      this.importPreview = await this.api.previewImportPackage(code);
      this.importCode = code;
      this.importGeneration = 1;
      this.importBranchIndex = 0;
      this.importParentIndex = 0;
    } catch (error) {
      this.dataError = this.errorText(error);
    } finally {
      this.importPreviewBusy = false;
    }
  }

  private async doImport(): Promise<void> {
    const preview = this.importPreview;
    if (preview === null || this.importBusy) return;
    if (this.dataBranches.length === 0) {
      this.dataError = '当前家族没有可用的家支';
      return;
    }
    const branchIndex = Math.min(this.importBranchIndex, this.dataBranches.length - 1);
    this.importBusy = true;
    this.dataError = '';
    try {
      const result = await this.api.importPackage(
        preview.code,
        this.dataBranches[branchIndex].id,
        Math.max(1, Math.min(99, this.importGeneration)),
        this.importParentId(),
        this.importParentId().length > 0 ? this.importParentRole : ''
      );
      await this.loadTree();
      this.applyMe(await this.api.me());
      this.importPreview = null;
      AlertDialog.show({
        title: '导入完成',
        message: '已从 ' + result.sourceFamilyName + ' 导入 ' +
          String(result.personCount) + ' 人，' + result.rootName +
          ' 位于第 ' + String(result.rootGeneration) + ' 世。',
        confirm: {
          value: '知道了',
          action: () => {
          }
        }
      });
    } catch (error) {
      this.dataError = this.errorText(error);
    } finally {
      this.importBusy = false;
    }
  }

  private async openFamilyCenter(): Promise<void> {
    this.page = 'familyCenter';
    this.familyCenterError = '';
    await this.loadFamilyCenter();
  }

  private async loadFamilyCenter(): Promise<void> {
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      const families = await this.api.families();
      this.familyEntries = families.items;
      if (this.canDelete()) {
        try {
          const accounts = await this.api.accounts();
          this.familyAccounts = accounts.items;
        } catch (_) {
          this.familyAccounts = [];
        }
        try {
          const invites = await this.api.invites();
          this.familyInvites = invites.items;
        } catch (_) {
          this.familyInvites = [];
        }
      }
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async switchToFamily(familyId: string): Promise<void> {
    if (familyId === this.familyId || this.familyCenterBusy) return;
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      const me = await this.api.switchFamily(familyId);
      this.applyMe(me);
      await this.loadTree();
      await this.loadHome();
      this.page = 'tabs';
      this.tab = 3;
      this.toast('已切换到 ' + me.family.name);
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async joinFamilyByCode(): Promise<void> {
    const code = this.familyJoinCode.trim().toUpperCase();
    if (code.length < 6) {
      this.familyCenterError = '请输入有效邀请码';
      return;
    }
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      const result = await this.api.joinFamily(code);
      const me: ApiMeResult = {
        user: result.user,
        membership: result.membership,
        family: result.family,
        families: result.families
      };
      this.applyMe(me);
      await this.loadTree();
      await this.loadHome();
      this.familyJoinCode = '';
      const archived = result.archivedFamilies === undefined
        ? 0 : result.archivedFamilies.length;
      const merges = result.mergeRequests === undefined
        ? 0 : result.mergeRequests.length;
      this.toast('已加入 ' + result.family.name +
        (archived > 0 ? '，原家族已归档' : '') +
        (merges > 0 ? '，已提交 ' + String(merges) + ' 个合并申请' : ''));
      this.page = 'tabs';
      this.tab = 3;
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async createNewFamily(): Promise<void> {
    const name = this.newFamilyName.trim();
    const surname = this.newFamilySurname.trim();
    if (name.length === 0 || surname.length === 0) {
      this.familyCenterError = '请填写家族名称和姓氏';
      return;
    }
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      const me = await this.api.createFamily(
        name,
        surname,
        this.newFamilyMotto.trim(),
        '',
        ''
      );
      this.applyMe(me);
      await this.loadTree();
      await this.loadHome();
      this.newFamilyName = '';
      this.newFamilySurname = '';
      this.newFamilyMotto = '';
      this.page = 'tabs';
      this.tab = 3;
      this.toast('已创建 ' + me.family.name);
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async changeAccountPassword(): Promise<void> {
    if (this.accountOldPassword.length === 0 || this.accountNewPassword.length < 8) {
      this.familyCenterError = '请输入当前密码，新密码至少 8 位';
      return;
    }
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      await this.api.changePassword(
        this.accountOldPassword,
        this.accountNewPassword
      );
      this.accountOldPassword = '';
      this.accountNewPassword = '';
      this.toast('密码已修改');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async createFamilyInvite(): Promise<void> {
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      const invite = await this.api.createInvite('member', 1, 7);
      this.familyInvites = [invite].concat(this.familyInvites);
      await this.copyText(invite.code);
      this.toast('邀请码已创建并复制');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async copyText(text: string): Promise<void> {
    try {
      const data = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        text
      );
      await pasteboard.getSystemPasteboard().setData(data);
    } catch (_) {
      // Clipboard failures should not hide the code itself.
    }
  }

  private confirmDeleteAccount(): void {
    if (this.accountDeletePassword.length === 0) {
      this.familyCenterError = '请输入密码后再注销账号';
      return;
    }
    AlertDialog.show({
      title: '注销账号',
      message: '注销后账号会退出并删除；如果家族只有你一人，家族也会归档。此操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认注销',
        fontColor: '#B4423D',
        action: () => {
          this.deleteMyAccount();
        }
      }
    });
  }

  private async deleteMyAccount(): Promise<void> {
    this.familyCenterBusy = true;
    try {
      await this.api.deleteAccount(this.accountDeletePassword);
      this.logout();
      this.toast('账号已注销');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async sendBindPhoneCode(): Promise<void> {
    const phone = this.bindPhoneNumber.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      this.familyCenterError = '请使用国际格式手机号，例如 +8613800000000';
      return;
    }
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      await this.api.sendBindCode(phone);
      this.toast('验证码已发送');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async bindMyPhone(): Promise<void> {
    const phone = this.bindPhoneNumber.trim();
    const code = this.bindPhoneCode.trim();
    if (!phone.startsWith('+') || code.length !== 6) {
      this.familyCenterError = '请填写国际格式手机号和 6 位验证码';
      return;
    }
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      await this.api.bindPhone(phone, code);
      this.bindPhoneCode = '';
      this.toast('手机号已绑定');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private async generateRecoveryCode(): Promise<void> {
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      this.recoveryCodeDisplay = await this.api.createRecoveryCode();
      await this.copyText(this.recoveryCodeDisplay);
      this.toast('找回码已生成并复制，请妥善保存');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private confirmTransferOwner(account: ApiFamilyAccount): void {
    AlertDialog.show({
      title: '转让族长',
      message: '确定把族长转让给 ' + account.displayName +
        ' 吗？转让后你将变为管理员，此操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认转让',
        fontColor: '#B4423D',
        action: () => {
          this.transferOwnerTo(account.userId);
        }
      }
    });
  }

  private async transferOwnerTo(userId: string): Promise<void> {
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      await this.api.transferOwner(this.familyId, userId);
      this.applyMe(await this.api.me());
      await this.loadFamilyCenter();
      this.toast('族长已转让');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private confirmArchiveFamily(): void {
    if (this.archiveConfirmName.trim() !== this.familyName) {
      this.familyCenterError = '请输入完整家族名称以确认';
      return;
    }
    if (this.archivePassword.length === 0) {
      this.familyCenterError = '请输入登录密码';
      return;
    }
    AlertDialog.show({
      title: '归档并注销',
      message: '归档当前家族会同时删除你的账号，所有成员将失去这个家族。此操作不可撤销。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认归档',
        fontColor: '#B4423D',
        action: () => {
          this.archiveFamilyNow();
        }
      }
    });
  }

  private async archiveFamilyNow(): Promise<void> {
    this.familyCenterBusy = true;
    this.familyCenterError = '';
    try {
      await this.api.archiveFamily(
        this.familyId,
        this.archivePassword,
        this.archiveConfirmName.trim()
      );
      this.logout();
      this.toast('家族已归档，账号已注销');
    } catch (error) {
      this.familyCenterError = this.errorText(error);
    } finally {
      this.familyCenterBusy = false;
    }
  }

  private filteredPersons(): ApiPerson[] {
    if (this.tree === null) return [];
    const key = this.query.trim();
    const list = this.tree.persons.filter((person: ApiPerson) => {
      if (key.length === 0) return true;
      return person.fullName.includes(key) ||
        person.generationLabel.includes(key) ||
        (person.birthPlace !== undefined && person.birthPlace!.includes(key)) ||
        (person.residence !== undefined && person.residence!.includes(key)) ||
        (person.occupation !== undefined && person.occupation!.includes(key)) ||
        (person.education !== undefined && person.education!.includes(key));
    });
    return list.sort((a: ApiPerson, b: ApiPerson) => {
      if (a.generationNo !== b.generationNo) return a.generationNo - b.generationNo;
      return a.fullName.localeCompare(b.fullName);
    });
  }

  private canDelete(): boolean {
    return this.role === 'owner' || this.role === 'admin';
  }

  private canEditAvatar(): boolean {
    if (this.canDelete()) return true;
    return this.selected !== null && this.selected!.id === this.linkedPersonId;
  }

  private linkedPersonAvatar(): string {
    if (this.tree === null || this.linkedPersonId.length === 0) return '';
    const person = this.tree.persons.find(
      (item: ApiPerson) => item.id === this.linkedPersonId
    );
    if (person === undefined || person.hasAvatar !== true) return '';
    return '/api/v1/persons/' + this.linkedPersonId +
      '/avatar?v=' + String(this.avatarRevision);
  }

  private canDeleteStory(): boolean {
    if (this.canDelete()) return true;
    return this.selectedStory !== null &&
      this.selectedStory!.authorUserId === this.currentUserId;
  }

  private albumFilterOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部人物' }];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        options.push({ value: person.fullName });
      });
    }
    return options;
  }

  private drawTree(): void {
    const layout = this.layout;
    if (layout === null) return;
    const ctx = this.canvasCtx;
    ctx.clearRect(0, 0, layout.width, layout.height);
    ctx.lineWidth = 2;
    layout.lines.forEach((line) => {
      ctx.strokeStyle = line.color;
      ctx.beginPath();
      ctx.moveTo(line.x1, line.y1);
      ctx.lineTo(line.x2, line.y2);
      ctx.stroke();
    });
    layout.dots.forEach((dot) => {
      ctx.beginPath();
      ctx.fillStyle = '#FFFEFA';
      ctx.strokeStyle = '#A68B62';
      ctx.lineWidth = 1.2;
      ctx.arc(dot.x, dot.y, 3.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    });
  }

  @Builder
  private LoginView() {
    Stack() {
      Image($r('app.media.hero_ink'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.55)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#B8FFFFFF')
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('家族族谱')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontFamily('serif')
              .fontColor('#1C2A32')
            Text('寻根溯源 · 传承家风')
              .fontSize(13)
              .fontColor('#6C7B82')
          }
          .margin({ top: 54, bottom: 24 })

          Column({ space: 14 }) {
            Text('进入家族')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text('使用家庭账户登录，查看当前家族的族谱与档案')
              .fontSize(12)
              .fontColor('#6C7B82')
              .width('100%')

            TextInput({ placeholder: '登录名', text: this.loginName })
              .height(50)
              .backgroundColor('#F7F9FA')
              .borderRadius(10)
              .fontSize(15)
              .onChange((value: string) => {
                this.loginName = value;
              })
            TextInput({ placeholder: '密码', text: this.password })
              .height(50)
              .type(InputType.Password)
              .backgroundColor('#F7F9FA')
              .borderRadius(10)
              .fontSize(15)
              .onChange((value: string) => {
                this.password = value;
              })
            TextInput({ placeholder: '服务器地址', text: this.serverDraft })
              .height(50)
              .backgroundColor('#F7F9FA')
              .borderRadius(10)
              .fontSize(13)
              .onChange((value: string) => {
                this.serverDraft = value;
              })
            Row({ space: 8 }) {
              Button('线上服务器')
                .layoutWeight(1)
                .height(34)
                .fontSize(11)
                .backgroundColor(this.serverMode === 0 ? '#EAF0FF' : '#F2F5F7')
                .fontColor(this.serverMode === 0 ? '#4E7DF4' : '#6C7B82')
                .onClick(() => {
                  this.serverMode = 0;
                  this.serverDraft = DEFAULT_SERVER;
                })
              Button('家庭局域网')
                .layoutWeight(1)
                .height(34)
                .fontSize(11)
                .backgroundColor(this.serverMode === 1 ? '#EAF0FF' : '#F2F5F7')
                .fontColor(this.serverMode === 1 ? '#4E7DF4' : '#6C7B82')
                .onClick(() => {
                  this.serverMode = 1;
                  this.serverDraft = LAN_SERVER;
                })
            }
            .width('100%')
            Text('线上域名目前只有 IPv6；提示找不到主机时，请切到“家庭局域网”')
              .fontSize(10)
              .fontColor('#89969C')
              .width('100%')
            if (this.error.length > 0) {
              Text(this.error)
                .fontSize(12)
                .fontColor('#B4423D')
                .width('100%')
            }
            Button(this.busy ? '正在进入...' : '进入家族')
              .width('100%')
              .height(50)
              .backgroundColor('#4E7DF4')
              .fontColor(Color.White)
              .fontSize(15)
              .borderRadius(10)
              .enabled(!this.busy)
              .onClick(() => {
                this.doLogin();
              })
            Row({ space: 14 }) {
              Text('注册账号')
                .fontSize(11)
                .fontColor('#4E7DF4')
                .onClick(() => {
                  this.authError = '';
                  this.authPage = 'register';
                })
              Text('手机验证码登录')
                .fontSize(11)
                .fontColor('#4E7DF4')
                .onClick(() => {
                  this.authError = '';
                  this.authPage = 'phone';
                })
              Text('找回密码')
                .fontSize(11)
                .fontColor('#4E7DF4')
                .onClick(() => {
                  this.authError = '';
                  this.authPage = 'reset';
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            Text('演示账号：linglei / Demo#2026')
              .fontSize(11)
              .fontColor('#89969C')
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(24)
          .backgroundColor('#FBFCFD')
          .borderRadius(18)
          .shadow({ radius: 20, color: '#14202A1A', offsetY: 8 })
        }
        .width('100%')
        .padding({ left: 22, right: 22, bottom: 28 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private AuthBackTitle(title: string, subtitle: string) {
    Row() {
      Button('‹')
        .width(38)
        .height(38)
        .backgroundColor('#FFFFFF')
        .fontColor('#1C2A32')
        .fontSize(22)
        .borderRadius(19)
        .onClick(() => {
          this.authError = '';
          this.authPage = 'login';
        })
      Column({ space: 2 }) {
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
        Text(subtitle)
          .fontSize(10)
          .fontColor('#89969C')
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 8 })
  }

  @Builder
  private RegisterView() {
    Stack() {
      Image($r('app.media.hero_ink'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.5)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#C8FFFFFF')
      Column() {
        this.AuthBackTitle('注册账号', '创建账号，或使用邀请码加入已有家族')
        Scroll() {
          Column({ space: 10 }) {
            TextInput({ placeholder: '服务器地址', text: this.serverDraft })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(12)
              .onChange((value: string) => {
                this.serverDraft = value;
              })
            TextInput({ placeholder: '登录名（英文或数字）', text: this.regLoginName })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(13)
              .onChange((value: string) => {
                this.regLoginName = value;
              })
            TextInput({ placeholder: '显示名，例如：凌磊', text: this.regDisplayName })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(13)
              .onChange((value: string) => {
                this.regDisplayName = value;
              })
            TextInput({ placeholder: '密码（至少 8 位）', text: this.regPassword })
              .height(44)
              .type(InputType.Password)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(13)
              .onChange((value: string) => {
                this.regPassword = value;
              })
            TextInput({ placeholder: '确认密码', text: this.regConfirm })
              .height(44)
              .type(InputType.Password)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(13)
              .onChange((value: string) => {
                this.regConfirm = value;
              })
            TextInput({ placeholder: '手机号（可选，+8613800000000）', text: this.regPhone })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(12)
              .onChange((value: string) => {
                this.regPhone = value;
              })
            TextInput({ placeholder: '邀请码（可选）', text: this.regInviteCode })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(12)
              .onChange((value: string) => {
                this.regInviteCode = value.toUpperCase();
              })
            TextInput({ placeholder: '新家族名称（无邀请码时可选）', text: this.regFamilyName })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(12)
              .onChange((value: string) => {
                this.regFamilyName = value;
              })
            TextInput({ placeholder: '姓氏（无邀请码时可选）', text: this.regSurname })
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(12)
              .onChange((value: string) => {
                this.regSurname = value;
              })
            Row({ space: 7 }) {
              Checkbox({ name: 'terms' })
                .select(this.regAcceptTerms)
                .selectedColor('#4E7DF4')
                .onChange((value: boolean) => {
                  this.regAcceptTerms = value;
                })
              Text('我已阅读并同意《用户协议》和《隐私政策》')
                .fontSize(10)
                .fontColor('#6C7B82')
                .layoutWeight(1)
            }
            .width('100%')
            if (this.authError.length > 0) {
              Text(this.authError)
                .fontSize(11)
                .fontColor('#B4423D')
                .width('100%')
            }
            Button(this.authBusy ? '正在注册...' : '注册并进入家族')
              .width('100%')
              .height(46)
              .backgroundColor('#4E7DF4')
              .fontColor(Color.White)
              .enabled(!this.authBusy)
              .onClick(() => {
                this.doRegister();
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#F2FFFFFF')
          .borderRadius(16)
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private PhoneLoginView() {
    Stack() {
      Image($r('app.media.hero_ink'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.5)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#C8FFFFFF')
      Column() {
        this.AuthBackTitle('手机验证码登录', '使用已绑定手机号登录')
        Column({ space: 10 }) {
          TextInput({ placeholder: '服务器地址', text: this.serverDraft })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(9)
            .fontSize(12)
            .onChange((value: string) => {
              this.serverDraft = value;
            })
          TextInput({ placeholder: '手机号，例如 +8613800000000', text: this.phoneLoginPhone })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(9)
            .fontSize(13)
            .onChange((value: string) => {
              this.phoneLoginPhone = value;
            })
          Row({ space: 8 }) {
            TextInput({ placeholder: '6 位验证码', text: this.phoneLoginCode })
              .layoutWeight(1)
              .height(44)
              .backgroundColor('#F7F9FA')
              .borderRadius(9)
              .fontSize(13)
              .onChange((value: string) => {
                this.phoneLoginCode = value;
              })
            Button(this.phoneCodeSent ? '重新发送' : '发送验证码')
              .height(44)
              .fontSize(10)
              .backgroundColor('#EAF0FF')
              .fontColor('#4E7DF4')
              .onClick(() => {
                this.sendPhoneLoginCode();
              })
          }
          .width('100%')
          if (this.authError.length > 0) {
            Text(this.authError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
          Button(this.authBusy ? '正在登录...' : '登录')
            .width('100%')
            .height(46)
            .backgroundColor('#4E7DF4')
            .fontColor(Color.White)
            .enabled(!this.authBusy)
            .onClick(() => {
              this.doPhoneLogin();
            })
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#F2FFFFFF')
        .borderRadius(16)
        .width('90%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ResetPasswordView() {
    Stack() {
      Image($r('app.media.hero_ink'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.5)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#C8FFFFFF')
      Column() {
        this.AuthBackTitle('找回密码', '使用登录名和一次性找回码重置密码')
        Column({ space: 10 }) {
          TextInput({ placeholder: '服务器地址', text: this.serverDraft })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(9)
            .fontSize(12)
            .onChange((value: string) => {
              this.serverDraft = value;
            })
          TextInput({ placeholder: '登录名', text: this.resetLoginName })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(9)
            .fontSize(13)
            .onChange((value: string) => {
              this.resetLoginName = value;
            })
          TextInput({ placeholder: '找回码', text: this.resetRecoveryCode })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(9)
            .fontSize(13)
            .onChange((value: string) => {
              this.resetRecoveryCode = value;
            })
          TextInput({ placeholder: '新密码（至少 8 位）', text: this.resetNewPassword })
            .height(44)
            .type(InputType.Password)
            .backgroundColor('#F7F9FA')
            .borderRadius(9)
            .fontSize(13)
            .onChange((value: string) => {
              this.resetNewPassword = value;
            })
          Text('找回码可在登录后“账号与家庭—账号安全”中生成，只能使用一次。')
            .fontSize(10)
            .lineHeight(16)
            .fontColor('#89969C')
            .width('100%')
          if (this.authError.length > 0) {
            Text(this.authError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
          Button(this.authBusy ? '正在重置...' : '重置密码')
            .width('100%')
            .height(46)
            .backgroundColor('#4E7DF4')
            .fontColor(Color.White)
            .enabled(!this.authBusy)
            .onClick(() => {
              this.doResetPassword();
            })
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#F2FFFFFF')
        .borderRadius(16)
        .width('90%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private LoadingView() {
    Column({ space: 14 }) {
      Text('族')
        .width(64)
        .height(64)
        .textAlign(TextAlign.Center)
        .fontSize(30)
        .fontColor(Color.White)
        .backgroundColor('#B4423D')
        .borderRadius(15)
      Text('正在恢复登录...')
        .fontSize(13)
        .fontColor('#6C7B82')
      LoadingProgress()
        .width(28)
        .height(28)
        .color('#4E7DF4')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F4F7F8')
  }

  @Builder
  private TabsView() {
    Column() {
      if (this.tab === 0) {
        this.HomeView()
      } else if (this.tab === 1) {
        this.TreeView()
      } else if (this.tab === 2) {
        this.MessagesTabView()
      } else {
        this.SettingsView()
      }
      this.BottomBar()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private BottomBar() {
    Row() {
      this.NavItem('首页', 0, '⌂', false)
      this.NavItem('族谱树', 1, '⑂', false)
      Button('+')
        .width(52)
        .height(52)
        .fontSize(28)
        .fontColor(Color.White)
        .backgroundColor('#4E7DF4')
        .borderRadius(26)
        .shadow({ radius: 12, color: '#4E7DF440', offsetY: 5 })
        .margin({ left: 2, right: 2 })
        .onClick(() => {
          this.openAdd();
        })
      this.NavItem('消息', 2, '✉', this.unreadCount > 0)
      this.NavItem('我的', 3, '◉', false)
    }
    .width('100%')
    .height(66)
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 0.8 }, color: '#EDF1F2' })
    .shadow({ radius: 18, color: '#0A20323B', offsetY: -5 })
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private NavItem(label: string, index: number, icon: string, badge: boolean) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Text(icon)
          .fontSize(19)
          .fontColor(this.tab === index ? '#4E7DF4' : '#849198')
        if (badge) {
          Column()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor('#B4423D')
            .border({ width: 1.2, color: Color.White })
            .margin({ top: 1, right: 1 })
        }
      }
      Text(label)
        .fontSize(10)
        .fontColor(this.tab === index ? '#4E7DF4' : '#849198')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
      if (index === 2) {
        this.loadInbox();
      } else if (index === 0) {
        this.refreshUnread();
      }
    })
  }

  @Builder
  private MessagesTabView() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('消息')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text(this.unreadCount > 0
            ? String(this.unreadCount) + ' 条未读消息'
            : '家族通知与审核动态')
            .fontSize(11)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        if (this.unreadCount > 0) {
          Button('全部已读')
            .fontSize(11)
            .height(30)
            .backgroundColor('#EAF0FF')
            .fontColor('#4E7DF4')
            .onClick(() => {
              this.markAllNotificationsRead();
            })
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      if (this.inboxBusy && this.notifications.length === 0) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载消息...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.notifications.length === 0) {
        Column({ space: 8 }) {
          Text('暂无消息')
            .fontSize(15)
            .fontColor('#1C2A32')
          Text('审核结果和家族动态会显示在这里')
            .fontSize(11)
            .fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.notifications, (item: ApiNotification) => {
            ListItem() {
              Row({ space: 10 }) {
                Column()
                  .width(8)
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor(item.isRead ? '#DDE5E8' : '#B4423D')
                Column({ space: 3 }) {
                  Text(item.title)
                    .fontSize(13)
                    .fontWeight(item.isRead ? FontWeight.Normal : FontWeight.Medium)
                    .fontColor('#1C2A32')
                  Text(item.body)
                    .fontSize(11)
                    .fontColor('#6C7B82')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.createdAt !== undefined
                    ? item.createdAt!.substring(0, 10) : '')
                    .fontSize(9)
                    .fontColor('#89969C')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(13)
              .backgroundColor(item.isRead ? '#F7F9FA' : Color.White)
              .borderRadius(12)
              .onClick(() => {
                this.markNotificationRead(item);
              })
            }
          }, (item: ApiNotification) => String(item.id))
        }
        .layoutWeight(1)
        .padding({ left: 18, right: 18 })
        .scrollBar(BarState.Off)
      }

      if (this.canDelete()) {
        Button('审核与家族合并')
          .width('92%')
          .height(42)
          .fontSize(12)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .borderRadius(10)
          .margin({ left: 18, right: 18, bottom: 8 })
          .onClick(() => {
            this.openInbox();
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7F8')
  }

  @Builder
  private HomeView() {
    Scroll() {
      Stack({ alignContent: Alignment.TopStart }) {
        Image($r('app.media.hero_ink'))
          .width('100%')
          .height(390)
          .objectFit(ImageFit.Cover)
          .opacity(0.9)
        Column()
          .width('100%')
          .height(390)
          .linearGradient({
            angle: 180,
            colors: [
              ['#38FFFFFF', 0.0],
              ['#00F4F7F8', 0.44],
              ['#85F4F7F8', 0.72],
              ['#FFF4F7F8', 1.0]
            ]
          })
        Column({ space: 12 }) {
          this.HomeTopBar()
          this.FamilyIdentity()
          Row() {
            this.SummaryCell('族', '#4E7DF4', '#EAF0FF',
              String(this.memberCount), '家族成员', -6)
            this.SummaryDivider()
            this.SummaryCell('支', '#3DA77C', '#E8F6EF',
              String(this.branchCount), '家支', 1)
            this.SummaryDivider()
            this.SummaryCell('世', '#E4A636', '#FFF4DF',
              this.myGeneration.length > 0 ? this.myGeneration : '—', '我的世代', 3)
          }
          .width('100%')
          .padding({ top: 15, bottom: 15 })
          .backgroundColor(Color.White)
          .borderRadius(15)
          .border({ width: 1, color: '#FFFFFFCC' })
          .shadow({ radius: 24, color: '#0A20323B', offsetY: 8 })

        Column() {
          Row() {
            this.QuickCell('族谱树', '查看家族关系', '树', '#4E7DF4', 1)
            this.QuickDivider()
            this.QuickCell('成员查询', '查找家族成员', '人', '#3DA77C', -6)
            this.QuickDivider()
            this.QuickCell('新增成员', '录入正式档案', '录', '#E4A636', -1)
          }
          .width('100%')
          Divider()
            .strokeWidth(1)
            .color('#ECF0F1')
            .margin({ left: 14, right: 14 })
          Row() {
            this.QuickCell(
              '消息中心',
              this.unreadCount > 0 ? String(this.unreadCount) + ' 条未读' : '审核与通知',
              '信',
              '#8A6BE8',
              -5
            )
            this.QuickDivider()
            this.QuickCell('家族相册', '珍贵家族影像', '影', '#35ABC0', -3)
            this.QuickDivider()
            this.QuickCell('家族故事', '传承家族文化', '故', '#E46A72', -4)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
        .backgroundColor(Color.White)
        .borderRadius(15)
        .border({ width: 1, color: '#FFFFFFCC' })
        .shadow({ radius: 24, color: '#0A20323B', offsetY: 8 })

        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Column()
              .width(3)
              .height(15)
              .backgroundColor('#4E7DF4')
              .borderRadius(3)
            Text('最近的生日与祭日')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
            Blank()
            Text('未来 60 天')
              .fontSize(11)
              .fontColor('#89969C')
          }
          if (this.anniversaries.length === 0) {
            Text('未来 60 天没有已记录的生日或祭日')
              .fontSize(12)
              .fontColor('#89969C')
              .padding({ top: 6, bottom: 6 })
          } else {
            ForEach(this.anniversaries.slice(0, 2), (item: ApiAnniversary) => {
              Row({ space: 8 }) {
                Text(item.kind === 'birthday' ? '生' : '祭')
                  .width(30)
                  .height(30)
                  .textAlign(TextAlign.Center)
                  .fontSize(12)
                  .fontColor(item.kind === 'birthday' ? '#B4423D' : '#6C7B82')
                  .backgroundColor(item.kind === 'birthday' ? '#FBEEEA' : '#EDF2F5')
                  .borderRadius(9)
                Column({ space: 2 }) {
                  Text(item.fullName + '  ' + item.solarText)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1C2A32')
                  Text(item.lunarText)
                    .fontSize(10)
                    .fontColor('#89969C')
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text(item.daysUntil + ' 天后')
                  .fontSize(11)
                  .fontColor('#4E7DF4')
              }
              .width('100%')
            }, (item: ApiAnniversary) => item.personId + item.date)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(15)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Column()
              .width(3)
              .height(15)
              .backgroundColor('#4E7DF4')
              .borderRadius(3)
            Text('最新动态')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
            Blank()
            Text('共 ' + this.activities.length + ' 条')
              .fontSize(11)
              .fontColor('#89969C')
          }
          if (this.activities.length === 0) {
            Text('暂无最新动态')
              .fontSize(12)
              .fontColor('#89969C')
          } else {
            ForEach(this.activities.slice(0, 5), (item: ApiActivity) => {
              Row({ space: 10 }) {
                Text('◉')
                  .fontSize(14)
                  .fontColor('#4E7DF4')
                Column({ space: 2 }) {
                  Text(item.actorName + '  ' + item.summary)
                    .fontSize(12)
                    .fontColor('#1C2A32')
                  Text(item.createdAt.substring(0, 10))
                    .fontSize(10)
                    .fontColor('#89969C')
                }
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
            }, (item: ApiActivity) => String(item.id))
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(15)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 50, bottom: 18 })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  private HomeTopBar() {
    Row({ space: 10 }) {
      Stack() {
        if (this.linkedPersonAvatar().length > 0) {
          AuthImage({
            path: this.linkedPersonAvatar(),
            radius: 22
          })
        } else {
          Text(this.displayName.length > 0 ? this.displayName.substring(0, 1) : '族')
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B4423D')
            .backgroundColor('#FBEEEA')
            .borderRadius(22)
            .border({ width: 2, color: Color.White })
        }
      }
      .width(44)
      .height(44)
      .shadow({ radius: 8, color: '#14202A1A', offsetY: 2 })

      Column({ space: 3 }) {
        Text(this.displayName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C2A32')
        Text((this.role === 'owner' ? '族长' : this.role === 'admin' ? '管理员' : '普通成员') + '  ›')
          .fontSize(11)
          .fontColor('#54646D')
      }
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.tab = 3;
      })
      Blank()
      Stack({ alignContent: Alignment.TopEnd }) {
        Button('✉')
          .width(40)
          .height(40)
          .fontSize(18)
          .fontColor('#1C2A32')
          .backgroundColor('#C7FFFFFF')
          .border({ width: 1, color: '#FFFFFFB3' })
          .borderRadius(20)
          .onClick(() => {
            this.tab = 2;
            this.loadInbox();
          })
        if (this.unreadCount > 0) {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor('#B4423D')
            .border({ width: 1.2, color: Color.White })
            .margin({ top: 5, right: 5 })
        }
      }
    }
    .width('100%')
  }

  @Builder
  private FamilyIdentity() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.familyName.length > 0 ? this.familyName : '当前家族')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontFamily('serif')
          .fontColor('#1C2A32')
          .letterSpacing(2.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Column({ space: 0 }) {
          Text('族')
            .fontSize(11)
            .fontColor('#FFF6E8')
          Text('谱')
            .fontSize(11)
            .fontColor('#FFF6E8')
        }
        .width(26)
        .height(43)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#B4423D')
        .borderRadius(4)
        .border({ width: 1, color: '#F5DFD5' })
        .rotate({ angle: -2 })
        .shadow({ radius: 8, color: '#2EB4423D', offsetY: 3 })
      }
      .width('100%')
      Row({ space: 9 }) {
        Column()
          .width(22)
          .height(1)
          .backgroundColor('#596A73')
        Text(this.familyMotto.length > 0 ? this.familyMotto : '敦亲睦族 · 薪火相传')
          .fontSize(14)
          .fontColor('#54646D')
          .letterSpacing(2.2)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.tab = 3;
    })
  }

  @Builder
  private SummaryCell(icon: string, color: string, softColor: string,
    value: string, label: string, action: number) {
    Column({ space: 4 }) {
      Text(icon)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .backgroundColor(softColor)
        .borderRadius(9)
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C2A32')
      Text(label)
        .fontSize(10)
        .fontColor('#89969C')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.handleQuickAction(action);
    })
  }

  @Builder
  private SummaryDivider() {
    Column()
      .width(1)
      .height(42)
      .backgroundColor('#ECF0F1')
  }

  @Builder
  private QuickCell(label: string, subtitle: string, icon: string,
    color: string, action: number) {
    Column({ space: 8 }) {
      Text(icon)
        .width(50)
        .height(50)
        .textAlign(TextAlign.Center)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(color)
        .borderRadius(11)
        .shadow({ radius: 13, color: color + '3D', offsetY: 6 })
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C2A32')
        .maxLines(1)
      Text(subtitle)
        .fontSize(9)
        .fontColor('#89969C')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: 15, bottom: 15, left: 2, right: 2 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.handleQuickAction(action);
    })
  }

  @Builder
  private QuickDivider() {
    Column()
      .width(1)
      .height(58)
      .backgroundColor('#ECF0F1')
  }

  private handleQuickAction(action: number): void {
    if (action === -1) {
      this.openAdd();
    } else if (action === -2) {
      this.refreshAll();
    } else if (action === -3) {
      this.openAlbum();
    } else if (action === -4) {
      this.openStories();
    } else if (action === -5) {
      this.openInbox();
    } else if (action === -6) {
      this.openMembers();
    } else {
      this.tab = action;
    }
  }

  @Builder
  private StatCell(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C2A32')
      Text(label)
        .fontSize(10)
        .fontColor('#89969C')
    }
    .layoutWeight(1)
  }

  @Builder
  private QuickTile(title: string, subtitle: string, color: string, action: number) {
    Row({ space: 10 }) {
      Text(title.substring(0, 1))
        .width(42)
        .height(42)
        .textAlign(TextAlign.Center)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(color)
        .borderRadius(12)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C2A32')
        Text(subtitle)
          .fontSize(9)
          .fontColor('#89969C')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .padding(10)
    .onClick(() => {
      if (action === -1) {
        this.openAdd();
      } else if (action === -2) {
        this.refreshAll();
      } else if (action === -3) {
        this.openAlbum();
      } else if (action === -4) {
        this.openStories();
      } else if (action === -5) {
        this.openInbox();
      } else if (action === -6) {
        this.openMembers();
      } else {
        this.tab = action;
      }
    })
  }

  @Builder
  private TreeView() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('族谱树')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontFamily('serif')
            .fontColor('#1C2A32')
          Text(this.familyName + ' · 共 ' + this.memberCount + ' 人')
            .fontSize(11)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Button('↻')
          .width(36)
          .height(36)
          .fontSize(17)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .border({ width: 1, color: '#FFFFFFCC' })
          .borderRadius(18)
          .shadow({ radius: 12, color: '#0A20323B', offsetY: 4 })
          .onClick(() => {
            this.refreshAll();
          })
        Button('＋')
          .width(36)
          .height(36)
          .fontSize(20)
          .margin({ left: 8 })
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .borderRadius(18)
          .shadow({ radius: 12, color: '#4E7DF440', offsetY: 4 })
          .onClick(() => {
            this.openAdd();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      Scroll() {
        Row({ space: 7 }) {
          Text('全部')
            .fontSize(10)
            .fontColor(this.treeGenerationFilter === 0 ? '#4E7DF4' : '#89969C')
            .backgroundColor(this.treeGenerationFilter === 0 ? '#EAF0FF' : '#FFFFFF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(13)
            .onClick(() => {
              this.treeGenerationFilter = 0;
            })
          ForEach(this.treeGenerations(), (generation: number) => {
            Text('第 ' + String(generation) + ' 世')
              .fontSize(10)
              .fontColor(this.treeGenerationFilter === generation ? '#4E7DF4' : '#89969C')
              .backgroundColor(this.treeGenerationFilter === generation
                ? '#EAF0FF' : '#FFFFFF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(13)
              .onClick(() => {
                this.treeGenerationFilter = generation;
              })
          }, (generation: number) => String(generation))
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ bottom: 7 })

      if (this.layout === null) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载族谱...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.BottomEnd }) {
          Stack() {
            Image($r('app.media.tree_paper'))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
            Canvas(this.canvasCtx)
              .width(this.layout!.width)
              .height(this.layout!.height)
              .onReady(() => {
                this.drawTree();
              })
            ForEach(this.layout!.boxes, (box: PersonBox) => {
              this.PersonCard(box)
            }, (box: PersonBox) => box.person.id)
          }
          .width(this.layout!.width)
          .height(this.layout!.height)
          .scale({ x: this.treeScale, y: this.treeScale })
          .translate({ x: this.treeOffsetX, y: this.treeOffsetY })
          .gesture(
            GestureGroup(
              GestureMode.Parallel,
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.treePanBaseX = this.treeOffsetX;
                  this.treePanBaseY = this.treeOffsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.treeOffsetX = this.treePanBaseX + event.offsetX;
                  this.treeOffsetY = this.treePanBaseY + event.offsetY;
                }),
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.treePinchBase = this.treeScale;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.treeScale = Math.max(
                    0.16,
                    Math.min(2, this.treePinchBase * event.scale)
                  );
                })
            )
          )

          Column({ space: 8 }) {
            Button('＋')
              .width(36)
              .height(36)
              .fontSize(18)
              .backgroundColor('#F2FFFFFF')
              .fontColor('#1C2A32')
              .borderRadius(18)
              .onClick(() => {
                this.zoomTree(1.22);
              })
            Button('－')
              .width(36)
              .height(36)
              .fontSize(18)
              .backgroundColor('#F2FFFFFF')
              .fontColor('#1C2A32')
              .borderRadius(18)
              .onClick(() => {
                this.zoomTree(1 / 1.22);
              })
            Button('⤢')
              .width(36)
              .height(36)
              .fontSize(15)
              .backgroundColor('#F2FFFFFF')
              .fontColor('#1C2A32')
              .borderRadius(18)
              .onClick(() => {
                this.resetTreeFit();
              })
          }
          .margin({ right: 12, bottom: 14 })
        }
        .layoutWeight(1)
        .width('100%')
        .clip(true)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.treeViewportWidth = Number(newArea.width);
          this.treeViewportHeight = Number(newArea.height);
          if (!this.treeFitted) {
            this.resetTreeFit();
          }
        })
      }
      if (this.selectedTreePerson() !== null) {
        Row({ space: 10 }) {
          this.TreePortrait(this.selectedTreePerson()!, 46, 52, 9)
          Column({ space: 3 }) {
            Text(this.selectedTreePerson()!.fullName)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
            Text(this.selectedTreePerson()!.generationLabel + ' · ' +
              this.personLifespan(this.selectedTreePerson()!))
              .fontSize(10)
              .fontColor('#89969C')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('查看档案')
            .fontSize(11)
            .height(32)
            .backgroundColor('#4E7DF4')
            .fontColor(Color.White)
            .onClick(() => {
              this.openPerson(this.selectedTreePerson()!.id);
            })
          Text('×')
            .fontSize(18)
            .fontColor('#89969C')
            .padding({ left: 4, right: 4 })
            .onClick(() => {
              this.treeSelectedId = '';
            })
        }
        .width('92%')
        .padding(10)
        .backgroundColor(Color.White)
        .borderRadius(14)
        .border({ width: 1, color: '#FFFFFFCC' })
        .shadow({ radius: 18, color: '#0A20323B', offsetY: 6 })
      }
      Text('双指缩放 · 单指拖动 · 点击人物选中')
        .fontSize(10)
        .fontColor('#89969C')
        .padding({ top: 6, bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private PersonCard(box: PersonBox) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (box.compact) {
        Column({ space: 3 }) {
          this.TreePortrait(box.person, 50, 55, 8)
          Text(box.person.fullName)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C2A32')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('(' + this.personLifespan(box.person) + ')')
            .fontSize(8)
            .fontColor('#89969C')
            .maxLines(1)
          Blank()
          Text(box.person.generationLabel)
            .fontSize(8)
            .fontColor(box.person.id === this.treeSelectedId ? '#4E7DF4' : '#89969C')
            .backgroundColor(box.person.id === this.treeSelectedId
              ? '#EAF0FF' : '#F4F5F4')
            .padding({ left: 4, right: 4, top: 2, bottom: 2 })
            .borderRadius(4)
        }
        .width('100%')
        .height('100%')
        .padding(5)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Row({ space: 7 }) {
          this.TreePortrait(box.person, 42, 60, 9)
          Column({ space: 3 }) {
            Text(box.person.fullName)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C2A32')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('(' + this.personLifespan(box.person) + ')')
              .fontSize(9)
              .fontColor('#89969C')
              .maxLines(1)
            Text(box.person.generationLabel)
              .fontSize(8)
              .fontColor('#89969C')
              .backgroundColor('#F3F5F5')
              .padding({ left: 5, right: 5, top: 2, bottom: 2 })
              .borderRadius(4)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .padding(7)
      }
      if (box.person.id === this.linkedPersonId) {
        Text('我')
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#4E7DF4')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
          .margin({ left: 2, top: -7 })
      }
    }
    .width(box.width)
    .height(box.height)
    .backgroundColor('#FFFEFA')
    .borderRadius(box.compact ? 12 : 14)
    .border({
      width: box.person.id === this.treeSelectedId ? 1.5 : 0.8,
      color: box.person.id === this.treeSelectedId ? '#4E7DF4' : '#E7ECEC'
    })
    .shadow({
      radius: box.person.id === this.treeSelectedId ? 16 : 8,
      color: box.person.id === this.treeSelectedId ? '#4E7DF433' : '#39545C12',
      offsetY: 4
    })
    .opacity(this.treeGenerationFilter === 0 ||
      box.person.generationNo === this.treeGenerationFilter ? 1 : 0.28)
    .position({ x: box.x, y: box.y })
    .onClick(() => {
      this.treeSelectedId = box.person.id;
    })
  }

  @Builder
  private TreePortrait(person: ApiPerson, width: number, height: number, radius: number) {
    Stack() {
      if (person.hasAvatar === true) {
        AuthImage({
          path: '/api/v1/persons/' + person.id + '/avatar?v=' +
            String(this.avatarRevision),
          radius: radius
        })
      } else {
        Text(person.fullName.substring(0, 1))
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
          .fontSize(width > 45 ? 18 : 15)
          .fontWeight(FontWeight.Bold)
          .fontColor(person.gender === 'female' ? '#B45D5A' : '#3F6E9E')
          .backgroundColor(person.gender === 'female' ? '#FBEEEA' : '#EAF0F5')
      }
    }
    .width(width)
    .height(height)
    .borderRadius(radius)
    .clip(true)
  }

  private personLifespan(person: ApiPerson): string {
    const birth = person.birth !== undefined ? person.birth!.year : undefined;
    const death = person.death !== undefined ? person.death!.year : undefined;
    if (birth !== undefined && death !== undefined) {
      return String(birth) + '–' + String(death);
    }
    if (birth !== undefined) {
      return String(birth) + '–';
    }
    return '—';
  }

  private personZodiac(person: ApiPerson): string {
    const year = person.birth !== undefined ? person.birth!.year : undefined;
    if (year === undefined || year < 1) return '';
    const animals: string[] = [
      '鼠', '牛', '虎', '兔', '龙', '蛇',
      '马', '羊', '猴', '鸡', '狗', '猪'
    ];
    return '属' + animals[(year - 4) % 12];
  }

  private selectedTreePerson(): ApiPerson | null {
    if (this.tree === null || this.treeSelectedId.length === 0) return null;
    const person = this.tree.persons.find(
      (item: ApiPerson) => item.id === this.treeSelectedId
    );
    return person === undefined ? null : person;
  }

  private treeGenerations(): number[] {
    const values: number[] = [];
    if (this.tree !== null) {
      this.tree.persons.forEach((person: ApiPerson) => {
        if (values.indexOf(person.generationNo) < 0) {
          values.push(person.generationNo);
        }
      });
    }
    values.sort((a: number, b: number) => a - b);
    return values;
  }

  private resetTreeFit(): void {
    const layout = this.layout;
    if (layout === null || layout.width <= 0 ||
      this.treeViewportWidth <= 0 || this.treeViewportHeight <= 0) {
      return;
    }
    const scale = Math.min(
      (this.treeViewportWidth - 24) / layout.width,
      (this.treeViewportHeight - 24) / layout.height,
      1
    );
    this.treeScale = Math.max(0.16, scale);
    this.treeOffsetX = (this.treeViewportWidth - layout.width * this.treeScale) / 2;
    this.treeOffsetY = Math.max(
      12,
      (this.treeViewportHeight - layout.height * this.treeScale) / 2
    );
    this.treeFitted = true;
  }

  private zoomTree(factor: number): void {
    const next = Math.max(0.16, Math.min(2, this.treeScale * factor));
    const centerX = this.treeViewportWidth / 2;
    const centerY = this.treeViewportHeight / 2;
    const ratio = next / this.treeScale;
    this.treeOffsetX = centerX - (centerX - this.treeOffsetX) * ratio;
    this.treeOffsetY = centerY - (centerY - this.treeOffsetY) * ratio;
    this.treeScale = next;
  }

  @Builder
  private MembersView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'tabs';
            this.tab = 0;
          })
        Column({ space: 4 }) {
          Text('成员查询')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text('共 ' + (this.tree === null ? 0 : this.tree.persons.length) + ' 人')
            .fontSize(11)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      TextInput({ placeholder: '搜索姓名、世代、籍贯、职业', text: this.query })
        .height(44)
        .margin({ left: 16, right: 16, bottom: 8 })
        .backgroundColor(Color.White)
        .borderRadius(10)
        .fontSize(13)
        .onChange((value: string) => {
          this.query = value;
        })

      List({ space: 8 }) {
        ForEach(this.filteredPersons(), (person: ApiPerson) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(person.gender === 'female' ? '女' : '男')
                .width(34)
                .height(34)
                .textAlign(TextAlign.Center)
                .fontSize(11)
                .fontColor(person.gender === 'female' ? '#B45D5A' : '#4E7DF4')
                .backgroundColor(person.gender === 'female' ? '#FBEEEA' : '#EAF0FF')
                .borderRadius(10)
              Column({ space: 2 }) {
                Text(person.fullName)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1C2A32')
                Text(person.generationLabel + ' · ' +
                  (person.lifeStatus === 'living' ? '在世' : '已故'))
                  .fontSize(10)
                  .fontColor('#89969C')
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Text('›')
                .fontSize(18)
                .fontColor('#C1CBCF')
            }
            .width('100%')
            .padding(13)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .onClick(() => {
              this.openPerson(person.id);
            })
          }
        }, (person: ApiPerson) => person.id)
      }
      .layoutWeight(1)
      .padding({ left: 14, right: 14 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private SettingsView() {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Stack() {
            if (this.linkedPersonAvatar().length > 0) {
              AuthImage({ path: this.linkedPersonAvatar(), radius: 32 })
            } else {
              Text(this.displayName.length > 0 ? this.displayName.substring(0, 1) : '族')
                .width(64)
                .height(64)
                .textAlign(TextAlign.Center)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#B4423D')
                .backgroundColor('#FBEEEA')
                .borderRadius(32)
            }
          }
          .width(64)
          .height(64)
          Column({ space: 5 }) {
            Text(this.displayName)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
            Text(this.familyName + ' · ' +
              (this.role === 'owner' ? '族长' : this.role === 'admin' ? '管理员' : '普通成员'))
              .fontSize(11)
              .fontColor('#89969C')
            Text(this.myGeneration.length > 0 ? this.myGeneration : '未绑定族谱人物')
              .fontSize(10)
              .fontColor('#4E7DF4')
              .backgroundColor('#EAF0FF')
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .borderRadius(6)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(15)
        .border({ width: 1, color: '#FFFFFFCC' })
        .shadow({ radius: 24, color: '#0A20323B', offsetY: 8 })

        Row({ space: 8 }) {
          Column()
            .width(3)
            .height(15)
            .backgroundColor('#4E7DF4')
            .borderRadius(3)
          Text('账号与家族')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
        }
        .width('100%')
        .padding({ left: 2, top: 4 })

        Column({ space: 10 }) {
          this.SettingsRow('服务器', this.savedServer)
          this.SettingsRow('登录账号', this.loginName)
          this.SettingsRow('我的世代', this.myGeneration.length > 0 ? this.myGeneration : '未绑定')
          this.SettingsRow('家族人数', String(this.memberCount))
          Row() {
            Text('账号与家庭')
              .fontSize(13)
              .fontColor('#1C2A32')
            Blank()
            Text('切换 / 邀请 / 密码 ›')
              .fontSize(11)
              .fontColor('#4E7DF4')
          }
          .width('100%')
          .padding({ top: 8, bottom: 4 })
          .onClick(() => {
            this.openFamilyCenter();
          })
          if (this.canDelete()) {
            Row() {
              Text('家族合并')
                .fontSize(13)
                .fontColor('#1C2A32')
              Blank()
              Text('查看合并申请 ›')
                .fontSize(11)
                .fontColor('#4E7DF4')
            }
            .width('100%')
            .padding({ top: 8, bottom: 4 })
            .onClick(() => {
              this.openMerges();
            })
          }
          if (this.role === 'owner') {
            Row() {
              Text('数据导入导出')
                .fontSize(13)
                .fontColor('#1C2A32')
              Blank()
              Text('导出 / 导入码 ›')
                .fontSize(11)
                .fontColor('#4E7DF4')
            }
            .width('100%')
            .padding({ top: 8, bottom: 4 })
            .onClick(() => {
              this.openData();
            })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(15)

        Column({ space: 8 }) {
          Text('鸿蒙版说明')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text('这是原生 ArkTS/ArkUI 版本，已接入族谱、相册、故事、消息、审核、合并与导入导出。')
            .fontSize(11)
            .lineHeight(18)
            .fontColor('#6C7B82')
          Text('界面配色、卡片和底部导航正在按 Flutter 版逐页对齐；当前为浅色主题。')
            .fontSize(11)
            .lineHeight(18)
            .fontColor('#6C7B82')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(15)

        Button('退出登录')
          .width('100%')
          .height(46)
          .backgroundColor('#FBEEEA')
          .fontColor('#B4423D')
          .borderRadius(10)
          .onClick(() => {
            this.logout();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 20 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  private SettingsRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#1C2A32')
      Blank()
      Text(value)
        .fontSize(11)
        .fontColor('#89969C')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 5, bottom: 5 })
  }

  @Builder
  private DetailView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.selected = null;
            this.page = 'tabs';
          })
        Text('人物档案')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
        Blank()
        if (this.canDelete()) {
          Button('删除')
            .fontSize(11)
            .height(32)
            .backgroundColor('#FBEEEA')
            .fontColor('#B4423D')
            .onClick(() => {
              this.confirmDelete();
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.detailBusy || this.selected === null) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载人物档案...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 13 }) {
              Row({ space: 16 }) {
                Stack({ alignContent: Alignment.BottomEnd }) {
                  if (this.selected!.hasAvatar === true) {
                    AuthImage({
                      path: '/api/v1/persons/' + this.selected!.id +
                        '/avatar?v=' + String(this.avatarRevision),
                      radius: 18
                    })
                  } else {
                    Text(this.selected!.fullName.substring(0, 1))
                      .width(92)
                      .height(112)
                      .textAlign(TextAlign.Center)
                      .fontSize(34)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#B4423D')
                      .backgroundColor('#FBEEEA')
                      .borderRadius(18)
                  }
                  if (this.canEditAvatar()) {
                    Text('＋')
                      .width(26)
                      .height(26)
                      .textAlign(TextAlign.Center)
                      .fontSize(15)
                      .fontColor('#54646D')
                      .backgroundColor(Color.White)
                      .borderRadius(13)
                      .border({ width: 1, color: '#ECF0F1' })
                      .margin({ right: -4, bottom: -4 })
                      .onClick(() => {
                        this.pickAvatar();
                      })
                  }
                }
                .width(92)
                .height(112)

                Column({ space: 7 }) {
                  Row({ space: 7 }) {
                    Text(this.selected!.fullName)
                      .fontSize(28)
                      .fontWeight(FontWeight.Bold)
                      .fontFamily('serif')
                      .fontColor('#1C2A32')
                      .letterSpacing(1)
                    Text(this.selected!.generationLabel)
                      .fontSize(9)
                      .fontColor('#4E7DF4')
                      .backgroundColor('#EAF0FF')
                      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                      .borderRadius(7)
                  }
                  .width('100%')
                  Text(this.selected!.occupation !== undefined &&
                    this.selected!.occupation!.length > 0
                    ? this.selected!.occupation! : '家族成员')
                    .fontSize(12)
                    .fontColor('#54646D')
                  Row({ space: 6 }) {
                    Text(this.selected!.lifeStatus === 'living' ? '在世' : '已故')
                      .fontSize(9)
                      .fontColor(this.selected!.lifeStatus === 'living'
                        ? '#2F8F67' : '#89969C')
                      .backgroundColor(this.selected!.lifeStatus === 'living'
                        ? '#E8F6EF' : '#EDF2F5')
                      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                      .borderRadius(6)
                    if (this.selected!.courtesyName !== undefined &&
                      this.selected!.courtesyName!.length > 0) {
                      Text('字 ' + this.selected!.courtesyName!)
                        .fontSize(9)
                        .fontColor('#B4423D')
                        .backgroundColor('#FBEEEA')
                        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                        .borderRadius(6)
                    }
                    if (this.selected!.alias !== undefined &&
                      this.selected!.alias!.length > 0) {
                      Text('号 ' + this.selected!.alias!)
                        .fontSize(9)
                        .fontColor('#B7791F')
                        .backgroundColor('#FFF4DF')
                        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                        .borderRadius(6)
                    }
                    if (this.personZodiac(this.selected!).length > 0) {
                      Text(this.personZodiac(this.selected!))
                        .fontSize(9)
                        .fontColor('#4E7DF4')
                        .backgroundColor('#EAF0FF')
                        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                        .borderRadius(6)
                    }
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')

              Row() {
                Column({ space: 2 }) {
                  Text('生卒')
                    .fontSize(9)
                    .fontColor('#89969C')
                  Text(this.selected!.birth !== undefined &&
                    this.selected!.birth!.text !== undefined
                    ? this.selected!.birth!.text : '未记录')
                    .fontSize(11)
                    .fontColor('#1C2A32')
                    .maxLines(1)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Column()
                  .width(1)
                  .height(28)
                  .backgroundColor('#DDE5E8')
                Column({ space: 2 }) {
                  Text('籍贯')
                    .fontSize(9)
                    .fontColor('#89969C')
                  Text(this.selected!.birthPlace !== undefined &&
                    this.selected!.birthPlace!.length > 0
                    ? this.selected!.birthPlace! : '未记录')
                    .fontSize(11)
                    .fontColor('#1C2A32')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .padding({ left: 12 })
                .alignItems(HorizontalAlign.Start)
                Column()
                  .width(1)
                  .height(28)
                  .backgroundColor('#DDE5E8')
                Column({ space: 2 }) {
                  Text('世代')
                    .fontSize(9)
                    .fontColor('#89969C')
                  Text(this.selected!.generationLabel)
                    .fontSize(11)
                    .fontColor('#1C2A32')
                }
                .layoutWeight(1)
                .padding({ left: 12 })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: 13, right: 13, top: 10, bottom: 10 })
              .backgroundColor('#94FFFFFF')
              .borderRadius(9)

              if (this.canEditAvatar()) {
                Row({ space: 8 }) {
                  Button(this.selected!.hasAvatar === true ? '更换头像' : '设置头像')
                    .fontSize(10)
                    .height(28)
                    .backgroundColor('#FFFFFFB8')
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.pickAvatar();
                    })
                  if (this.selected!.hasAvatar === true) {
                    Button('移除头像')
                      .fontSize(10)
                      .height(28)
                      .backgroundColor('#FFFFFFB8')
                      .fontColor('#B4423D')
                      .onClick(() => {
                        this.confirmDeleteAvatar();
                      })
                  }
                }
                .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 20, right: 20, top: 22, bottom: 19 })
            .linearGradient({
              angle: 135,
              colors: [['#F6F3E9', 0.0], ['#E7EFF0', 1.0]]
            })
            .borderRadius(17)
            .border({ width: 1, color: Color.White })
            .shadow({ radius: 24, color: '#0A20323B', offsetY: 8 })

            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Column()
                  .width(3)
                  .height(15)
                  .backgroundColor('#4E7DF4')
                  .borderRadius(3)
                Text('照片')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                Blank()
                Text(this.personPhotos.length > 0 ? '全部 ›' : '添加 ›')
                  .fontSize(11)
                  .fontColor('#89969C')
                  .onClick(() => {
                    this.openAlbumForPerson(this.selected!.id);
                  })
              }
              .width('100%')
              if (this.personPhotos.length === 0) {
                Text('还没有关联照片')
                  .fontSize(11)
                  .fontColor('#89969C')
              } else {
                Row({ space: 8 }) {
                  ForEach(this.personPhotos.slice(0, 4), (photo: ApiPhoto) => {
                    Stack() {
                      AuthImage({
                        path: '/api/v1/photos/' + photo.id + '/content',
                        radius: 9
                      })
                    }
                    .width(68)
                    .height(68)
                    .onClick(() => {
                      this.openAlbumForPerson(this.selected!.id);
                    })
                  }, (photo: ApiPhoto) => photo.id)
                }
                .width('100%')
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(15)
            .alignItems(HorizontalAlign.Start)

            if (this.canDelete() || this.linkedPersonId.length === 0) {
              Row({ space: 8 }) {
                if (this.canDelete()) {
                  Button('编辑资料')
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(11)
                    .backgroundColor('#FFFFFF')
                    .fontColor('#1C2A32')
                    .border({ width: 1, color: '#ECF0F1' })
                    .onClick(() => {
                      this.openEditPerson();
                    })
                  Button('添加亲属')
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(11)
                    .backgroundColor('#EAF0FF')
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.openAddRelation();
                    })
                }
                if (!this.canDelete()) {
                  Button('申请修改资料')
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(11)
                    .backgroundColor('#EAF0FF')
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.openProfileRequest();
                    })
                }
                if (this.linkedPersonId.length === 0) {
                  Button('绑定为此人物')
                    .layoutWeight(1)
                    .height(38)
                    .fontSize(11)
                    .backgroundColor('#FFF4DF')
                    .fontColor('#B7791F')
                    .onClick(() => {
                      this.confirmBindPerson();
                    })
                }
              }
              .width('100%')
            }

            this.RelationSection('父母', this.selected!.parents)
            this.RelationSection('配偶', this.selected!.spouses)
            this.RelationSection('子女', this.selected!.children)

            if (this.selected!.biography !== undefined && this.selected!.biography!.length > 0) {
              Column({ space: 6 }) {
                Text('生平简介')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                Text(this.selected!.biography!)
                  .fontSize(12)
                  .lineHeight(20)
                  .fontColor('#6C7B82')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(15)
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private RelationSection(title: string, relations: ApiRelative[] | undefined) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column()
          .width(3)
          .height(15)
          .backgroundColor('#4E7DF4')
          .borderRadius(3)
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
      }
      .width('100%')
      if (relations === undefined || relations.length === 0) {
        Text('未记录')
          .fontSize(11)
          .fontColor('#89969C')
      } else {
        ForEach(relations, (item: ApiRelative) => {
          Row() {
            Text(item.relation)
              .fontSize(11)
              .fontColor('#89969C')
              .width(44)
            Text(item.fullName)
              .fontSize(13)
              .fontColor('#1C2A32')
              .onClick(() => {
                this.openPerson(item.personId);
              })
            Blank()
            if (item.edgeId.length > 0) {
              Text('×')
                .fontSize(16)
                .fontColor('#C1CBCF')
                .padding({ left: 8, right: 8 })
                .onClick(() => {
                  this.confirmDeleteRelation(item, title);
                })
            }
            Text('›')
              .fontSize(17)
              .fontColor('#C1CBCF')
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (item: ApiRelative) => item.personId + item.relation)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(15)
  }

  @Builder
  private ProfileRequestView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'detail';
          })
        Text('申请修改资料')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
        Blank()
        Button(this.profileReqBusy ? '提交中' : '提交')
          .fontSize(11)
          .height(32)
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .enabled(!this.profileReqBusy)
          .onClick(() => {
            this.submitProfileRequest();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 10 }) {
          Text('只提交实际改动的字段，族长或管理员审核通过后才写入正式档案。')
            .fontSize(10)
            .lineHeight(16)
            .fontColor('#89969C')
            .width('100%')
            .padding(12)
            .backgroundColor('#FFF8F0')
            .borderRadius(9)
          TextInput({ placeholder: '籍贯', text: this.profileReqBirthPlace })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.profileReqBirthPlace = value;
            })
          TextInput({ placeholder: '现居地', text: this.profileReqResidence })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.profileReqResidence = value;
            })
          TextInput({ placeholder: '职业', text: this.profileReqOccupation })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.profileReqOccupation = value;
            })
          TextInput({ placeholder: '教育', text: this.profileReqEducation })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.profileReqEducation = value;
            })
          TextArea({ placeholder: '生平简介', text: this.profileReqBiography })
            .height(160)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(12)
            .onChange((value: string) => {
              this.profileReqBiography = value;
            })
          if (this.profileReqError.length > 0) {
            Text(this.profileReqError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private EditPersonView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'detail';
          })
        Text('编辑人物资料')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
        Blank()
        Button(this.editBusy ? '保存中' : '保存')
          .fontSize(11)
          .height(32)
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .enabled(!this.editBusy)
          .onClick(() => {
            this.saveEditedPerson();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 10 }) {
          TextInput({ placeholder: '姓', text: this.editSurname })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editSurname = value;
            })
          TextInput({ placeholder: '名', text: this.editGivenName })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editGivenName = value;
            })
          TextInput({ placeholder: '字（可选）', text: this.editCourtesyName })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editCourtesyName = value;
            })
          TextInput({ placeholder: '号（可选）', text: this.editAlias })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editAlias = value;
            })
          Row({ space: 10 }) {
            Button('男')
              .layoutWeight(1)
              .height(38)
              .backgroundColor(this.editGender === 'male' ? '#4E7DF4' : '#F2F5F7')
              .fontColor(this.editGender === 'male' ? Color.White : '#1C2A32')
              .onClick(() => {
                this.editGender = 'male';
              })
            Button('女')
              .layoutWeight(1)
              .height(38)
              .backgroundColor(this.editGender === 'female' ? '#B45D5A' : '#F2F5F7')
              .fontColor(this.editGender === 'female' ? Color.White : '#1C2A32')
              .onClick(() => {
                this.editGender = 'female';
              })
          }
          .width('100%')
          TextInput({ placeholder: '世代（数字）', text: this.editGeneration })
            .height(44)
            .type(InputType.Number)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editGeneration = value;
            })
          if (this.dataBranches.length > 0) {
            Select(this.dataBranches.map((branch: ApiBranch) => {
              const option: SelectOption = { value: branch.name };
              return option;
            }))
              .selected(this.editBranchIndex)
              .value(this.dataBranches[Math.min(
                this.editBranchIndex,
                this.dataBranches.length - 1
              )].name)
              .onSelect((index: number) => {
                this.editBranchIndex = index;
              })
              .width('100%')
          }
          Row({ space: 10 }) {
            Button('在世')
              .layoutWeight(1)
              .height(36)
              .backgroundColor(this.editLifeStatus === 'living' ? '#E8F6EF' : '#F2F5F7')
              .fontColor(this.editLifeStatus === 'living' ? '#2F8F67' : '#89969C')
              .onClick(() => {
                this.editLifeStatus = 'living';
              })
            Button('已故')
              .layoutWeight(1)
              .height(36)
              .backgroundColor(this.editLifeStatus !== 'living' ? '#EDF2F5' : '#F2F5F7')
              .fontColor(this.editLifeStatus !== 'living' ? '#6C7B82' : '#89969C')
              .onClick(() => {
                this.editLifeStatus = 'deceased';
              })
          }
          .width('100%')
          TextInput({ placeholder: '出生年份（可选）', text: this.editBirthYear })
            .height(44)
            .type(InputType.Number)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editBirthYear = value;
            })
          TextInput({ placeholder: '籍贯', text: this.editBirthPlace })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editBirthPlace = value;
            })
          TextInput({ placeholder: '现居地', text: this.editResidence })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editResidence = value;
            })
          TextInput({ placeholder: '职业', text: this.editOccupation })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editOccupation = value;
            })
          TextInput({ placeholder: '教育', text: this.editEducation })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.editEducation = value;
            })
          TextArea({ placeholder: '生平简介', text: this.editBiography })
            .height(160)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(12)
            .onChange((value: string) => {
              this.editBiography = value;
            })
          if (this.editError.length > 0) {
            Text(this.editError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private AddRelationView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'detail';
          })
        Text('添加亲属')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 4 }) {
            Text('为 ' + (this.selected !== null ? this.selected!.fullName : '') + ' 添加：')
              .fontSize(13)
              .fontColor('#1C2A32')
              .width('100%')
            Text('添加后族谱树和人物档案会立即刷新。')
              .fontSize(10)
              .fontColor('#89969C')
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('关系类型')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C2A32')
              .width('100%')
            Select([
              { value: '父亲' },
              { value: '母亲' },
              { value: '配偶' },
              { value: '子女' }
            ])
              .selected(this.relationTypeIndex)
              .value(['父亲', '母亲', '配偶', '子女'][this.relationTypeIndex])
              .onSelect((index: number) => {
                this.relationTypeIndex = index;
              })
              .width('100%')
            Text('关联人物')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C2A32')
              .width('100%')
            Select(this.relationPersonOptions())
              .selected(this.relationPersonIndex)
              .value(this.relationPersonOptions()[Math.min(
                this.relationPersonIndex,
                this.relationPersonOptions().length - 1
              )].value)
              .onSelect((index: number) => {
                this.relationPersonIndex = index;
              })
              .width('100%')
            if (this.relationError.length > 0) {
              Text(this.relationError)
                .fontSize(11)
                .fontColor('#B4423D')
                .width('100%')
            }
            Button(this.relationBusy ? '正在保存...' : '保存关系')
              .width('100%')
              .height(44)
              .backgroundColor('#4E7DF4')
              .fontColor(Color.White)
              .enabled(!this.relationBusy)
              .onClick(() => {
                this.addRelation();
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private AddPersonView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'tabs';
          })
        Text('新增人物')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 10 }) {
            Text('基本信息')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            TextInput({ placeholder: '姓', text: this.addSurname })
              .height(46)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .onChange((value: string) => {
                this.addSurname = value;
              })
            TextInput({ placeholder: '名', text: this.addGiven })
              .height(46)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .onChange((value: string) => {
                this.addGiven = value;
              })
            Row({ space: 10 }) {
              Button('男')
                .layoutWeight(1)
                .height(40)
                .backgroundColor(this.addGender === 'male' ? '#4E7DF4' : '#F2F5F7')
                .fontColor(this.addGender === 'male' ? Color.White : '#1C2A32')
                .onClick(() => {
                  this.addGender = 'male';
                })
              Button('女')
                .layoutWeight(1)
                .height(40)
                .backgroundColor(this.addGender === 'female' ? '#B45D5A' : '#F2F5F7')
                .fontColor(this.addGender === 'female' ? Color.White : '#1C2A32')
                .onClick(() => {
                  this.addGender = 'female';
                })
            }
            .width('100%')
            TextInput({ placeholder: '世代（数字）', text: this.addGeneration })
              .height(46)
              .type(InputType.Number)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .onChange((value: string) => {
                this.addGeneration = value;
              })
            if (this.branches.length > 0) {
              Select(this.branches.map((branch: ApiBranch) => {
                const option: SelectOption = { value: branch.name };
                return option;
              }))
                .selected(this.addBranchIndex)
                .value(this.branches[Math.min(this.addBranchIndex, this.branches.length - 1)].name)
                .onSelect((index: number) => {
                  this.addBranchIndex = index;
                })
                .width('100%')
            } else {
              Text('暂无可用家支')
                .fontSize(11)
                .fontColor('#B4423D')
            }
            if (this.error.length > 0) {
              Text(this.error)
                .fontSize(11)
                .fontColor('#B4423D')
                .width('100%')
            }
            Button(this.busy ? '正在保存...' : '保存到族谱')
              .width('100%')
              .height(48)
              .backgroundColor('#4E7DF4')
              .fontColor(Color.White)
              .borderRadius(10)
              .enabled(!this.busy)
              .onClick(() => {
                this.createPerson();
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(15)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private AlbumView() {
    Stack() {
      Column() {
        Row() {
          Button('‹')
            .width(38)
            .height(38)
            .backgroundColor('#FFFFFF')
            .fontColor('#1C2A32')
            .fontSize(22)
            .borderRadius(19)
            .onClick(() => {
              this.viewerPhoto = null;
              this.page = 'tabs';
            })
          Column({ space: 2 }) {
            Text('家族相册')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
            Text('共 ' + this.albumPhotos.length + ' 张')
              .fontSize(10)
              .fontColor('#89969C')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10 })
          Blank()
          Button(this.albumBusy ? '上传中' : '上传')
            .fontSize(11)
            .height(32)
            .backgroundColor('#4E7DF4')
            .fontColor(Color.White)
            .enabled(!this.albumBusy)
            .onClick(() => {
              this.pickAndUploadPhotos();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 8 })

        Row() {
          Select(this.albumFilterOptions())
            .selected(this.albumFilterIndex)
            .value(this.albumFilterOptions()[Math.min(
              this.albumFilterIndex,
              this.albumFilterOptions().length - 1
            )].value)
            .onSelect((index: number) => {
              this.albumFilterIndex = index;
              this.loadPhotos();
            })
            .layoutWeight(1)
          if (this.albumPersonId().length > 0) {
            Text('上传会关联到当前人物')
              .fontSize(10)
              .fontColor('#89969C')
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 8 })

        if (this.albumError.length > 0) {
          Text(this.albumError)
            .fontSize(12)
            .fontColor('#B4423D')
            .padding(16)
        }

        if (this.albumBusy && this.albumPhotos.length === 0) {
          Column({ space: 10 }) {
            LoadingProgress().width(28).height(28).color('#4E7DF4')
            Text('正在加载相册...').fontSize(12).fontColor('#89969C')
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.albumPhotos.length === 0) {
          Column({ space: 8 }) {
            Text('还没有照片')
              .fontSize(16)
              .fontColor('#1C2A32')
            Text('点击右上角“上传”，从系统相册选择照片')
              .fontSize(11)
              .fontColor('#89969C')
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Grid() {
            ForEach(this.albumPhotos, (photo: ApiPhoto) => {
              GridItem() {
                Stack({ alignContent: Alignment.BottomStart }) {
                  AuthImage({
                    path: '/api/v1/photos/' + photo.id + '/content',
                    radius: 10
                  })
                  if (photo.caption.length > 0) {
                    Text(photo.caption)
                      .fontSize(9)
                      .fontColor(Color.White)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                      .backgroundColor('#00000099')
                      .width('100%')
                  }
                }
                .width('100%')
                .aspectRatio(1)
                .borderRadius(10)
                .clip(true)
                .onClick(() => {
                  this.viewerPhoto = photo;
                })
              }
            }, (photo: ApiPhoto) => photo.id)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .padding({ left: 14, right: 14 })
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')

      if (this.viewerPhoto !== null) {
        this.PhotoViewer()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private PhotoFormView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'album';
          })
        Text(this.photoFormEditingId.length > 0 ? '编辑照片信息' : '上传照片')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
        Blank()
        Button(this.photoFormBusy ? '保存中' : '保存')
          .fontSize(11)
          .height(32)
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .enabled(!this.photoFormBusy)
          .onClick(() => {
            this.savePhotoForm();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 10 }) {
          if (this.photoFormEditingId.length > 0) {
            Stack() {
              AuthImage({
                path: '/api/v1/photos/' + this.photoFormEditingId + '/content',
                radius: 10,
                fit: ImageFit.Cover
              })
            }
            .width('100%')
            .height(180)
          } else {
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.photoFormUris, (uri: string) => {
                  Image(uri)
                    .width(64)
                    .height(64)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                }, (uri: string) => uri)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }
          TextInput({ placeholder: '照片说明（可选）', text: this.photoFormCaption })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.photoFormCaption = value;
            })
          TextInput({ placeholder: '拍摄日期 YYYY-MM-DD（可选）', text: this.photoFormTakenAt })
            .height(44)
            .backgroundColor('#F7F9FA')
            .borderRadius(8)
            .fontSize(13)
            .onChange((value: string) => {
              this.photoFormTakenAt = value;
            })
          Column({ space: 7 }) {
            Text('关联人物')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text('可同时选择多人，照片会出现在这些人的档案中。')
              .fontSize(10)
              .fontColor('#89969C')
              .width('100%')
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.tree !== null ? this.tree.persons : [], (person: ApiPerson) => {
                Text(person.fullName)
                  .fontSize(10)
                  .fontColor(this.photoFormPersonIds.includes(person.id)
                    ? '#4E7DF4' : '#6C7B82')
                  .backgroundColor(this.photoFormPersonIds.includes(person.id)
                    ? '#EAF0FF' : '#F2F5F7')
                  .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                  .borderRadius(8)
                  .margin({ right: 6, bottom: 6 })
                  .onClick(() => {
                    this.togglePhotoPerson(person.id);
                  })
              }, (person: ApiPerson) => person.id)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          if (this.photoFormError.length > 0) {
            Text(this.photoFormError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private PhotoViewer() {
    Stack() {
      Column() {
        AuthImage({
          path: '/api/v1/photos/' + this.viewerPhoto!.id + '/content',
          radius: 0,
          fit: ImageFit.Contain
        })
          .width('100%')
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#111417')

      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF33')
          .fontColor(Color.White)
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.viewerPhoto = null;
          })
        Blank()
        Button('编辑')
          .fontSize(11)
          .height(32)
          .backgroundColor('#FFFFFF33')
          .fontColor(Color.White)
          .margin({ right: 8 })
          .onClick(() => {
            this.openEditPhotoForm(this.viewerPhoto!);
          })
        if (this.canDelete()) {
          Button(this.viewerBusy ? '删除中' : '删除')
            .fontSize(11)
            .height(32)
            .backgroundColor('#B4423DCC')
            .fontColor(Color.White)
            .enabled(!this.viewerBusy)
            .onClick(() => {
              this.confirmDeletePhoto();
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12 })
      .position({ x: 0, y: 0 })

      Column({ space: 4 }) {
        if (this.viewerPhoto!.caption.length > 0) {
          Text(this.viewerPhoto!.caption)
            .fontSize(12)
            .fontColor(Color.White)
        }
        Text(this.viewerPhoto!.persons.length > 0
          ? this.viewerPhoto!.persons.map((item) => item.fullName).join('、')
          : '家族影像')
          .fontSize(10)
          .fontColor('#FFFFFFAA')
      }
      .width('100%')
      .padding(16)
      .position({ x: 0, y: '82%' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private AvatarCropView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'detail';
          })
        Text('裁剪头像')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.avatarSource !== undefined) {
        Stack() {
          Image(this.avatarSource)
            .width(280)
            .height(280)
            .objectFit(ImageFit.Cover)
            .scale({ x: this.avatarZoom, y: this.avatarZoom })
          Column()
            .width(280)
            .height(280)
            .border({ width: 2, color: '#FFFFFFCC' })
            .backgroundColor('#00000000')
        }
        .width(280)
        .height(280)
        .borderRadius(20)
        .clip(true)
        .backgroundColor('#1C2A32')

        Text('双指或滑块缩放，头像会自动取中心正方形')
          .fontSize(11)
          .fontColor('#6C7B82')
          .margin({ top: 12 })
        Slider({
          value: this.avatarZoom,
          min: 1,
          max: 3,
          step: 0.1
        })
          .width('80%')
          .selectedColor('#4E7DF4')
          .onChange((value: number) => {
            this.avatarZoom = value;
          })
        if (this.avatarError.length > 0) {
          Text(this.avatarError)
            .fontSize(11)
            .fontColor('#B4423D')
        }
        Button(this.avatarBusy ? '正在保存...' : '保存头像')
          .width('80%')
          .height(46)
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .borderRadius(10)
          .enabled(!this.avatarBusy)
          .onClick(() => {
            this.confirmAvatar();
          })
      } else {
        Column({ space: 8 }) {
          Text('没有选择图片')
            .fontSize(14)
            .fontColor('#1C2A32')
          Text('请返回人物档案重新选择')
            .fontSize(11)
            .fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private StoriesView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'tabs';
          })
        Column({ space: 2 }) {
          Text('家族故事')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text('共 ' + this.stories.length + ' 篇家族记忆')
            .fontSize(10)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
        Blank()
        Button('写故事')
          .fontSize(11)
          .height(32)
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .onClick(() => {
            this.openStoryEditor();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.storiesBusy && this.stories.length === 0) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载家族故事...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.storiesError.length > 0) {
        Column({ space: 8 }) {
          Text(this.storiesError)
            .fontSize(12)
            .fontColor('#B4423D')
          Button('重新加载')
            .fontSize(11)
            .height(32)
            .backgroundColor('#EAF0FF')
            .fontColor('#4E7DF4')
            .onClick(() => {
              this.loadStories();
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.stories.length === 0) {
        Column({ space: 8 }) {
          Text('还没有家族故事')
            .fontSize(16)
            .fontColor('#1C2A32')
          Text('写下长辈的经历、家族的迁徙或一次难忘的团聚')
            .fontSize(11)
            .fontColor('#89969C')
          Button('写第一篇故事')
            .fontSize(12)
            .height(36)
            .backgroundColor('#4E7DF4')
            .fontColor(Color.White)
            .onClick(() => {
              this.openStoryEditor();
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.stories, (story: ApiStory) => {
            ListItem() {
              Row({ space: 12 }) {
                Stack() {
                  if (story.photos.length > 0) {
                    AuthImage({
                      path: '/api/v1/photos/' + story.photos[0].id + '/content',
                      radius: 12
                    })
                  } else {
                    Text('文')
                      .width('100%')
                      .height('100%')
                      .textAlign(TextAlign.Center)
                      .fontSize(20)
                      .fontColor('#B45D5A')
                      .backgroundColor('#FBEEEA')
                  }
                }
                .width(82)
                .height(82)

                Column({ space: 4 }) {
                  Text(story.title)
                    .fontSize(15)
                    .fontFamily('serif')
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1C2A32')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(story.body)
                    .fontSize(11)
                    .fontColor('#6C7B82')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(story.authorName + ' · ' +
                    (story.createdAt !== undefined ? story.createdAt!.substring(0, 10) : ''))
                    .fontSize(9)
                    .fontColor('#89969C')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(Color.White)
              .borderRadius(14)
              .border({ width: 1, color: '#FFFFFFCC' })
              .shadow({ radius: 24, color: '#0A20323B', offsetY: 8 })
              .onClick(() => {
                this.openStory(story);
              })
            }
          }, (story: ApiStory) => story.id)
        }
        .layoutWeight(1)
        .padding({ left: 14, right: 14 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private StoryDetailView() {
    Stack() {
      Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.selectedStory = null;
            this.page = 'stories';
          })
        Text('家族故事')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
        Blank()
        if (this.selectedStory !== null &&
          (this.canDeleteStory() ||
            this.selectedStory!.authorUserId === this.currentUserId)) {
          Button('编辑')
            .fontSize(11)
            .height(32)
            .backgroundColor('#EAF0FF')
            .fontColor('#4E7DF4')
            .margin({ right: 8 })
            .onClick(() => {
              this.openEditStory(this.selectedStory!);
            })
        }
        if (this.canDeleteStory() && this.selectedStory !== null) {
          Button('删除')
            .fontSize(11)
            .height(32)
            .backgroundColor('#FBEEEA')
            .fontColor('#B4423D')
            .onClick(() => {
              this.confirmDeleteStory();
            })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.storyDetailBusy || this.selectedStory === null) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在打开故事...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Text(this.selectedStory!.title)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text(this.selectedStory!.authorName + ' · ' +
              (this.selectedStory!.createdAt !== undefined
                ? this.selectedStory!.createdAt!.substring(0, 10) : ''))
              .fontSize(10)
              .fontColor('#89969C')
              .width('100%')
            if (this.selectedStory!.personName.length > 0) {
              Text('关联人物：' + this.selectedStory!.personName)
                .fontSize(10)
                .fontColor('#4E7DF4')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#EAF0FF')
                .borderRadius(8)
            }
            Text(this.selectedStory!.body)
              .fontSize(14)
              .lineHeight(24)
              .fontColor('#3A4A52')
              .width('100%')

            if (this.selectedStory!.photos.length > 0) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.selectedStory!.photos, (photo: ApiPhoto) => {
                  Stack() {
                    AuthImage({
                      path: '/api/v1/photos/' + photo.id + '/content',
                      radius: 10
                    })
                  }
                  .width('48%')
                  .aspectRatio(1)
                  .margin({ bottom: 8 })
                  .onClick(() => {
                    this.storyViewerPhoto = photo;
                  })
                }, (photo: ApiPhoto) => photo.id)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 28 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      if (this.storyViewerPhoto !== null) {
        this.StoryPhotoViewer()
      }
    }
    .width('100%')
    .height('100%')
  }
  }

  @Builder
  private StoryPhotoViewer() {
    Stack() {
      AuthImage({
        path: '/api/v1/photos/' + this.storyViewerPhoto!.id + '/content',
        radius: 0,
        fit: ImageFit.Contain
      })
        .width('100%')
        .height('100%')
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF33')
          .fontColor(Color.White)
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.storyViewerPhoto = null;
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12 })
      .position({ x: 0, y: 0 })
      if (this.storyViewerPhoto!.caption.length > 0) {
        Text(this.storyViewerPhoto!.caption)
          .fontSize(12)
          .fontColor(Color.White)
          .padding(16)
          .position({ x: 0, y: '82%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111417')
  }

  @Builder
  private StoryEditView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'stories';
          })
        Text(this.storyEditingId.length > 0 ? '编辑故事' : '写家族故事')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .margin({ left: 12 })
        Blank()
        Button(this.storySaving ? '保存中' : '发布')
          .fontSize(11)
          .height(32)
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .enabled(!this.storySaving)
          .onClick(() => {
            this.saveStory();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          TextInput({ placeholder: '故事标题', text: this.storyTitle })
            .height(48)
            .backgroundColor(Color.White)
            .borderRadius(10)
            .fontSize(15)
            .onChange((value: string) => {
              this.storyTitle = value;
            })

          TextArea({ placeholder: '写下这段家族记忆...', text: this.storyBody })
            .height(220)
            .backgroundColor(Color.White)
            .borderRadius(10)
            .fontSize(13)
            .onChange((value: string) => {
              this.storyBody = value;
            })

          Select(this.storyPersonOptions())
            .selected(this.storyPersonIndex)
            .value(this.storyPersonOptions()[Math.min(
              this.storyPersonIndex,
              this.storyPersonOptions().length - 1
            )].value)
            .onSelect((index: number) => {
              this.storyPersonIndex = index;
            })
            .width('100%')

          Column({ space: 8 }) {
            Row() {
              Text('故事配图')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1C2A32')
              Blank()
              Text(this.storyExistingPhotos.length + this.storyPhotoUris.length + '/9')
                .fontSize(10)
                .fontColor('#89969C')
            }
            .width('100%')
            if (this.storyExistingPhotos.length > 0) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.storyExistingPhotos, (photo: ApiPhoto) => {
                  Stack({ alignContent: Alignment.TopEnd }) {
                    AuthImage({
                      path: '/api/v1/photos/' + photo.id + '/content',
                      radius: 8
                    })
                    Text('×')
                      .width(24)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .fontSize(15)
                      .fontColor(Color.White)
                      .backgroundColor('#00000099')
                      .borderRadius(12)
                      .margin(4)
                      .onClick(() => {
                        this.storyExistingPhotos = this.storyExistingPhotos.filter(
                          (item: ApiPhoto) => item.id !== photo.id
                        );
                      })
                  }
                  .width('31%')
                  .aspectRatio(1)
                  .borderRadius(8)
                  .clip(true)
                  .margin({ bottom: 8 })
                }, (photo: ApiPhoto) => photo.id)
              }
              .width('100%')
            }
            if (this.storyPhotoUris.length > 0) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
                ForEach(this.storyPhotoUris, (uri: string, index: number) => {
                  Stack({ alignContent: Alignment.TopEnd }) {
                    Image(uri)
                      .width('100%')
                      .height('100%')
                      .objectFit(ImageFit.Cover)
                    Text('×')
                      .width(24)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .fontSize(15)
                      .fontColor(Color.White)
                      .backgroundColor('#00000099')
                      .borderRadius(12)
                      .margin(4)
                      .onClick(() => {
                        const next = this.storyPhotoUris.filter(
                          (item: string, i: number) => i !== index
                        );
                        this.storyPhotoUris = next;
                      })
                  }
                  .width('31%')
                  .aspectRatio(1)
                  .borderRadius(8)
                  .clip(true)
                  .margin({ bottom: 8 })
                }, (uri: string, index: number) => uri + String(index))
              }
              .width('100%')
            }
            Button('添加图片')
              .width('100%')
              .height(38)
              .fontSize(12)
              .backgroundColor('#F2F5F7')
              .fontColor('#1C2A32')
              .enabled(!this.storySaving)
              .onClick(() => {
                this.pickStoryPhotos();
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)

          if (this.storyStatus.length > 0) {
            Text(this.storyStatus)
              .fontSize(11)
              .fontColor('#4E7DF4')
          }
          if (this.storyError.length > 0) {
            Text(this.storyError)
              .fontSize(11)
              .fontColor('#B4423D')
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private InboxView() {
    Stack() {
      Column() {
        Row() {
          Button('‹')
            .width(38)
            .height(38)
            .backgroundColor('#FFFFFF')
            .fontColor('#1C2A32')
            .fontSize(22)
            .borderRadius(19)
            .onClick(() => {
              this.page = 'tabs';
            })
          Column({ space: 2 }) {
            Text('消息中心')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
            Text(this.unreadCount > 0 ? '未读 ' + String(this.unreadCount) + ' 条' : '暂无未读消息')
              .fontSize(10)
              .fontColor('#89969C')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 10 })
          Blank()
          if (this.unreadCount > 0) {
            Button('全部已读')
              .fontSize(11)
              .height(32)
              .backgroundColor('#EAF0FF')
              .fontColor('#4E7DF4')
              .onClick(() => {
                this.markAllNotificationsRead();
              })
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 8 })

        Row({ space: 8 }) {
          this.InboxTabButton('通知', 0)
          this.InboxTabButton(this.canDelete() ? '审核' : '我的申请', 1)
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 8 })

        if (this.inboxBusy) {
          Column({ space: 10 }) {
            LoadingProgress().width(28).height(28).color('#4E7DF4')
            Text('正在加载...').fontSize(12).fontColor('#89969C')
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.inboxError.length > 0) {
          Column({ space: 8 }) {
            Text(this.inboxError)
              .fontSize(12)
              .fontColor('#B4423D')
            Button('重新加载')
              .fontSize(11)
              .height(32)
              .backgroundColor('#EAF0FF')
              .fontColor('#4E7DF4')
              .onClick(() => {
                this.loadInbox();
              })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.inboxTab === 0) {
          if (this.notifications.length === 0) {
            Column({ space: 8 }) {
              Text('暂无消息')
                .fontSize(15)
                .fontColor('#1C2A32')
              Text('审核结果和新动态会显示在这里')
                .fontSize(11)
                .fontColor('#89969C')
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 8 }) {
              ForEach(this.notifications, (item: ApiNotification) => {
                ListItem() {
                  Row({ space: 10 }) {
                    Column()
                      .width(8)
                      .height(8)
                      .borderRadius(4)
                      .backgroundColor(item.isRead ? '#DDE5E8' : '#B4423D')
                    Column({ space: 3 }) {
                      Text(item.title)
                        .fontSize(13)
                        .fontWeight(item.isRead ? FontWeight.Normal : FontWeight.Medium)
                        .fontColor('#1C2A32')
                      Text(item.body)
                        .fontSize(11)
                        .fontColor('#6C7B82')
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(item.createdAt !== undefined
                        ? item.createdAt!.substring(0, 10) : '')
                        .fontSize(9)
                        .fontColor('#89969C')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding(13)
                  .backgroundColor(item.isRead ? '#F7F9FA' : Color.White)
                  .borderRadius(12)
                  .onClick(() => {
                    this.markNotificationRead(item);
                  })
                }
              }, (item: ApiNotification) => String(item.id))
            }
            .layoutWeight(1)
            .padding({ left: 14, right: 14 })
            .scrollBar(BarState.Off)
          }
        } else if (!this.canDelete()) {
          Scroll() {
            Column({ space: 8 }) {
              if (this.myRequests.length === 0) {
                Text('还没有提交过资料修改申请')
                  .fontSize(11)
                  .fontColor('#89969C')
                  .padding(20)
              }
              ForEach(this.myRequests, (item: ApiEditRequest) => {
                Column({ space: 5 }) {
                  Row() {
                    Text(item.summary)
                      .fontSize(12)
                      .fontColor('#1C2A32')
                      .layoutWeight(1)
                    Text(item.status === 'pending' ? '待审核' :
                      item.status === 'approved' ? '已通过' :
                      item.status === 'rejected' ? '已拒绝' : item.status)
                      .fontSize(9)
                      .fontColor(item.status === 'pending' ? '#B7791F' :
                        item.status === 'approved' ? '#2F8F67' : '#B4423D')
                  }
                  .width('100%')
                  Text(item.requesterName + ' · ' +
                    (item.submittedAt !== undefined
                      ? item.submittedAt!.substring(0, 10) : ''))
                    .fontSize(9)
                    .fontColor('#89969C')
                  if (item.reviewNote !== undefined && item.reviewNote!.length > 0) {
                    Text('审核意见：' + item.reviewNote!)
                      .fontSize(10)
                      .fontColor('#6C7B82')
                  }
                  Text('查看详情')
                    .fontSize(10)
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.showEditRequestDetail(item);
                    })
                }
                .width('100%')
                .padding(12)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .alignItems(HorizontalAlign.Start)
              }, (item: ApiEditRequest) => item.id)
            }
            .width('100%')
            .padding(14)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Row() {
                Column({ space: 2 }) {
                  Text('家族合并')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1C2A32')
                  Text('查看其他家族并入本家族的申请')
                    .fontSize(10)
                    .fontColor('#89969C')
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Button('查看')
                  .fontSize(11)
                  .height(32)
                  .backgroundColor('#EAF0FF')
                  .fontColor('#4E7DF4')
                  .onClick(() => {
                    this.openMerges();
                  })
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(14)

              Column({ space: 8 }) {
                Row() {
                  Text('资料修改审核')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1C2A32')
                  Blank()
                  Text('待审 ' + String(this.editReviews.length))
                    .fontSize(10)
                    .fontColor('#89969C')
                }
                .width('100%')
                if (this.editReviews.length === 0) {
                  Text('暂无待审核的资料修改')
                    .fontSize(11)
                    .fontColor('#89969C')
                    .width('100%')
                } else {
                  ForEach(this.editReviews, (item: ApiEditRequest) => {
                    Column({ space: 5 }) {
                      Text(item.summary)
                        .fontSize(12)
                        .fontColor('#1C2A32')
                      Text(item.requesterName + ' 提交 · ' +
                        (item.submittedAt !== undefined
                          ? item.submittedAt!.substring(0, 10) : ''))
                        .fontSize(9)
                        .fontColor('#89969C')
                      Row({ space: 8 }) {
                        Text('详情')
                          .fontSize(10)
                          .fontColor('#4E7DF4')
                          .padding({ left: 4, right: 4 })
                          .onClick(() => {
                            this.showEditRequestDetail(item);
                          })
                        Button('通过')
                          .layoutWeight(1)
                          .height(32)
                          .fontSize(11)
                          .backgroundColor('#E9F6EF')
                          .fontColor('#2F8F67')
                          .onClick(() => {
                            this.startReview('edit', item.id, item.summary, true);
                          })
                        Button('拒绝')
                          .layoutWeight(1)
                          .height(32)
                          .fontSize(11)
                          .backgroundColor('#FBEEEA')
                          .fontColor('#B4423D')
                          .onClick(() => {
                            this.startReview('edit', item.id, item.summary, false);
                          })
                      }
                      .width('100%')
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor(Color.White)
                    .borderRadius(12)
                    .alignItems(HorizontalAlign.Start)
                  }, (item: ApiEditRequest) => item.id)
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(14)
              .alignItems(HorizontalAlign.Start)

              Column({ space: 8 }) {
                Row() {
                  Text('人物绑定审核')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1C2A32')
                  Blank()
                  Text('待审 ' + String(this.bindingReviews.length))
                    .fontSize(10)
                    .fontColor('#89969C')
                }
                .width('100%')
                if (this.bindingReviews.length === 0) {
                  Text('暂无待审核的绑定申请')
                    .fontSize(11)
                    .fontColor('#89969C')
                    .width('100%')
                } else {
                  ForEach(this.bindingReviews, (item: ApiBindingRequest) => {
                    Column({ space: 5 }) {
                      Text(item.requesterName + ' → ' + item.personName)
                        .fontSize(12)
                        .fontColor('#1C2A32')
                      Text(item.submittedAt !== undefined
                        ? item.submittedAt!.substring(0, 10) : '')
                        .fontSize(9)
                        .fontColor('#89969C')
                      Row({ space: 8 }) {
                        Button('通过')
                          .layoutWeight(1)
                          .height(32)
                          .fontSize(11)
                          .backgroundColor('#E9F6EF')
                          .fontColor('#2F8F67')
                          .onClick(() => {
                            this.startReview('binding', item.id,
                              item.requesterName + ' → ' + item.personName, true);
                          })
                        Button('拒绝')
                          .layoutWeight(1)
                          .height(32)
                          .fontSize(11)
                          .backgroundColor('#FBEEEA')
                          .fontColor('#B4423D')
                          .onClick(() => {
                            this.startReview('binding', item.id,
                              item.requesterName + ' → ' + item.personName, false);
                          })
                      }
                      .width('100%')
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor(Color.White)
                    .borderRadius(12)
                    .alignItems(HorizontalAlign.Start)
                  }, (item: ApiBindingRequest) => item.id)
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(14)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: 14, right: 14, bottom: 24 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

      if (this.reviewId.length > 0) {
        this.ReviewSheet()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private InboxTabButton(label: string, index: number) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(12)
      .backgroundColor(this.inboxTab === index ? '#4E7DF4' : '#FFFFFF')
      .fontColor(this.inboxTab === index ? Color.White : '#6C7B82')
      .borderRadius(8)
      .onClick(() => {
        this.inboxTab = index;
      })
  }

  @Builder
  private ReviewSheet() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000066')
        .onClick(() => {
          this.cancelReview();
        })
      Column({ space: 10 }) {
        Text((this.reviewApprove ? '通过：' : '拒绝：') + this.reviewLabel)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C2A32')
          .width('100%')
        Text(this.reviewKind === 'edit'
          ? '通过后会写入正式档案；拒绝时必须填写原因。'
          : '通过后会绑定账号与人物；拒绝时必须填写原因。')
          .fontSize(11)
          .fontColor('#6C7B82')
          .width('100%')
        TextArea({
          placeholder: this.reviewApprove ? '审核意见（可选）' : '拒绝原因（必填）',
          text: this.reviewNote
        })
          .height(100)
          .backgroundColor('#F7F9FA')
          .borderRadius(8)
          .fontSize(12)
          .onChange((value: string) => {
            this.reviewNote = value;
          })
        if (this.reviewError.length > 0) {
          Text(this.reviewError)
            .fontSize(11)
            .fontColor('#B4423D')
            .width('100%')
        }
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#F2F5F7')
            .fontColor('#1C2A32')
            .onClick(() => {
              this.cancelReview();
            })
          Button(this.reviewBusy ? '提交中' : '确认提交')
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.reviewApprove ? '#3DA77C' : '#B4423D')
            .fontColor(Color.White)
            .enabled(!this.reviewBusy)
            .onClick(() => {
              this.submitReview();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 18, topRight: 18 })
      .position({ x: 0, y: '48%' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private MergesView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'tabs';
            this.tab = 3;
          })
        Column({ space: 2 }) {
          Text('家族合并')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text('共 ' + String(this.mergeRequests.length) + ' 个申请')
            .fontSize(10)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
        Blank()
        Button('刷新')
          .fontSize(11)
          .height(32)
          .backgroundColor('#EAF0FF')
          .fontColor('#4E7DF4')
          .onClick(() => {
            this.loadMerges();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.mergesBusy && this.mergeRequests.length === 0) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载合并申请...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.mergesError.length > 0) {
        Column({ space: 8 }) {
          Text(this.mergesError).fontSize(12).fontColor('#B4423D')
          Button('重新加载')
            .fontSize(11)
            .height(32)
            .backgroundColor('#EAF0FF')
            .fontColor('#4E7DF4')
            .onClick(() => {
              this.loadMerges();
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.mergeRequests.length === 0) {
        Column({ space: 8 }) {
          Text('暂时没有家族合并申请')
            .fontSize(15)
            .fontColor('#1C2A32')
          Text('成员加入本家族时，如果原家族有数据，会自动提交到这里')
            .fontSize(10)
            .fontColor('#89969C')
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 9 }) {
          ForEach(this.mergeRequests, (item: ApiFamilyMergeRequest) => {
            ListItem() {
              Column({ space: 6 }) {
                Row() {
                  Text(item.sourceFamilyName + '  →  ' + item.targetFamilyName)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1C2A32')
                  Blank()
                  Text(item.status === 'pending' ? '待处理' :
                    item.status === 'approved' ? '已合并' :
                    item.status === 'rejected' ? '已拒绝' : item.status)
                    .fontSize(9)
                    .fontColor(item.status === 'pending' ? '#B7791F' :
                      item.status === 'approved' ? '#2F8F67' : '#B4423D')
                    .backgroundColor(item.status === 'pending' ? '#FFF6E5' :
                      item.status === 'approved' ? '#E9F6EF' : '#FBEEEA')
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .borderRadius(6)
                }
                .width('100%')
                Text('人物 ' + String(item.personCount) + ' · 故事 ' +
                  String(item.storyCount) + ' · 照片 ' + String(item.photoCount))
                  .fontSize(11)
                  .fontColor('#6C7B82')
                Text(item.requesterName + ' 提交 · ' +
                  (item.createdAt !== undefined ? item.createdAt!.substring(0, 10) : ''))
                  .fontSize(9)
                  .fontColor('#89969C')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(13)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.openMerge(item);
              })
            }
          }, (item: ApiFamilyMergeRequest) => item.id)
        }
        .layoutWeight(1)
        .padding({ left: 14, right: 14 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private MergeDetailView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'merges';
            this.loadMerges();
          })
        Column({ space: 2 }) {
          Text('合并审核')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text(this.mergeDetail !== null
            ? this.mergeDetail!.request.sourceFamilyName + ' → ' +
              this.mergeDetail!.request.targetFamilyName
            : '正在加载')
            .fontSize(10)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.mergeDetailBusy || this.mergeDetail === null) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载合并详情...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 5 }) {
              Text(this.mergeDetail!.request.sourceFamilyName + '  →  ' +
                this.mergeDetail!.request.targetFamilyName)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1C2A32')
              Text('申请人：' + this.mergeDetail!.request.requesterName + ' · ' +
                (this.mergeDetail!.request.createdAt !== undefined
                  ? this.mergeDetail!.request.createdAt!.substring(0, 10) : ''))
                .fontSize(10)
                .fontColor('#89969C')
              Text('原家族第 ' + String(this.mergeDetail!.minGeneration) + '—' +
                String(this.mergeDetail!.maxGeneration) + ' 世')
                .fontSize(10)
                .fontColor('#6C7B82')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(13)
            .alignItems(HorizontalAlign.Start)

            if (this.mergeDetail!.request.status !== 'pending') {
              Column({ space: 4 }) {
                Text(this.mergeDetail!.request.status === 'approved' ? '已合并' : '已拒绝')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.mergeDetail!.request.status === 'approved'
                    ? '#2F8F67' : '#B4423D')
                if (this.mergeDetail!.request.reviewNote !== undefined &&
                  this.mergeDetail!.request.reviewNote!.length > 0) {
                  Text(this.mergeDetail!.request.reviewNote!)
                    .fontSize(11)
                    .fontColor('#6C7B82')
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(13)
              .alignItems(HorizontalAlign.Start)
            }

            if (this.mergeDetail!.request.status === 'pending') {
              if (this.role !== 'owner') {
                Text('只有族长可以确认或拒绝家族合并')
                  .fontSize(11)
                  .fontColor('#B7791F')
                  .padding(12)
                  .width('100%')
                  .backgroundColor('#FFF6E5')
                  .borderRadius(10)
              }
            }

            Column({ space: 6 }) {
              Row() {
                Text('人物 · ' + String(this.mergePersonIds.length) + '/' +
                  String(this.mergeDetail!.persons.length))
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                Blank()
                if (this.mergeDetail!.request.status === 'pending' && this.role === 'owner') {
                  Text(this.mergePersonIds.length === this.mergeDetail!.persons.length
                    ? '清空' : '全选')
                    .fontSize(10)
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.mergePersonIds =
                        this.mergePersonIds.length === this.mergeDetail!.persons.length
                          ? [] : this.mergeDetail!.persons.map(
                            (person: ApiMergePerson) => person.id);
                    })
                }
              }
              .width('100%')
              if (this.mergeDetail!.persons.length === 0) {
                Text('无可合并人物').fontSize(10).fontColor('#89969C')
              }
              ForEach(this.mergeDetail!.persons, (person: ApiMergePerson) => {
                Row({ space: 10 }) {
                  Text(this.mergePersonIds.includes(person.id) ? '✓' : '○')
                    .width(22)
                    .height(22)
                    .textAlign(TextAlign.Center)
                    .fontSize(11)
                    .fontColor(this.mergePersonIds.includes(person.id)
                      ? Color.White : '#89969C')
                    .backgroundColor(this.mergePersonIds.includes(person.id)
                      ? '#4E7DF4' : '#F2F5F7')
                    .borderRadius(11)
                  Column({ space: 2 }) {
                    Text(person.fullName)
                      .fontSize(12)
                      .fontColor('#1C2A32')
                    Text('第 ' + String(person.generationNo) + ' 世 · ' +
                      person.branchName)
                      .fontSize(9)
                      .fontColor('#89969C')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 5, bottom: 5 })
                .onClick(() => {
                  if (this.mergeDetail!.request.status === 'pending' &&
                    this.role === 'owner') {
                    this.toggleMergePerson(person.id);
                  }
                })
              }, (person: ApiMergePerson) => person.id)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(13)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Row() {
                Text('故事 · ' + String(this.mergeStoryIds.length) + '/' +
                  String(this.mergeDetail!.stories.length))
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                Blank()
                if (this.mergeDetail!.request.status === 'pending' && this.role === 'owner') {
                  Text(this.mergeStoryIds.length === this.mergeDetail!.stories.length
                    ? '清空' : '全选')
                    .fontSize(10)
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.mergeStoryIds =
                        this.mergeStoryIds.length === this.mergeDetail!.stories.length
                          ? [] : this.mergeDetail!.stories.map(
                            (story: ApiMergeStory) => story.id);
                    })
                }
              }
              .width('100%')
              if (this.mergeDetail!.stories.length === 0) {
                Text('无可合并故事').fontSize(10).fontColor('#89969C')
              }
              ForEach(this.mergeDetail!.stories, (story: ApiMergeStory) => {
                Row({ space: 10 }) {
                  Text(this.mergeStoryIds.includes(story.id) ? '✓' : '○')
                    .width(22)
                    .height(22)
                    .textAlign(TextAlign.Center)
                    .fontSize(11)
                    .fontColor(this.mergeStoryIds.includes(story.id)
                      ? Color.White : '#89969C')
                    .backgroundColor(this.mergeStoryIds.includes(story.id)
                      ? '#4E7DF4' : '#F2F5F7')
                    .borderRadius(11)
                  Column({ space: 2 }) {
                    Text(story.title)
                      .fontSize(12)
                      .fontColor('#1C2A32')
                      .maxLines(1)
                    Text(String(story.photoCount) + ' 张图片' +
                      (story.personName.length > 0 ? ' · ' + story.personName : ''))
                      .fontSize(9)
                      .fontColor('#89969C')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 5, bottom: 5 })
                .onClick(() => {
                  if (this.mergeDetail!.request.status === 'pending' &&
                    this.role === 'owner') {
                    this.toggleMergeStory(story.id);
                  }
                })
              }, (story: ApiMergeStory) => story.id)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(13)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Row() {
                Text('照片 · ' + String(this.mergePhotoIds.length) + '/' +
                  String(this.mergeDetail!.photos.length))
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                Blank()
                if (this.mergeDetail!.request.status === 'pending' && this.role === 'owner') {
                  Text(this.mergePhotoIds.length === this.mergeDetail!.photos.length
                    ? '清空' : '全选')
                    .fontSize(10)
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.mergePhotoIds =
                        this.mergePhotoIds.length === this.mergeDetail!.photos.length
                          ? [] : this.mergeDetail!.photos.map(
                            (photo: ApiMergePhoto) => photo.id);
                    })
                }
              }
              .width('100%')
              if (this.mergeDetail!.photos.length === 0) {
                Text('无可合并照片').fontSize(10).fontColor('#89969C')
              }
              ForEach(this.mergeDetail!.photos, (photo: ApiMergePhoto) => {
                Row({ space: 10 }) {
                  Text(this.mergePhotoIds.includes(photo.id) ? '✓' : '○')
                    .width(22)
                    .height(22)
                    .textAlign(TextAlign.Center)
                    .fontSize(11)
                    .fontColor(this.mergePhotoIds.includes(photo.id)
                      ? Color.White : '#89969C')
                    .backgroundColor(this.mergePhotoIds.includes(photo.id)
                      ? '#4E7DF4' : '#F2F5F7')
                    .borderRadius(11)
                  Column({ space: 2 }) {
                    Text(photo.caption.length > 0 ? photo.caption : '未命名照片')
                      .fontSize(12)
                      .fontColor('#1C2A32')
                      .maxLines(1)
                    Text(photo.personNames.length > 0
                      ? photo.personNames.join('、') : '未关联人物')
                      .fontSize(9)
                      .fontColor('#89969C')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 5, bottom: 5 })
                .onClick(() => {
                  if (this.mergeDetail!.request.status === 'pending' &&
                    this.role === 'owner') {
                    this.toggleMergePhoto(photo.id);
                  }
                })
              }, (photo: ApiMergePhoto) => photo.id)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(13)
            .alignItems(HorizontalAlign.Start)

            if (this.mergeDetail!.request.status === 'pending' && this.role === 'owner') {
              Column({ space: 10 }) {
                Text('合并设置')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                  .width('100%')
                if (this.mergeDetail!.branches.length > 0) {
                  Select(this.mergeDetail!.branches.map((branch: ApiBranch) => {
                    const option: SelectOption = { value: branch.name };
                    return option;
                  }))
                    .selected(this.mergeBranchIndex)
                    .value(this.mergeDetail!.branches[Math.min(
                      this.mergeBranchIndex,
                      this.mergeDetail!.branches.length - 1
                    )].name)
                    .onSelect((index: number) => {
                      this.mergeBranchIndex = index;
                    })
                    .width('100%')
                } else {
                  Text('当前家族没有可用家支').fontSize(10).fontColor('#B4423D')
                }
                Row({ space: 12 }) {
                  Text('起始世代')
                    .fontSize(12)
                    .fontColor('#1C2A32')
                  Button('−')
                    .width(30)
                    .height(30)
                    .fontSize(16)
                    .backgroundColor('#F2F5F7')
                    .fontColor('#1C2A32')
                    .onClick(() => {
                      this.mergeStartGeneration =
                        Math.max(1, this.mergeStartGeneration - 1);
                    })
                  Text('第 ' + String(this.mergeStartGeneration) + ' 世')
                    .fontSize(12)
                    .fontColor('#4E7DF4')
                  Button('+')
                    .width(30)
                    .height(30)
                    .fontSize(16)
                    .backgroundColor('#F2F5F7')
                    .fontColor('#1C2A32')
                    .onClick(() => {
                      this.mergeStartGeneration =
                        Math.min(99, this.mergeStartGeneration + 1);
                    })
                }
                .width('100%')
                Select(this.mergeAttachOptions())
                  .selected(this.mergeAttachIndex)
                  .value(this.mergeAttachOptions()[Math.min(
                    this.mergeAttachIndex,
                    this.mergeAttachOptions().length - 1
                  )].value)
                  .onSelect((index: number) => {
                    this.mergeAttachIndex = index;
                    if (index > 0 && this.tree !== null &&
                      index - 1 < this.tree.persons.length) {
                      this.mergeStartGeneration = Math.min(
                        99,
                        this.tree.persons[index - 1].generationNo + 1
                      );
                    }
                  })
                  .width('100%')
                TextArea({ placeholder: '审核备注（拒绝时必填）', text: this.mergeNote })
                  .height(80)
                  .backgroundColor('#F7F9FA')
                  .borderRadius(8)
                  .fontSize(11)
                  .onChange((value: string) => {
                    this.mergeNote = value;
                  })
                if (this.mergeError.length > 0) {
                  Text(this.mergeError)
                    .fontSize(11)
                    .fontColor('#B4423D')
                    .width('100%')
                }
                Row({ space: 10 }) {
                  Button('拒绝')
                    .layoutWeight(1)
                    .height(42)
                    .backgroundColor('#FBEEEA')
                    .fontColor('#B4423D')
                    .enabled(!this.mergeSubmitting)
                    .onClick(() => {
                      this.rejectMergeTap();
                    })
                  Button(this.mergeSubmitting ? '处理中' : '确认合并')
                    .layoutWeight(1)
                    .height(42)
                    .backgroundColor('#4E7DF4')
                    .fontColor(Color.White)
                    .enabled(!this.mergeSubmitting)
                    .onClick(() => {
                      this.approveMergeTap();
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(13)
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 28 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private DataView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'tabs';
            this.tab = 3;
          })
        Column({ space: 2 }) {
          Text('数据导入导出')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text('导出备份、生成导入码或导入旁支')
            .fontSize(10)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Text('导出完整家族数据')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text('导出家族资料、家支、人物档案、亲子/配偶关系、故事和照片元数据。照片原文件不包含在 JSON 中。')
              .fontSize(11)
              .lineHeight(18)
              .fontColor('#6C7B82')
              .width('100%')
            Button(this.exportBusy ? '正在导出...' : '选择位置并导出 JSON')
              .width('100%')
              .height(42)
              .backgroundColor('#4E7DF4')
              .fontColor(Color.White)
              .enabled(!this.exportBusy)
              .onClick(() => {
                this.exportFamilyData();
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('生成旁支导入码')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text('选择根人物，只导出该人物及其后代、配偶和内部关系。对方导入后会生成新的人物 ID。')
              .fontSize(11)
              .lineHeight(18)
              .fontColor('#6C7B82')
              .width('100%')
            Select(this.exportRootOptions())
              .selected(this.exportRootIndex)
              .value(this.exportRootOptions()[Math.min(
                this.exportRootIndex,
                this.exportRootOptions().length - 1
              )].value)
              .onSelect((index: number) => {
                this.exportRootIndex = index;
                this.exportPackage = null;
                this.exportCode = '';
              })
              .width('100%')
            Button(this.exportBusy ? '正在生成...' : '生成导入码')
              .width('100%')
              .height(40)
              .backgroundColor('#EAF0FF')
              .fontColor('#4E7DF4')
              .enabled(!this.exportBusy)
              .onClick(() => {
                this.generateImportCode();
              })
            if (this.exportCode.length > 0) {
              Column({ space: 5 }) {
                Text('导入码')
                  .fontSize(9)
                  .fontColor('#89969C')
                Text(this.exportCode)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#B4423D')
                  .letterSpacing(3)
                if (this.exportPackage !== null) {
                  Text(this.exportPackage!.sourceFamilyName + ' · ' +
                    this.exportPackage!.rootName + ' · ' +
                    String(this.exportPackage!.personCount) + ' 人')
                    .fontSize(10)
                    .fontColor('#6C7B82')
                  Text('有效期至 ' +
                    (this.exportPackage!.expiresAt !== undefined
                      ? this.exportPackage!.expiresAt!.substring(0, 10) : '—'))
                    .fontSize(9)
                    .fontColor('#89969C')
                }
                Button('复制导入码')
                  .width('100%')
                  .height(36)
                  .backgroundColor('#F2F5F7')
                  .fontColor('#1C2A32')
                  .onClick(() => {
                    this.copyExportCode();
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFF8F0')
              .borderRadius(10)
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('导入旁支数据')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text('输入对方家族生成的导入码，先预览，再选择家支和世代导入。')
              .fontSize(11)
              .lineHeight(18)
              .fontColor('#6C7B82')
              .width('100%')
            Row({ space: 8 }) {
              TextInput({ placeholder: '输入导入码', text: this.importCode })
                .layoutWeight(1)
                .height(42)
                .backgroundColor('#F7F9FA')
                .borderRadius(8)
                .fontSize(13)
                .onChange((value: string) => {
                  this.importCode = value.toUpperCase();
                  this.importPreview = null;
                })
              Button(this.importPreviewBusy ? '预览中' : '预览')
                .height(42)
                .fontSize(11)
                .backgroundColor('#4E7DF4')
                .fontColor(Color.White)
                .enabled(!this.importPreviewBusy)
                .onClick(() => {
                  this.previewImport();
                })
            }
            .width('100%')

            if (this.importPreview !== null) {
              Column({ space: 5 }) {
                Text(this.importPreview!.sourceFamilyName + ' · ' +
                  this.importPreview!.rootName)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1C2A32')
                Text(String(this.importPreview!.personCount) + ' 人 · ' +
                  String(this.importPreview!.relationshipCount) + ' 条关系')
                  .fontSize(10)
                  .fontColor('#6C7B82')
                ForEach(this.importPreview!.persons.slice(0, 8),
                  (person: ApiImportPersonPreview) => {
                    Text(person.fullName + ' · 第 ' +
                      String(person.generationNo) + ' 世 · ' + person.relation)
                      .fontSize(9)
                      .fontColor('#89969C')
                  }, (person: ApiImportPersonPreview) =>
                    person.fullName + String(person.generationNo))
                if (this.importPreview!.persons.length > 8) {
                  Text('还有 ' + String(this.importPreview!.persons.length - 8) + ' 人...')
                    .fontSize(9)
                    .fontColor('#89969C')
                }
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)

              if (this.dataBranches.length > 0) {
                Select(this.dataBranches.map((branch: ApiBranch) => {
                  const option: SelectOption = { value: branch.name };
                  return option;
                }))
                  .selected(this.importBranchIndex)
                  .value(this.dataBranches[Math.min(
                    this.importBranchIndex,
                    this.dataBranches.length - 1
                  )].name)
                  .onSelect((index: number) => {
                    this.importBranchIndex = index;
                  })
                  .width('100%')
              } else {
                Text('当前家族没有可用家支').fontSize(10).fontColor('#B4423D')
              }

              Row({ space: 12 }) {
                Text('根人物世代')
                  .fontSize(12)
                  .fontColor('#1C2A32')
                Button('−')
                  .width(30)
                  .height(30)
                  .fontSize(16)
                  .backgroundColor('#F2F5F7')
                  .fontColor('#1C2A32')
                  .onClick(() => {
                    this.importGeneration = Math.max(1, this.importGeneration - 1);
                  })
                Text('第 ' + String(this.importGeneration) + ' 世')
                  .fontSize(12)
                  .fontColor('#4E7DF4')
                Button('+')
                  .width(30)
                  .height(30)
                  .fontSize(16)
                  .backgroundColor('#F2F5F7')
                  .fontColor('#1C2A32')
                  .onClick(() => {
                    this.importGeneration = Math.min(99, this.importGeneration + 1);
                  })
              }
              .width('100%')

              Select(this.importParentOptions())
                .selected(this.importParentIndex)
                .value(this.importParentOptions()[Math.min(
                  this.importParentIndex,
                  this.importParentOptions().length - 1
                )].value)
                .onSelect((index: number) => {
                  this.importParentIndex = index;
                  if (index > 0 && this.tree !== null &&
                    index - 1 < this.tree.persons.length) {
                    this.importGeneration = Math.min(
                      99,
                      this.tree.persons[index - 1].generationNo + 1
                    );
                  }
                })
                .width('100%')

              if (this.importParentIndex > 0) {
                Row({ space: 8 }) {
                  Button('作为父亲')
                    .layoutWeight(1)
                    .height(32)
                    .fontSize(11)
                    .backgroundColor(this.importParentRole === 'father'
                      ? '#EAF0FF' : '#F2F5F7')
                    .fontColor(this.importParentRole === 'father'
                      ? '#4E7DF4' : '#6C7B82')
                    .onClick(() => {
                      this.importParentRole = 'father';
                    })
                  Button('作为母亲')
                    .layoutWeight(1)
                    .height(32)
                    .fontSize(11)
                    .backgroundColor(this.importParentRole === 'mother'
                      ? '#EAF0FF' : '#F2F5F7')
                    .fontColor(this.importParentRole === 'mother'
                      ? '#4E7DF4' : '#6C7B82')
                    .onClick(() => {
                      this.importParentRole = 'mother';
                    })
                }
                .width('100%')
              }

              Button(this.importBusy ? '正在导入...' : '确认导入')
                .width('100%')
                .height(44)
                .backgroundColor('#3DA77C')
                .fontColor(Color.White)
                .enabled(!this.importBusy)
                .onClick(() => {
                  this.doImport();
                })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          if (this.dataError.length > 0) {
            Text(this.dataError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
          if (this.dataBusy) {
            Text('正在加载家支...')
              .fontSize(10)
              .fontColor('#89969C')
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private FamilyCenterView() {
    Column() {
      Row() {
        Button('‹')
          .width(38)
          .height(38)
          .backgroundColor('#FFFFFF')
          .fontColor('#1C2A32')
          .fontSize(22)
          .borderRadius(19)
          .onClick(() => {
            this.page = 'tabs';
            this.tab = 3;
          })
        Column({ space: 2 }) {
          Text('账号与家庭')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text(this.familyName + ' · ' + this.displayName)
            .fontSize(10)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      if (this.familyCenterBusy) {
        Row() {
          LoadingProgress()
            .width(18)
            .height(18)
            .color('#4E7DF4')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 4, bottom: 4 })
      }

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              Column()
                .width(3)
                .height(15)
                .backgroundColor('#4E7DF4')
                .borderRadius(3)
              Text('我的家族')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1C2A32')
            }
            .width('100%')
            if (this.familyEntries.length === 0) {
              Text('暂无其他家族')
                .fontSize(11)
                .fontColor('#89969C')
            }
            ForEach(this.familyEntries, (entry: ApiFamilyEntry) => {
              Row({ space: 10 }) {
                Text(entry.family.name.substring(0, 1))
                  .width(38)
                  .height(38)
                  .textAlign(TextAlign.Center)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#B4423D')
                  .backgroundColor('#FBEEEA')
                  .borderRadius(11)
                Column({ space: 2 }) {
                  Text(entry.family.name)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1C2A32')
                  Text(entry.family.surname + '氏 · ' +
                    String(entry.family.memberCount) + ' 人 · ' +
                    (entry.membership.role === 'owner' ? '族长' :
                      entry.membership.role === 'admin' ? '管理员' : '成员'))
                    .fontSize(9)
                    .fontColor('#89969C')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (entry.family.id === this.familyId) {
                  Text('当前')
                    .fontSize(9)
                    .fontColor('#2F8F67')
                    .backgroundColor('#E8F6EF')
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .borderRadius(6)
                } else {
                  Button('切换')
                    .fontSize(10)
                    .height(30)
                    .backgroundColor('#EAF0FF')
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.switchToFamily(entry.family.id);
                    })
                }
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F7F9FA')
              .borderRadius(10)
            }, (entry: ApiFamilyEntry) => entry.family.id)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('加入其他家族')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            Text('输入对方族长分享的邀请码；原家族有数据时会自动生成合并申请。')
              .fontSize(10)
              .lineHeight(16)
              .fontColor('#6C7B82')
              .width('100%')
            Row({ space: 8 }) {
              TextInput({ placeholder: '邀请码', text: this.familyJoinCode })
                .layoutWeight(1)
                .height(40)
                .backgroundColor('#F7F9FA')
                .borderRadius(8)
                .fontSize(12)
                .onChange((value: string) => {
                  this.familyJoinCode = value.toUpperCase();
                })
              Button('加入')
                .height(40)
                .fontSize(11)
                .backgroundColor('#3DA77C')
                .fontColor(Color.White)
                .onClick(() => {
                  this.joinFamilyByCode();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 8 }) {
            Text('创建新家族')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            TextInput({ placeholder: '家族名称', text: this.newFamilyName })
              .height(40)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.newFamilyName = value;
              })
            TextInput({ placeholder: '姓氏', text: this.newFamilySurname })
              .height(40)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.newFamilySurname = value;
              })
            TextInput({ placeholder: '家训（可选）', text: this.newFamilyMotto })
              .height(40)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.newFamilyMotto = value;
              })
            Button('创建家族')
              .width('100%')
              .height(40)
              .fontSize(11)
              .backgroundColor('#4E7DF4')
              .fontColor(Color.White)
              .onClick(() => {
                this.createNewFamily();
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          if (this.canDelete()) {
            Column({ space: 8 }) {
              Row() {
                Text('邀请码')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1C2A32')
                Blank()
                Button('新建')
                  .fontSize(10)
                  .height(28)
                  .backgroundColor('#EAF0FF')
                  .fontColor('#4E7DF4')
                  .onClick(() => {
                    this.createFamilyInvite();
                  })
              }
              .width('100%')
              if (this.familyInvites.length === 0) {
                Text('还没有邀请码')
                  .fontSize(10)
                  .fontColor('#89969C')
              }
              ForEach(this.familyInvites, (invite: ApiInvite) => {
                Row({ space: 8 }) {
                  Text(invite.code)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#B4423D')
                    .letterSpacing(2)
                  Column({ space: 1 }) {
                    Text(invite.status + ' · 已用 ' +
                      String(invite.usedCount) + '/' + String(invite.maxUses))
                      .fontSize(8)
                      .fontColor('#89969C')
                    Text(invite.expiresAt !== undefined
                      ? '有效期至 ' + invite.expiresAt!.substring(0, 10) : '')
                      .fontSize(8)
                      .fontColor('#89969C')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text('复制')
                    .fontSize(10)
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.copyText(invite.code);
                      this.toast('邀请码已复制');
                    })
                }
                .width('100%')
                .padding({ top: 4, bottom: 4 })
              }, (invite: ApiInvite) => invite.id)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(13)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Text('家族账号')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1C2A32')
                .width('100%')
              ForEach(this.familyAccounts, (account: ApiFamilyAccount) => {
                Row({ space: 8 }) {
                  Text(account.displayName)
                    .fontSize(12)
                    .fontColor('#1C2A32')
                  Text('@' + account.loginName)
                    .fontSize(9)
                    .fontColor('#89969C')
                  Blank()
                  Text(account.role === 'owner' ? '族长' :
                    account.role === 'admin' ? '管理员' : '成员')
                    .fontSize(9)
                    .fontColor('#4E7DF4')
                  if (this.role === 'owner' && account.role !== 'owner') {
                    Text('转让')
                      .fontSize(9)
                      .fontColor('#B7791F')
                      .onClick(() => {
                        this.confirmTransferOwner(account);
                      })
                  }
                  Text(account.personName.length > 0 ? account.personName : '未绑定')
                    .fontSize(9)
                    .fontColor('#89969C')
                }
                .width('100%')
                .padding({ top: 4, bottom: 4 })
              }, (account: ApiFamilyAccount) => account.userId)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Color.White)
            .borderRadius(13)
            .alignItems(HorizontalAlign.Start)
          }

          Column({ space: 8 }) {
            Text('账号安全')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C2A32')
              .width('100%')
            TextInput({ placeholder: '当前密码', text: this.accountOldPassword })
              .height(40)
              .type(InputType.Password)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.accountOldPassword = value;
              })
            TextInput({ placeholder: '新密码（至少 8 位）', text: this.accountNewPassword })
              .height(40)
              .type(InputType.Password)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.accountNewPassword = value;
              })
            Button('修改密码')
              .width('100%')
              .height(38)
              .fontSize(11)
              .backgroundColor('#EAF0FF')
              .fontColor('#4E7DF4')
              .onClick(() => {
                this.changeAccountPassword();
              })
            Text('绑定手机号')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C2A32')
              .width('100%')
              .margin({ top: 4 })
            TextInput({ placeholder: '手机号，例如 +8613800000000', text: this.bindPhoneNumber })
              .height(40)
              .backgroundColor('#F7F9FA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.bindPhoneNumber = value;
              })
            Row({ space: 8 }) {
              TextInput({ placeholder: '6 位验证码', text: this.bindPhoneCode })
                .layoutWeight(1)
                .height(40)
                .backgroundColor('#F7F9FA')
                .borderRadius(8)
                .fontSize(12)
                .onChange((value: string) => {
                  this.bindPhoneCode = value;
                })
              Button('发送')
                .height(40)
                .fontSize(10)
                .backgroundColor('#EAF0FF')
                .fontColor('#4E7DF4')
                .onClick(() => {
                  this.sendBindPhoneCode();
                })
            }
            .width('100%')
            Button('绑定手机号')
              .width('100%')
              .height(38)
              .fontSize(11)
              .backgroundColor('#E8F6EF')
              .fontColor('#2F8F67')
              .onClick(() => {
                this.bindMyPhone();
              })
            Button('生成一次性找回码')
              .width('100%')
              .height(38)
              .fontSize(11)
              .backgroundColor('#FFF4DF')
              .fontColor('#B7791F')
              .onClick(() => {
                this.generateRecoveryCode();
              })
            if (this.recoveryCodeDisplay.length > 0) {
              Text(this.recoveryCodeDisplay)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#B4423D')
                .letterSpacing(2)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(8)
                .backgroundColor('#FFF8F0')
                .borderRadius(8)
            }
            TextInput({ placeholder: '输入密码以注销账号', text: this.accountDeletePassword })
              .height(40)
              .type(InputType.Password)
              .backgroundColor('#FBEEEA')
              .borderRadius(8)
              .fontSize(12)
              .onChange((value: string) => {
                this.accountDeletePassword = value;
              })
            Button('注销账号')
              .width('100%')
              .height(38)
              .fontSize(11)
              .backgroundColor('#FBEEEA')
              .fontColor('#B4423D')
              .onClick(() => {
                this.confirmDeleteAccount();
              })
            if (this.role === 'owner') {
              Text('归档当前家族（同时注销账号）')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor('#B4423D')
                .width('100%')
                .margin({ top: 8 })
              TextInput({ placeholder: '输入家族全名确认', text: this.archiveConfirmName })
                .height(40)
                .backgroundColor('#FBEEEA')
                .borderRadius(8)
                .fontSize(12)
                .onChange((value: string) => {
                  this.archiveConfirmName = value;
                })
              TextInput({ placeholder: '登录密码', text: this.archivePassword })
                .height(40)
                .type(InputType.Password)
                .backgroundColor('#FBEEEA')
                .borderRadius(8)
                .fontSize(12)
                .onChange((value: string) => {
                  this.archivePassword = value;
                })
              Button('归档家族并注销账号')
                .width('100%')
                .height(38)
                .fontSize(11)
                .backgroundColor('#B4423D')
                .fontColor(Color.White)
                .onClick(() => {
                  this.confirmArchiveFamily();
                })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(13)
          .alignItems(HorizontalAlign.Start)

          if (this.familyCenterError.length > 0) {
            Text(this.familyCenterError)
              .fontSize(11)
              .fontColor('#B4423D')
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.booting) {
        this.LoadingView()
      } else if (!this.loggedIn) {
        if (this.authPage === 'register') {
          this.RegisterView()
        } else if (this.authPage === 'phone') {
          this.PhoneLoginView()
        } else if (this.authPage === 'reset') {
          this.ResetPasswordView()
        } else {
          this.LoginView()
        }
      } else if (this.page === 'detail') {
        this.DetailView()
      } else if (this.page === 'add') {
        this.AddPersonView()
      } else if (this.page === 'album') {
        this.AlbumView()
      } else if (this.page === 'photoForm') {
        this.PhotoFormView()
      } else if (this.page === 'members') {
        this.MembersView()
      } else if (this.page === 'avatar') {
        this.AvatarCropView()
      } else if (this.page === 'addRelation') {
        this.AddRelationView()
      } else if (this.page === 'editPerson') {
        this.EditPersonView()
      } else if (this.page === 'profileRequest') {
        this.ProfileRequestView()
      } else if (this.page === 'stories') {
        this.StoriesView()
      } else if (this.page === 'storyDetail') {
        this.StoryDetailView()
      } else if (this.page === 'storyEdit') {
        this.StoryEditView()
      } else if (this.page === 'inbox') {
        this.InboxView()
      } else if (this.page === 'merges') {
        this.MergesView()
      } else if (this.page === 'mergeDetail') {
        this.MergeDetailView()
      } else if (this.page === 'data') {
        this.DataView()
      } else if (this.page === 'familyCenter') {
        this.FamilyCenterView()
      } else {
        this.TabsView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7F8')
  }
}
