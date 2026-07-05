import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Application from 'expo-application';
import {Platform} from 'react-native';
import {syncManager} from "@/services/syncManager";
import * as FileSystem from 'expo-file-system';
import { File } from 'expo-file-system';
import { fetch as expoFetch } from 'expo/fetch';

const BASE_URL = "https://apigrocery.gaby15103.org";
const BASE_URL_LOCAL = "http://10.0.2.2:3000"

export interface UploadFilePayload {
    uri: string;
    type?: string;
    name?: string;
}

export class BaseApi {
    protected async getHeaders(): Promise<Record<string, string>> {
        const email = await AsyncStorage.getItem('userEmail') || '';

        let deviceId = 'unknown';
        try {
            if (Platform.OS === 'android') {
                deviceId = Application.getAndroidId();
            } else if (Platform.OS === 'ios') {
                const id = await Application.getIosIdForVendorAsync();
                deviceId = id || 'ios-id';
            }
        } catch (e) {
            console.error("Failed to fetch device ID", e);
        }

        return {
            'Content-Type': 'application/json',
            'x-user-email': email,
            'x-device-id': deviceId,
        };
    }

    protected async request<T>({
                                   method,
                                   path,
                                   body,
                                   fromJson
                               }: {
        method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
        path: string;
        body?: any;
        fromJson?: (json: any) => T;
    }): Promise<T> {
        let url = `${BASE_URL}${path}`;
        if (__DEV__){
            url = `${BASE_URL_LOCAL}${path}`
        }
        let headers = await this.getHeaders();
        let finalBody = body;

        const isFormData = body && (typeof body === 'object' && body.constructor.name === 'FormData');
        if (isFormData) {
            finalBody = body;
            const uploadHeaders = {...headers};
            delete uploadHeaders['Content-Type'];
            headers = uploadHeaders;
        } else if (body) {
            finalBody = JSON.stringify(body);
        }

        console.log(url)
        console.log(finalBody);
        console.log(headers)

        try {
            const response = await fetch(url, {
                method,
                headers,
                body: finalBody,
            });

            return await this.handleResponse<T>(response, fromJson);
        } catch (error: any) {
            if (error.message === 'Network request failed' && method !== 'GET') {
                await this.handleOffline(method, path, body);
                throw new Error("Offline: Action queued.");
            }
            throw error;
        }
    }

    /**
     * Dedicated native method for uploading local image files securely.
     * Replaces standard fetch multipart to support modern Expo architecture.
     */
    protected async uploadNativeMultipart<T>({
                                                 path,
                                                 file,
                                                 method = 'POST',
                                                 fieldName = 'file',
                                                 fromJson
                                             }: {
        path: string;
        file: UploadFilePayload;
        method?: 'POST' | 'PUT' | 'PATCH';
        fieldName?: string;
        fromJson?: (json: any) => T;
    }): Promise<T> {
        const url = `${BASE_URL}${path}`;
        const headers = await this.getHeaders();
        delete headers['Content-Type']; // Let modern FormData auto-generate boundaries

        try {
            // 1. Instantiates a modern Expo File instance mapping directly to the storage URI
            const nativeFile = new File(file.uri);

            // 2. Build a standard web-compliant FormData object
            const formData = new FormData();

            // 3. Append the structural parameters natively
            // Expo's new fetch parser recognizes this native File class object directly.
            formData.append(fieldName, nativeFile as any, file.name || 'upload.jpg');

            // 4. Use expo/fetch instead of global fetch to stream the data to the engine
            const response = await expoFetch(url, {
                method,
                headers,
                body: formData,
            });

            // Pass to your standard baseApi response middleware handler
            return await this.handleResponse<T>(response as any, fromJson);

        } catch (error: any) {
            if (error.message?.includes('Network') || error.message?.includes('failed')) {
                await this.handleOffline(method, path, { _isFormData: true, fileUri: file.uri });
                throw new Error("Offline: Multipart action queued.");
            }
            console.error("Modern multi-part upload worker failed:", error);
            throw error;
        }
    }

    private async handleResponse<T>(response: Response, fromJson?: (json: any) => T): Promise<T> {
        const statusCode = response.status;

        if (statusCode >= 200 && statusCode < 300) {
            const text = await response.text();
            if (!text) return null as unknown as T;

            const isJson = text.trim().startsWith('{') || text.trim().startsWith('[');
            if (!isJson) {
                return text as unknown as T;
            }

            try {
                const json = JSON.parse(text);
                return fromJson ? fromJson(json) : (json as T);
            } catch (e) {
                throw new Error(`Invalid JSON structure received from server: ${text}`);
            }
        }

        let errorMessage = `Server returned status code ${statusCode}`;
        try {
            const errorBody = await response.json();
            errorMessage = errorBody.message || errorBody.error || errorMessage;
        } catch (_) {
        }

        switch (statusCode) {
            case 400:
                throw new Error(`Bad Request: ${errorMessage}`);
            case 401:
                throw new Error("Unauthorized: Please log in again.");
            case 403:
                throw new Error("Forbidden: You don't have permission.");
            case 404:
                throw new Error(`Not Found: ${errorMessage}`);
            case 500:
                throw new Error(`Server Error: Your Arch server might be down. ${errorMessage}`);
            default:
                throw new Error(`Error ${statusCode}: ${errorMessage}`);
        }
    }

    private async handleOffline(method: any, path: string, body: any) {
        console.log(`Queueing offline task: ${method} ${path}`, body);
        await syncManager.enqueue(method, path, body);
    }
}