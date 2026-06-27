import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Application from 'expo-application';
import { Platform } from 'react-native';
import {authApiClient} from "@/services/api/authApiClient";
import {User} from "@/types/models";

class AuthRepository {
    /**
     * Helper to fetch the unique device ID across Android/iOS platforms
     */
    private async getUniqueDeviceId(): Promise<string> {
        if (Platform.OS === 'android') {
            let deviceId = Application.getAndroidId();
            await AsyncStorage.setItem('deviceId', deviceId);
            return deviceId;
        } else if (Platform.OS === 'ios') {
            const id = await Application.getIosIdForVendorAsync();
            if (id != null) {
                await AsyncStorage.setItem('deviceId', id);
            }
            return id || 'ios-id';
        }
        return 'unknown-device';
    }

    async isLoggedIn(): Promise<boolean> {
        const email = await AsyncStorage.getItem('userEmail');
        return email !== null;
    }

    async getEmail(): Promise<string | null> {
        return AsyncStorage.getItem('userEmail');
    }

    async getSyncCode(): Promise<string> {
        let deviceId = await AsyncStorage.getItem('deviceId');
        if (deviceId == "Not Generated") {
            deviceId = await this.getUniqueDeviceId()
        }
        return deviceId || "Not Generated";
    }

    async getDeviceId(): Promise<string> {
        const deviceId = await AsyncStorage.getItem('deviceId');
        return deviceId || "Not Generated";
    }

    /**
     * 1. Registration Flow
     */
    async registerUser(first: string, last: string, email: string): Promise<void> {
        const deviceId = await this.getUniqueDeviceId();

        await authApiClient.register({
            firstName: first,
            lastName: last,
            email: email,
            deviceId: deviceId,
        });

        await AsyncStorage.multiSet([
            ['firstName', first],
            ['lastName', last],
            ['userEmail', email],
        ]);
    }

    async updateProfile(firstName: string, lastName: string, email: string): Promise<void> {
        await authApiClient.updateProfile({ firstName, lastName, email });

        await AsyncStorage.multiSet([
            ['firstName', firstName],
            ['lastName', lastName],
            ['userEmail', email],
        ]);
    }

    /**
     * 2. Device Linking Flow
     */
    async linkAccount(syncCode: string): Promise<void> {
        const deviceId = await this.getUniqueDeviceId();
        const user = await authApiClient.linkDevices(deviceId, syncCode);

        await AsyncStorage.multiSet([
            ['userEmail', user.email],
            ['firstName', user.firstName],
            ['lastName', user.lastName],
        ]);
    }

    /**
     * Wipes persistent local structures (replaces Hive multi-box clearing)
     */
    async clearAllLocalData(): Promise<void> {
        // If you cache lists/items under unique namespace keys, target them here
        const keysToClear = ['items', 'groups', 'lists', 'firstName', 'lastName', 'userEmail'];
        await AsyncStorage.multiRemove(keysToClear);
    }

    async saveToken(token: string): Promise<void> {
        await authApiClient.updateFcmToken(token);
    }

    async fetchProfile(): Promise<User> {
        return authApiClient.getMe();
    }

    async getInvites(): Promise<any[]> {
        return authApiClient.fetchPendingInvites();
    }

    async acceptInvite(groupId: string, status: string): Promise<void> {
        await authApiClient.respondToInvite(groupId, status);
    }

    async inviteUser(groupId: string, email: string): Promise<void> {
        await authApiClient.sendInvite(groupId, email);
    }

    async getContacts(): Promise<string[]> {
        return authApiClient.fetchRecentContacts();
    }
}

export const authRepository = new AuthRepository();