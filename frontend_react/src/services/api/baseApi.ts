import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Application from 'expo-application';
import {Platform} from 'react-native';
import {syncManager} from "@/services/syncManager";

const BASE_URL = "https://apigrocery.gaby15103.org";

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
                               }: {
        method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
        path: string;
        body?: any;
    }): Promise<T> {
        const url = `${BASE_URL}${path}`;
        let headers = await this.getHeaders();
        let finalBody = body;

        if (body instanceof FormData) {
            finalBody = body;
            const uploadHeaders = { ...headers };
            delete uploadHeaders['Content-Type'];
            headers = uploadHeaders;
        } else if (body) {
            finalBody = JSON.stringify(body);
        }

        try {
            const response = await fetch(url, {
                method,
                headers,
                body: finalBody,
            });

            return await this.handleResponse<T>(response);
        } catch (error: any) {
            if (error.message === 'Network request failed' && method !== 'GET') {
                await this.handleOffline(method, path, body);
                throw new Error("Offline: Action queued.");
            }
            throw error;
        }
    }

    private async handleResponse<T>(response: Response): Promise<T> {
        const statusCode = response.status;

        if (statusCode >= 200 && statusCode < 300) {
            const text = await response.text();
            return text ? (JSON.parse(text) as T) : (null as unknown as T);
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