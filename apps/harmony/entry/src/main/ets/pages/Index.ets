import { promptAction } from '@kit.ArkUI';
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
  ApiMeResult,
  ApiNotification,
  ApiPerson,
  ApiPhoto,
  ApiRelative,
  ApiStory,
  ApiTree
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

  @State private displayName: string = '';
  @State private currentUserId: string = '';
  @State private role: string = '';
  @State private linkedPersonId: string = '';
  @State private familyName: string = '';
  @State private familySurname: string = '';
  @State private familyMotto: string = '';
  @State private memberCount: number = 0;
  @State private branchCount: number = 0;
  @State private myGeneration: string = '';

  @State private tree: ApiTree | null = null;
  @State private layout: TreeLayoutResult | null = null;
  @State private activities: ApiActivity[] = [];
  @State private anniversaries: ApiAnniversary[] = [];
  @State private query: string = '';
  @State private selected: ApiPerson | null = null;
  @State private detailBusy: boolean = false;

  @State private albumPhotos: ApiPhoto[] = [];
  @State private albumBusy: boolean = false;
  @State private albumError: string = '';
  @State private albumFilterIndex: number = 0;
  @State private viewerPhoto: ApiPhoto | null = null;
  @State private viewerBusy: boolean = false;

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

  @State private inboxTab: number = 0;
  @State private notifications: ApiNotification[] = [];
  @State private unreadCount: number = 0;
  @State private inboxBusy: boolean = false;
  @State private inboxError: string = '';
  @State private editReviews: ApiEditRequest[] = [];
  @State private bindingReviews: ApiBindingRequest[] = [];
  @State private reviewKind: string = '';
  @State private reviewId: string = '';
  @State private reviewLabel: string = '';
  @State private reviewApprove: boolean = true;
  @State private reviewNote: string = '';
  @State private reviewError: string = '';
  @State private reviewBusy: boolean = false;

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
      this.albumBusy = true;
      const personId = this.albumPersonId();
      let uploaded = 0;
      for (const uri of result.photoUris) {
        await this.api.uploadPhoto(uri, personId);
        uploaded++;
      }
      await this.loadPhotos();
      this.toast('已上传 ' + uploaded + ' 张照片');
    } catch (error) {
      this.toast(this.errorText(error));
    } finally {
      this.albumBusy = false;
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
    this.storyTitle = '';
    this.storyBody = '';
    this.storyPersonIndex = 0;
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
    const remaining = 9 - this.storyPhotoUris.length;
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
      const photoIds: string[] = [];
      for (let i = 0; i < this.storyPhotoUris.length; i++) {
        this.storyStatus = '正在上传图片 ' + String(i + 1) + '/' +
          String(this.storyPhotoUris.length);
        const uploaded = await this.api.uploadPhoto(this.storyPhotoUris[i], personId);
        photoIds.push(uploaded.id);
      }
      this.storyStatus = '正在保存故事...';
      await this.api.createStory(title, body, personId, photoIds);
      await this.loadStories();
      this.page = 'stories';
      this.toast('故事已发布');
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
      }
    }
  }

  private startReview(kind: string, id: string, label: string, approve: boolean): void {
    this.reviewKind = kind;
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

  private filteredPersons(): ApiPerson[] {
    if (this.tree === null) return [];
    const key = this.query.trim();
    const list = this.tree.persons.filter((person: ApiPerson) => {
      return key.length === 0 || person.fullName.includes(key) ||
        person.generationLabel.includes(key);
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
        .opacity(0.45)
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 6 }) {
            Text('家族族谱')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
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
    .backgroundColor('#F2F4F5')
  }

  @Builder
  private TabsView() {
    Column() {
      if (this.tab === 0) {
        this.HomeView()
      } else if (this.tab === 1) {
        this.TreeView()
      } else if (this.tab === 2) {
        this.MembersView()
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
      this.NavItem('首页', 0, '⌂')
      this.NavItem('族谱树', 1, '⑂')
      this.NavItem('成员', 2, '☷')
      this.NavItem('我的', 3, '◉')
    }
    .width('100%')
    .height(64)
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E7ECEE' })
    .padding({ left: 8, right: 8 })
  }

  @Builder
  private NavItem(label: string, index: number, icon: string) {
    Column({ space: 3 }) {
      Text(icon)
        .fontSize(19)
        .fontColor(this.tab === index ? '#4E7DF4' : '#89969C')
      Text(label)
        .fontSize(10)
        .fontColor(this.tab === index ? '#4E7DF4' : '#89969C')
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
    })
  }

  @Builder
  private HomeView() {
    Scroll() {
      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image($r('app.media.hero_ink'))
            .width('100%')
            .height(190)
            .objectFit(ImageFit.Cover)
          Column({ space: 5 }) {
            Text(this.displayName + '  ·  ' + (this.role === 'owner' ? '族长' : '成员'))
              .fontSize(13)
              .fontColor('#F7F3EA')
            Text(this.familyName)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFDF7')
            Text(this.familyMotto)
              .fontSize(12)
              .fontColor('#F1EAD9')
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, bottom: 16 })
        }
        .width('100%')
        .height(190)
        .borderRadius(16)
        .clip(true)

        Row() {
          this.StatCell(String(this.memberCount), '家族成员')
          this.StatCell(String(this.branchCount), '家支')
          this.StatCell(this.myGeneration.length > 0 ? this.myGeneration : '—', '我的世代')
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .backgroundColor(Color.White)
        .borderRadius(15)

        Column({ space: 10 }) {
          Row() {
            this.QuickTile('族谱树', '查看家族关系', '#4E7DF4', 1)
            this.QuickTile('成员查询', '查找家族成员', '#3DA77C', 2)
          }
          Row() {
            this.QuickTile('家族相册', '珍贵家族影像', '#35ABC0', -3)
            this.QuickTile('家族故事', '记录家族记忆', '#B45D5A', -4)
          }
          Row() {
            this.QuickTile('新增成员', '录入正式档案', '#E4A636', -1)
            this.QuickTile(
              '消息中心',
              this.unreadCount > 0 ? '未读 ' + String(this.unreadCount) + ' 条' : '审核与通知',
              '#6C7B82',
              -5
            )
          }
        }
        .width('100%')
        .padding(10)
        .backgroundColor(Color.White)
        .borderRadius(15)

        Column({ space: 10 }) {
          Row() {
            Text('最近的生日与祭日')
              .fontSize(15)
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
          Row() {
            Text('最新动态')
              .fontSize(15)
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
      .padding({ left: 14, right: 14, top: 12, bottom: 18 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
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
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text(this.familyName + ' · 共 ' + this.memberCount + ' 人')
            .fontSize(11)
            .fontColor('#89969C')
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Button('刷新')
          .fontSize(11)
          .height(30)
          .backgroundColor('#EAF0FF')
          .fontColor('#4E7DF4')
          .onClick(() => {
            this.refreshAll();
          })
        Button('新增')
          .fontSize(11)
          .height(30)
          .margin({ left: 6 })
          .backgroundColor('#4E7DF4')
          .fontColor(Color.White)
          .onClick(() => {
            this.openAdd();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      if (this.layout === null) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color('#4E7DF4')
          Text('正在加载族谱...').fontSize(12).fontColor('#89969C')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Scroll() {
            Stack() {
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
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }
        .scrollable(ScrollDirection.Vertical)
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      Text('左右/上下拖动查看 · 点击人物查看档案')
        .fontSize(10)
        .fontColor('#89969C')
        .padding({ top: 6, bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private PersonCard(box: PersonBox) {
    Column({ space: 3 }) {
      Text(box.person.fullName)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(box.person.id === this.linkedPersonId ? '#4E7DF4' : '#1C2A32')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(box.person.generationLabel)
        .fontSize(9)
        .fontColor('#89969C')
        .maxLines(1)
      Text(box.person.gender === 'female' ? '女' : box.person.gender === 'male' ? '男' : '—')
        .fontSize(9)
        .fontColor(box.person.lifeStatus === 'living' ? '#3DA77C' : '#89969C')
    }
    .width(box.width)
    .height(box.height)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({
      width: box.person.id === this.linkedPersonId ? 1.6 : 1,
      color: box.person.id === this.linkedPersonId ? '#4E7DF4' : '#E4EAEC'
    })
    .position({ x: box.x, y: box.y })
    .onClick(() => {
      this.openPerson(box.person.id);
    })
  }

  @Builder
  private MembersView() {
    Column() {
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
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      TextInput({ placeholder: '搜索姓名或世代', text: this.query })
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
        Column({ space: 5 }) {
          Text('我的')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C2A32')
          Text(this.displayName)
            .fontSize(14)
            .fontColor('#1C2A32')
          Text(this.familyName + ' · ' + (this.role === 'owner' ? '族长' : this.role))
            .fontSize(11)
            .fontColor('#89969C')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 16, bottom: 6 })

        Column({ space: 10 }) {
          this.SettingsRow('服务器', this.savedServer)
          this.SettingsRow('登录账号', this.loginName)
          this.SettingsRow('我的世代', this.myGeneration.length > 0 ? this.myGeneration : '未绑定')
          this.SettingsRow('家族人数', String(this.memberCount))
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
          Text('这是原生 ArkTS/ArkUI 版本，已接入登录、首页、族谱树、成员查询、人物档案、新增人物和删除人物。')
            .fontSize(11)
            .lineHeight(18)
            .fontColor('#6C7B82')
          Text('照片、故事、家族合并、头像和资料审核等能力仍在逐步对齐 Android 版。')
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
            Column({ space: 10 }) {
              Row({ space: 14 }) {
                Stack() {
                  if (this.selected!.hasAvatar === true) {
                    AuthImage({
                      path: '/api/v1/persons/' + this.selected!.id +
                        '/avatar?v=' + String(this.avatarRevision),
                      radius: 18
                    })
                  } else {
                    Text(this.selected!.fullName.substring(0, 1))
                      .width(86)
                      .height(86)
                      .textAlign(TextAlign.Center)
                      .fontSize(30)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#B4423D')
                      .backgroundColor('#FBEEEA')
                      .borderRadius(18)
                  }
                }
                .width(86)
                .height(86)

                Column({ space: 5 }) {
                  Text(this.selected!.fullName)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1C2A32')
                  Row({ space: 8 }) {
                    Text(this.selected!.generationLabel)
                      .fontSize(10)
                      .fontColor('#4E7DF4')
                      .backgroundColor('#EAF0FF')
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .borderRadius(8)
                    Text(this.selected!.lifeStatus === 'living' ? '在世' : '已故')
                      .fontSize(10)
                      .fontColor(this.selected!.lifeStatus === 'living' ? '#3DA77C' : '#89969C')
                      .backgroundColor(this.selected!.lifeStatus === 'living' ? '#E9F6EF' : '#EDF2F5')
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .borderRadius(8)
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')

              if (this.canEditAvatar()) {
                Row({ space: 8 }) {
                  Button(this.selected!.hasAvatar === true ? '更换头像' : '设置头像')
                    .fontSize(11)
                    .height(32)
                    .backgroundColor('#EAF0FF')
                    .fontColor('#4E7DF4')
                    .onClick(() => {
                      this.pickAvatar();
                    })
                  if (this.selected!.hasAvatar === true) {
                    Button('移除头像')
                      .fontSize(11)
                      .height(32)
                      .backgroundColor('#FBEEEA')
                      .fontColor('#B4423D')
                      .onClick(() => {
                        this.confirmDeleteAvatar();
                      })
                  }
                }
                .width('100%')
              }

              Text('生卒：' + (this.selected!.birth !== undefined && this.selected!.birth!.text !== undefined
                ? this.selected!.birth!.text : '未记录'))
                .fontSize(12)
                .fontColor('#6C7B82')
              Text('籍贯：' + (this.selected!.birthPlace !== undefined && this.selected!.birthPlace!.length > 0
                ? this.selected!.birthPlace! : '未记录'))
                .fontSize(12)
                .fontColor('#6C7B82')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(18)
            .backgroundColor(Color.White)
            .borderRadius(15)

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
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C2A32')
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
            Blank()
            Text('›')
              .fontSize(17)
              .fontColor('#C1CBCF')
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .onClick(() => {
            this.openPerson(item.personId);
          })
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
    }
    .width('100%')
    .height('100%')
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
        Text('写家族故事')
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
              Text(this.storyPhotoUris.length + '/9')
                .fontSize(10)
                .fontColor('#89969C')
            }
            .width('100%')
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
          if (this.canDelete()) {
            this.InboxTabButton('审核', 1)
          }
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
        } else {
          Scroll() {
            Column({ space: 14 }) {
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

  build() {
    Stack() {
      if (this.booting) {
        this.LoadingView()
      } else if (!this.loggedIn) {
        this.LoginView()
      } else if (this.page === 'detail') {
        this.DetailView()
      } else if (this.page === 'add') {
        this.AddPersonView()
      } else if (this.page === 'album') {
        this.AlbumView()
      } else if (this.page === 'avatar') {
        this.AvatarCropView()
      } else if (this.page === 'stories') {
        this.StoriesView()
      } else if (this.page === 'storyDetail') {
        this.StoryDetailView()
      } else if (this.page === 'storyEdit') {
        this.StoryEditView()
      } else if (this.page === 'inbox') {
        this.InboxView()
      } else {
        this.TabsView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F4F5')
  }
}
