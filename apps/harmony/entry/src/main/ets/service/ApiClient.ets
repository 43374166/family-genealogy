import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import {
  ApiActivityPage,
  ApiAnniversaryPage,
  ApiBranchPage,
  ApiEditRequest,
  ApiEditRequestPage,
  ApiFamily,
  ApiFamilyAccountPage,
  ApiFamilyListPage,
  ApiFamilyMergeDetail,
  ApiFamilyMergeRequest,
  ApiFamilyMergeRequestPage,
  ApiFamilyMergeResult,
  ApiImportPackage,
  ApiImportPreview,
  ApiImportResult,
  ApiInvite,
  ApiInvitePage,
  ApiJoinResult,
  ApiLoginResult,
  ApiMeResult,
  ApiNotificationPage,
  ApiPerson,
  ApiPersonPage,
  ApiPhoto,
  ApiPhotoPage,
  ApiProblem,
  ApiRegistration,
  ApiStory,
  ApiStoryPage,
  ApiTree,
  ApiBindingRequest,
  ApiBindingRequestPage,
  UpdatePersonPayload
} from '../model/Types';

export class ApiClient {
  private baseUrl: string = 'https://family.fishdream.xyz:10443';
  private token: string = '';

  setSession(serverUrl: string, token: string): void {
    this.baseUrl = this.normalizeServer(serverUrl);
    this.token = token;
  }

  setServer(serverUrl: string): void {
    this.baseUrl = this.normalizeServer(serverUrl);
  }

  private normalizeServer(serverUrl: string): string {
    let value = serverUrl.trim();
    if (value.length === 0) {
      value = 'https://family.fishdream.xyz:10443';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://' + value;
    }
    return value;
  }

