import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import {
  ApiActivityPage,
  ApiAnniversaryPage,
  ApiBranchPage,
  ApiFamily,
  ApiLoginResult,
  ApiMeResult,
  ApiPerson,
  ApiPersonPage,
  ApiPhoto,
  ApiPhotoPage,
  ApiProblem,
  ApiStory,
  ApiStoryPage,
  ApiTree
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
    const fields: Record<string, string> = {};
    if (personId !== undefined && personId.length > 0) {
      fields['personId'] = personId;
      fields['personIds'] = personId;
    }
    if (caption.length > 0) {
      fields['caption'] = caption;
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
