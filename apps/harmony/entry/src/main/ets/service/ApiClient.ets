import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  ApiActivityPage,
  ApiAnniversaryPage,
  ApiBranchPage,
  ApiFamily,
  ApiLoginResult,
  ApiMeResult,
  ApiPerson,
  ApiPersonPage,
  ApiProblem,
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

  async family(): Promise<ApiFamily> {
    const text = await this.request(http.RequestMethod.GET, '/api/v1/family');
    return JSON.parse(text) as ApiFamily;
  }
}