  private async request(
    method: http.RequestMethod,
    path: string,
    body?: Object
  ): Promise<string> {
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (this.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + this.token;
    }
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 12000,
      readTimeout: 25000
    };
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }
    try {
      const response = await client.request(this.baseUrl + path, options);
      const text = response.result as string;
      if (response.responseCode >= 400) {
        let message = '请求失败（' + response.responseCode + '）';
        try {
          const problem = JSON.parse(text) as ApiProblem;
          if (problem.detail !== undefined && problem.detail.length > 0) {
            message = problem.detail;
          } else if (problem.title !== undefined && problem.title.length > 0) {
            message = problem.title;
          }
        } catch (_) {
          // Keep the HTTP fallback message when the body is not JSON.
        }
        throw new Error(message);
      }
      return text;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      const systemError = error as BusinessError;
      throw new Error(systemError.message || '无法连接服务器，请检查地址和网络');
    } finally {
      client.destroy();
    }
  }

  async login(loginName: string, password: string): Promise<ApiLoginResult> {
    const body: Record<string, string> = {
      'loginName': loginName,
      'password': password
    };
    const text = await this.request(http.RequestMethod.POST, '/api/v1/auth/login', body);
    const result = JSON.parse(text) as ApiLoginResult;
    this.token = result.token;
    return result;
  }

  async me(): Promise<ApiMeResult> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/me');
    return JSON.parse(text) as ApiMeResult;
  }

  async tree(): Promise<ApiTree> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/tree');
    return JSON.parse(text) as ApiTree;
  }

  async person(personId: string): Promise<ApiPerson> {
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/persons/' + encodeURIComponent(personId)
    );
    return JSON.parse(text) as ApiPerson;
  }

  async persons(query: string, generation: number): Promise<ApiPersonPage> {
    let path = '/api/v1/persons?limit=100';
    if (query.trim().length > 0) {
      path += '&query=' + encodeURIComponent(query.trim());
    }
    if (generation > 0) {
      path += '&generation=' + generation;
    }
    const text = await this.request(http.RequestMethod.GET, path);
    return JSON.parse(text) as ApiPersonPage;
  }

  async activity(): Promise<ApiActivityPage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/activity?limit=8');
    return JSON.parse(text) as ApiActivityPage;
  }

  async anniversaries(): Promise<ApiAnniversaryPage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/anniversaries?days=60');
    return JSON.parse(text) as ApiAnniversaryPage;
  }

  async branches(): Promise<ApiBranchPage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/branches');
    return JSON.parse(text) as ApiBranchPage;
  }

  async createPerson(
    surname: string,
    givenName: string,
    gender: string,
    generationNo: number,
    branchId: string
  ): Promise<ApiPerson> {
    const body: Record<string, string | number> = {
      'surname': surname,
      'givenName': givenName,
      'gender': gender,
      'generationNo': generationNo,
      'branchId': branchId
    };
    const text = await this.request(http.RequestMethod.POST, '/api/v1/persons', body);
    return JSON.parse(text) as ApiPerson;
  }

  async deletePerson(personId: string): Promise<void> {
    await this.request(
      http.RequestMethod.DELETE,
      '/api/v1/persons/' + encodeURIComponent(personId)
    );
  }

  async photos(personId?: string): Promise<ApiPhotoPage> {
    let path = '/api/v1/photos';
    if (personId !== undefined && personId.length > 0) {
      path += '?personId=' + encodeURIComponent(personId);
    }
    const text = await this.request(http.RequestMethod.GET, path);
    return JSON.parse(text) as ApiPhotoPage;
  }

  async photosByPersons(personIds: string[]): Promise<ApiPhotoPage> {
    if (personIds.length === 0) return await this.photos();
    const query = personIds.map((id: string) => encodeURIComponent(id)).join(',');
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/photos?personIds=' + query
    );
    return JSON.parse(text) as ApiPhotoPage;
  }

  async updatePhoto(
    photoId: string,
    personIds: string[],
    caption: string,
    takenAt: string
  ): Promise<ApiPhoto> {
    const payload: UpdatePhotoPayload = {
      personId: personIds.length > 0 ? personIds[0] : '',
      personIds: personIds,
      caption: caption,
      takenAt: takenAt
    };
    const text = await this.request(
      http.RequestMethod.PATCH,
      '/api/v1/photos/' + encodeURIComponent(photoId),
      payload
    );
    return JSON.parse(text) as ApiPhoto;
  }

  async bytes(path: string): Promise<ArrayBuffer> {
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Accept': 'image/*'
    };
    if (this.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + this.token;
    }
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: headers,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 12000,
      readTimeout: 25000
    };
    try {
      const response = await client.request(this.baseUrl + path, options);
      if (response.responseCode >= 400) {
        throw new Error('图片加载失败（' + response.responseCode + '）');
      }
      return response.result as ArrayBuffer;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      const systemError = error as BusinessError;
      throw new Error(systemError.message || '图片加载失败');
    } finally {
      client.destroy();
    }
  }

  private fileBuffer(uri: string): ArrayBuffer {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      return buffer;
    } finally {
      fs.closeSync(file);
    }
  }

  private filenameFromUri(uri: string): string {
    let filename = uri.substring(uri.lastIndexOf('/') + 1);
    try {
      filename = decodeURIComponent(filename);
    } catch (_) {
      // Keep the raw URI name when decoding fails.
    }
    if (filename.length === 0) {
      filename = 'photo-' + Date.now() + '.jpg';
    }
    if (!filename.includes('.')) {
      filename += '.jpg';
    }
    return filename;
  }

  private mimeForFilename(filename: string): string {
    const lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  private async uploadMultipart(
    path: string,
    uri: string,
    fields: Record<string, string>
  ): Promise<string> {
    const filename = this.filenameFromUri(uri);
    const contentType = this.mimeForFilename(filename);
    const buffer = this.fileBuffer(uri);
    return await this.uploadMultipartData(path, buffer, filename, contentType, fields);
  }

  private async uploadMultipartData(
    path: string,
    buffer: ArrayBuffer,
    filename: string,
    contentType: string,
    fields: Record<string, string>
  ): Promise<string> {
    if (buffer.byteLength > 8 * 1024 * 1024) {
      throw new Error('图片不能超过 8 MB');
    }
    const formData: http.MultiFormData[] = [];
    const keys = Object.keys(fields);
    for (const key of keys) {
      formData.push({
        name: key,
        contentType: 'text/plain',
        data: fields[key]
      });
    }
    formData.push({
      name: 'file',
      contentType: contentType,
      remoteFileName: filename,
      data: buffer
    });
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Content-Type': 'multipart/form-data'
    };
    if (this.token.length > 0) {
      headers['Authorization'] = 'Bearer ' + this.token;
    }
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      multiFormDataList: formData,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 60000
    };
    try {
      const response = await client.request(this.baseUrl + path, options);
      const text = response.result as string;
      if (response.responseCode >= 400) {
        let message = '上传失败（' + response.responseCode + '）';
        try {
          const problem = JSON.parse(text) as ApiProblem;
          if (problem.detail !== undefined && problem.detail.length > 0) {
            message = problem.detail;
          }
        } catch (_) {
          // Keep the status fallback.
        }
        throw new Error(message);
      }
      return text;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      const systemError = error as BusinessError;
      throw new Error(systemError.message || '上传失败，请检查网络');
    } finally {
      client.destroy();
    }
  }

  async uploadPhoto(uri: string, personId?: string, caption: string = ''): Promise<ApiPhoto> {
    const personIds: string[] = personId !== undefined && personId.length > 0
      ? [personId] : [];
    return await this.uploadPhotoTagged(uri, personIds, caption, '');
  }

  async uploadPhotoTagged(
    uri: string,
    personIds: string[],
    caption: string,
    takenAt: string
  ): Promise<ApiPhoto> {
    const fields: Record<string, string> = {};
    if (personIds.length > 0) {
      fields['personId'] = personIds[0];
      fields['personIds'] = personIds.join(',');
    }
    if (caption.length > 0) {
      fields['caption'] = caption;
    }
    if (takenAt.length > 0) {
      fields['takenAt'] = takenAt;
    }
    const text = await this.uploadMultipart('/api/v1/photos', uri, fields);
    return JSON.parse(text) as ApiPhoto;
  }

  async uploadAvatar(uri: string, personId: string): Promise<void> {
    await this.uploadMultipart(
      '/api/v1/persons/' + encodeURIComponent(personId) + '/avatar',
      uri,
      {}
    );
  }

  async uploadAvatarBuffer(buffer: ArrayBuffer, personId: string): Promise<void> {
    await this.uploadMultipartData(
      '/api/v1/persons/' + encodeURIComponent(personId) + '/avatar',
      buffer,
      'avatar.jpg',
      'image/jpeg',
      {}
    );
  }

  async deleteAvatar(personId: string): Promise<void> {
    await this.request(
      http.RequestMethod.DELETE,
      '/api/v1/persons/' + encodeURIComponent(personId) + '/avatar'
    );
  }

  async deletePhoto(photoId: string): Promise<void> {
    await this.request(
      http.RequestMethod.DELETE,
      '/api/v1/photos/' + encodeURIComponent(photoId)
    );
  }

  async stories(): Promise<ApiStoryPage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/stories');
    return JSON.parse(text) as ApiStoryPage;
  }

  async story(storyId: string): Promise<ApiStory> {
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/stories/' + encodeURIComponent(storyId)
    );
    return JSON.parse(text) as ApiStory;
  }

  async createStory(
    title: string,
    body: string,
    personId: string,
    photoIds: string[]
  ): Promise<ApiStory> {
    const payload: StoryPayload = {
      title: title,
      body: body,
      personId: personId,
      photoIds: photoIds
    };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/stories',
      payload
    );
    return JSON.parse(text) as ApiStory;
  }

  async deleteStory(storyId: string): Promise<void> {
    await this.request(
      http.RequestMethod.DELETE,
      '/api/v1/stories/' + encodeURIComponent(storyId)
    );
  }

  async updateStory(
    storyId: string,
    title: string,
    body: string,
    personId: string,
    photoIds: string[]
  ): Promise<ApiStory> {
    const payload: StoryPayload = {
      title: title,
      body: body,
      personId: personId,
      photoIds: photoIds
    };
    const text = await this.request(
      http.RequestMethod.PATCH,
      '/api/v1/stories/' + encodeURIComponent(storyId),
      payload
    );
    return JSON.parse(text) as ApiStory;
  }

  async notifications(limit: number = 50): Promise<ApiNotificationPage> {
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/notifications?limit=' + String(limit)
    );
    return JSON.parse(text) as ApiNotificationPage;
  }

  async unreadNotificationCount(): Promise<number> {
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/notifications/unread-count'
    );
    const value = JSON.parse(text) as Record<string, number>;
    return value['count'] === undefined ? 0 : value['count'];
  }

  async markNotificationRead(id: number = 0, all: boolean = false): Promise<void> {
    const payload: NotificationReadPayload = { id: id, all: all };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/notifications/read',
      payload
    );
  }

  async editRequests(status: string = '', mine: boolean = false): Promise<ApiEditRequestPage> {
    let path = '/api/v1/edit-requests?limit=100';
    if (status.length > 0) path += '&status=' + encodeURIComponent(status);
    if (mine) path += '&mine=true';
    const text = await this.request(http.RequestMethod.GET, path);
    return JSON.parse(text) as ApiEditRequestPage;
  }

  async editRequest(requestId: string): Promise<ApiEditRequest> {
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/edit-requests/' + encodeURIComponent(requestId)
    );
    return JSON.parse(text) as ApiEditRequest;
  }

  async reviewEditRequest(
    requestId: string,
    approve: boolean,
    note: string
  ): Promise<ApiEditRequest> {
    const payload: ReviewPayload = { note: note };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/edit-requests/' + encodeURIComponent(requestId) +
        (approve ? '/approve' : '/reject'),
      payload
    );
    return JSON.parse(text) as ApiEditRequest;
  }

  async bindingRequests(status: string = '', mine: boolean = false): Promise<ApiBindingRequestPage> {
    let path = '/api/v1/bind-requests?limit=100';
    if (status.length > 0) path += '&status=' + encodeURIComponent(status);
    if (mine) path += '&mine=true';
    const text = await this.request(http.RequestMethod.GET, path);
    return JSON.parse(text) as ApiBindingRequestPage;
  }

  async reviewBindingRequest(
    requestId: string,
    approve: boolean,
    note: string
  ): Promise<ApiBindingRequest> {
    const payload: ReviewPayload = { note: note };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/bind-requests/' + encodeURIComponent(requestId) +
        (approve ? '/approve' : '/reject'),
      payload
    );
    return JSON.parse(text) as ApiBindingRequest;
  }

  async mergeRequests(status: string = ''): Promise<ApiFamilyMergeRequestPage> {
    let path = '/api/v1/merge-requests';
    if (status.length > 0) path += '?status=' + encodeURIComponent(status);
    const text = await this.request(http.RequestMethod.GET, path);
    return JSON.parse(text) as ApiFamilyMergeRequestPage;
  }

  async mergeDetail(requestId: string): Promise<ApiFamilyMergeDetail> {
    const text = await this.request(
      http.RequestMethod.GET,
      '/api/v1/merge-requests/' + encodeURIComponent(requestId)
    );
    return JSON.parse(text) as ApiFamilyMergeDetail;
  }

  async approveMerge(
    requestId: string,
    personIds: string[],
    storyIds: string[],
    photoIds: string[],
    targetBranchId: string,
    startGeneration: number,
    attachParentId: string,
    note: string
  ): Promise<ApiFamilyMergeResult> {
    const payload: MergeApprovePayload = {
      personIds: personIds,
      storyIds: storyIds,
      photoIds: photoIds,
      targetBranchId: targetBranchId,
      startGeneration: startGeneration,
      attachParentId: attachParentId,
      note: note
    };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/merge-requests/' + encodeURIComponent(requestId) + '/approve',
      payload
    );
    return JSON.parse(text) as ApiFamilyMergeResult;
  }

  async rejectMerge(requestId: string, note: string): Promise<ApiFamilyMergeResult> {
    const payload: ReviewPayload = { note: note };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/merge-requests/' + encodeURIComponent(requestId) + '/reject',
      payload
    );
    return JSON.parse(text) as ApiFamilyMergeResult;
  }

  async exportFamilyJSON(familyId: string): Promise<string> {
    return await this.request(
      http.RequestMethod.GET,
      '/api/v1/families/' + encodeURIComponent(familyId) + '/export'
    );
  }

  async createImportPackage(rootPersonId: string): Promise<ApiImportPackage> {
    const payload: ImportRootPayload = { rootPersonId: rootPersonId };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/import-packages',
      payload
    );
    return JSON.parse(text) as ApiImportPackage;
  }

  async previewImportPackage(code: string): Promise<ApiImportPreview> {
    const payload: ImportCodePayload = { code: code };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/import-packages/preview',
      payload
    );
    return JSON.parse(text) as ApiImportPreview;
  }

  async importPackage(
    code: string,
    branchId: string,
    rootGeneration: number,
    parentId: string,
    parentRole: string
  ): Promise<ApiImportResult> {
    const payload: ImportPackagePayload = {
      code: code,
      branchId: branchId,
      rootGeneration: rootGeneration,
      parentId: parentId,
      parentRole: parentRole
    };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/import-packages/import',
      payload
    );
    return JSON.parse(text) as ApiImportResult;
  }

  async families(): Promise<ApiFamilyListPage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/families');
    return JSON.parse(text) as ApiFamilyListPage;
  }

  async switchFamily(familyId: string): Promise<ApiMeResult> {
    const payload: SwitchFamilyPayload = { familyId: familyId };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/switch-family',
      payload
    );
    return JSON.parse(text) as ApiMeResult;
  }

  async joinFamily(inviteCode: string): Promise<ApiJoinResult> {
    const payload: JoinFamilyPayload = { inviteCode: inviteCode };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/families/join',
      payload
    );
    return JSON.parse(text) as ApiJoinResult;
  }

  async createFamily(
    name: string,
    surname: string,
    motto: string,
    region: string,
    description: string
  ): Promise<ApiMeResult> {
    const payload: CreateFamilyPayload = {
      name: name,
      surname: surname,
      motto: motto,
      region: region,
      description: description
    };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/families',
      payload
    );
    return JSON.parse(text) as ApiMeResult;
  }

  async changePassword(currentPassword: string, newPassword: string): Promise<void> {
    const payload: PasswordPayload = {
      currentPassword: currentPassword,
      newPassword: newPassword
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/me/password',
      payload
    );
  }

  async deleteAccount(password: string): Promise<void> {
    const payload: DeleteAccountPayload = { password: password };
    await this.request(http.RequestMethod.DELETE, '/api/v1/me', payload);
  }

  async invites(): Promise<ApiInvitePage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/invites');
    return JSON.parse(text) as ApiInvitePage;
  }

  async createInvite(role: string, maxUses: number, expiresInDays: number): Promise<ApiInvite> {
    const payload: CreateInvitePayload = {
      role: role,
      maxUses: maxUses,
      expiresInDays: expiresInDays
    };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/invites',
      payload
    );
    return JSON.parse(text) as ApiInvite;
  }

  async accounts(): Promise<ApiFamilyAccountPage> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/accounts');
    return JSON.parse(text) as ApiFamilyAccountPage;
  }

  async register(
    loginName: string,
    password: string,
    displayName: string,
    inviteCode: string,
    phone: string,
    familyName: string,
    surname: string,
    acceptTerms: boolean
  ): Promise<ApiRegistration> {
    const payload: RegisterPayload = {
      loginName: loginName,
      password: password,
      displayName: displayName,
      inviteCode: inviteCode,
      phone: phone,
      familyName: familyName,
      surname: surname,
      acceptTerms: acceptTerms
    };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/register',
      payload
    );
    return JSON.parse(text) as ApiRegistration;
  }

  async sendLoginCode(phone: string): Promise<void> {
    const payload: PhonePayload = { phone: phone };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/sms/send',
      payload
    );
  }

  async loginWithPhone(phone: string, code: string): Promise<ApiLoginResult> {
    const payload: PhoneCodePayload = { phone: phone, code: code };
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/sms/login',
      payload
    );
    return JSON.parse(text) as ApiLoginResult;
  }

  async resetPassword(
    loginName: string,
    recoveryCode: string,
    newPassword: string
  ): Promise<void> {
    const payload: ResetPasswordPayload = {
      loginName: loginName,
      recoveryCode: recoveryCode,
      newPassword: newPassword
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/reset-password',
      payload
    );
  }

  async createRecoveryCode(): Promise<string> {
    const text = await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/recovery-code'
    );
    const value = JSON.parse(text) as RecoveryCodeResult;
    return value.code === undefined ? '' : value.code;
  }

  async sendBindCode(phone: string): Promise<void> {
    const payload: PhonePayload = { phone: phone };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/phone/send',
      payload
    );
  }

  async bindPhone(phone: string, code: string): Promise<void> {
    const payload: PhoneCodePayload = { phone: phone, code: code };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/auth/phone/bind',
      payload
    );
  }

  async transferOwner(familyId: string, userId: string): Promise<void> {
    const payload: TransferOwnerPayload = { userId: userId };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/families/' + encodeURIComponent(familyId) + '/transfer-owner',
      payload
    );
  }

  async archiveFamily(
    familyId: string,
    password: string,
    confirmName: string
  ): Promise<void> {
    const payload: ArchiveFamilyPayload = {
      password: password,
      confirmName: confirmName
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/families/' + encodeURIComponent(familyId) + '/archive',
      payload
    );
  }

  async updatePerson(
    personId: string,
    payload: UpdatePersonPayload
  ): Promise<ApiPerson> {
    const text = await this.request(
      http.RequestMethod.PATCH,
      '/api/v1/persons/' + encodeURIComponent(personId),
      payload
    );
    return JSON.parse(text) as ApiPerson;
  }

  async addParentChild(
    parentId: string,
    childId: string,
    parentRole: string
  ): Promise<void> {
    const payload: ParentChildPayload = {
      parentId: parentId,
      childId: childId,
      parentRole: parentRole
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/relationships/parent-child',
      payload
    );
  }

  async addSpouse(personAId: string, personBId: string): Promise<void> {
    const payload: SpousePayload = {
      personAId: personAId,
      personBId: personBId
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/relationships/spouse',
      payload
    );
  }

  async deleteParentChild(edgeId: string): Promise<void> {
    await this.request(
      http.RequestMethod.DELETE,
      '/api/v1/relationships/parent-child/' + encodeURIComponent(edgeId)
    );
  }

  async deleteSpouse(edgeId: string): Promise<void> {
    await this.request(
      http.RequestMethod.DELETE,
      '/api/v1/relationships/spouse/' + encodeURIComponent(edgeId)
    );
  }

  async createRelationshipEndRequest(edgeType: string, edgeId: string): Promise<void> {
    const payload: RelationshipEndPayload = {
      edgeType: edgeType,
      edgeId: edgeId
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/edit-requests/relationship-end',
      payload
    );
  }

  async createProfileRequest(
    personId: string,
    baseVersion: number,
    changes: Record<string, string>
  ): Promise<void> {
    const payload: CreateEditRequestPayload = {
      targetPersonId: personId,
      baseVersion: baseVersion,
      changes: changes
    };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/edit-requests',
      payload
    );
  }

  async createBindingRequest(personId: string): Promise<void> {
    const payload: BindingPayload = { personId: personId };
    await this.request(
      http.RequestMethod.POST,
      '/api/v1/bind-requests',
      payload
    );
  }

  async family(): Promise<ApiFamily> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/family');
    return JSON.parse(text) as ApiFamily;
  }
}

export class AppServices {
  static api: ApiClient = new ApiClient();
}

interface StoryPayload {
  title: string;
  body: string;
  personId: string;
  photoIds: string[];
}

interface NotificationReadPayload {
  id: number;
  all: boolean;
}

interface ReviewPayload {
  note: string;
}

interface MergeApprovePayload {
  personIds: string[];
  storyIds: string[];
  photoIds: string[];
  targetBranchId: string;
  startGeneration: number;
  attachParentId: string;
  note: string;
}

interface ImportRootPayload {
  rootPersonId: string;
}

interface ImportCodePayload {
  code: string;
}

interface ImportPackagePayload {
  code: string;
  branchId: string;
  rootGeneration: number;
  parentId: string;
  parentRole: string;
}

interface SwitchFamilyPayload {
  familyId: string;
}

interface JoinFamilyPayload {
  inviteCode: string;
}

interface CreateFamilyPayload {
  name: string;
  surname: string;
  motto: string;
  region: string;
  description: string;
}

interface PasswordPayload {
  currentPassword: string;
  newPassword: string;
}

interface DeleteAccountPayload {
  password: string;
}

interface CreateInvitePayload {
  role: string;
  maxUses: number;
  expiresInDays: number;
}

interface RegisterPayload {
  loginName: string;
  password: string;
  displayName: string;
  inviteCode: string;
  phone: string;
  familyName: string;
  surname: string;
  acceptTerms: boolean;
}

interface PhonePayload {
  phone: string;
}

interface PhoneCodePayload {
  phone: string;
  code: string;
}

interface ResetPasswordPayload {
  loginName: string;
  recoveryCode: string;
  newPassword: string;
}

interface RecoveryCodeResult {
  code?: string;
}

interface TransferOwnerPayload {
  userId: string;
}

interface ArchiveFamilyPayload {
  password: string;
  confirmName: string;
}

interface ParentChildPayload {
  parentId: string;
  childId: string;
  parentRole: string;
}

interface SpousePayload {
  personAId: string;
  personBId: string;
}

interface RelationshipEndPayload {
  edgeType: string;
  edgeId: string;
}

interface BindingPayload {
  personId: string;
}

interface ProfileChangesPayload {
  birthPlace: string;
  residence: string;
  occupation: string;
  education: string;
  biography: string;
}

interface CreateEditRequestPayload {
  targetPersonId: string;
  baseVersion: number;
  changes: Record<string, string>;
}

interface UpdatePhotoPayload {
  personId: string;
  personIds: string[];
  caption: string;
  takenAt: string;
}
