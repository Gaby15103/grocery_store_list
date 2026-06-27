import AsyncStorage from '@react-native-async-storage/async-storage';
import { groupApiClient} from "@/services/api/groupApiClient";
import {GroceryGroup} from "@/types/models";

class GroupRepository {
    private readonly GROUPS_KEY = 'groups';
    private readonly ACTIVE_GROUP_KEY = 'activeGroupId';

    /**
     * Helper to retrieve current cached array safely from local storage
     */
    async getCachedGroups(): Promise<GroceryGroup[]> {
        try {
            const stored = await AsyncStorage.getItem(this.GROUPS_KEY);
            return stored ? (JSON.parse(stored) as GroceryGroup[]) : [];
        } catch (_) {
            return [];
        }
    }

    /**
     * Refreshes local storage from server data. Fallback to cache on error.
     */
    async refreshGroups(): Promise<GroceryGroup[]> {
        try {
            const remoteGroups = await groupApiClient.fetchGroups();
            console.log('Remote Groups: ' + JSON.stringify(remoteGroups));

            // Overwrites and updates local cache like: box.clear() -> box.put()
            await AsyncStorage.setItem(this.GROUPS_KEY, JSON.stringify(remoteGroups));
            return remoteGroups;
        } catch (error) {
            console.warn("Repository: Sync failed, using local data.", error);
            return this.getCachedGroups();
        }
    }

    /**
     * Toggle group privacy configuration on remote and local caches
     */
    async makeGroupPublic(groupId: string): Promise<void> {
        const updatedGroup = await groupApiClient.makeGroupPublic(groupId);
        await this.updateSingleCachedGroup(groupId, updatedGroup);
    }

    /**
     * 3. Create Group
     */
    async createGroup(name: string): Promise<void> {
        const serverGroup = await groupApiClient.createGroup(name);
        if (serverGroup) {
            const cached = await this.getCachedGroups();
            cached.push(serverGroup);
            await AsyncStorage.setItem(this.GROUPS_KEY, JSON.stringify(cached));
        }
    }

    /**
     * 4. Delete Group
     */
    async removeGroup(groupId: string): Promise<void> {
        await groupApiClient.deleteGroup(groupId);

        const cached = await this.getCachedGroups();
        const filtered = cached.filter(group => group.id !== groupId);
        await AsyncStorage.setItem(this.GROUPS_KEY, JSON.stringify(filtered));

        const activeGroupId = await this.getActiveGroupId();
        if (activeGroupId === groupId) {
            await AsyncStorage.setItem(this.ACTIVE_GROUP_KEY, 'default');
        }
    }

    /**
     * 5. Active Group State (Persisted in Metadata)
     */
    async getActiveGroupId(): Promise<string> {
        const activeId = await AsyncStorage.getItem(this.ACTIVE_GROUP_KEY);
        return activeId || 'default';
    }

    async saveActiveGroupId(id: string): Promise<void> {
        await AsyncStorage.setItem(this.ACTIVE_GROUP_KEY, id);
    }

    /**
     * Internal routine helper to update a single modified group in place
     */
    private async updateSingleCachedGroup(groupId: string, updatedGroup: GroceryGroup): Promise<void> {
        const cached = await this.getCachedGroups();
        const index = cached.findIndex(group => group.id === groupId);

        if (index !== -1) {
            cached[index] = updatedGroup;
        } else {
            cached.push(updatedGroup);
        }

        await AsyncStorage.setItem(this.GROUPS_KEY, JSON.stringify(cached));
    }
}

export const groupRepository = new GroupRepository();