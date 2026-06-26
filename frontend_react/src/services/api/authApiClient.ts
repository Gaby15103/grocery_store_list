import { BaseApi } from './baseApi';
import {User} from "@/types/models";
export interface RegisterPayload {
    firstName: string;
    lastName: string;
    email: string;
    deviceId: string;
}

export interface UpdateProfilePayload {
    firstName: string;
    lastName: string;
    email: string;
}

class AuthApiClient extends BaseApi {

    /**
     * GET current user profile
     */
    async getMe(): Promise<User> {
        return this.request<User>({
            method: 'GET',
            path: '/users/me',
        });
    }

    /**
     * POST register new user
     */
    async register(payload: RegisterPayload): Promise<void> {
        return this.request<void>({
            method: 'POST',
            path: '/users/register',
            body: payload,
        });
    }

    /**
     * PUT: Update the user's profile details
     */
    async updateProfile(payload: UpdateProfilePayload): Promise<void> {
        return this.request<void>({
            method: 'PUT',
            path: '/users/profile',
            body: payload,
        });
    }

    /**
     * POST link devices via sync code
     */
    async linkDevices(currentDeviceId: string, targetCode: string): Promise<User> {
        // Mimics the exact Dart extract mapper: (json) => json['user']
        const response = await this.request<{ user: User }>({
            method: 'POST',
            path: '/users/link',
            body: {
                currentDeviceId,
                targetSyncCode: targetCode,
            },
        });
        return response.user;
    }

    /**
     * GET: Fetch pending invites for the logged-in user
     */
    async fetchPendingInvites(): Promise<any[]> {
        return this.request<any[]>({
            method: 'GET',
            path: '/users/invitations',
        });
    }

    /**
     * PUT: Respond to a group invite
     */
    async respondToInvite(groupId: string, status: string): Promise<void> {
        return this.request<void>({
            method: 'PUT',
            path: `/groups/${groupId}/invite/respond`,
            body: { status },
        });
    }

    /**
     * POST: Send an invite to another user
     */
    async sendInvite(groupId: string, targetEmail: string): Promise<void> {
        return this.request<void>({
            method: 'POST',
            path: `/groups/${groupId}/invite`,
            body: { email: targetEmail },
        });
    }

    /**
     * GET: Fetch recently invited emails for auto-complete
     */
    async fetchRecentContacts(): Promise<string[]> {
        type ContactResponse = Array<{ email: string }>;

        const response = await this.request<ContactResponse>({
            method: 'GET',
            path: '/users/contacts',
        });

        // Mimics: (json as List).map((u) => u['email'] as String).toList()
        return response.map((u) => u.email);
    }

    /**
     * PATCH: Update Firebase Cloud Messaging push token
     */
    async updateFcmToken(token: string): Promise<void> {
        return this.request<void>({
            method: 'PATCH',
            path: '/users/me/fcm-token',
            body: { token },
        });
    }
}

export const authApiClient = new AuthApiClient();