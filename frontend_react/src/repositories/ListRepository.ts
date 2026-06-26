import AsyncStorage from '@react-native-async-storage/async-storage'; // Replace with your storage import path
import { listApiClient } from '@/services/api/listApiClient';
import { GroceryList, GroceryItem, ItemStatus } from '@/types/models';

class ListRepository {
    private readonly LISTS_KEY = 'lists';
    private readonly ITEMS_KEY = 'items';

    private async _getCachedLists(): Promise<GroceryList[]> {
        const stored = await AsyncStorage.getItem(this.LISTS_KEY);
        return stored ? JSON.parse(stored) : [];
    }

    private async _getCachedItems(): Promise<GroceryItem[]> {
        const stored = await AsyncStorage.getItem(this.ITEMS_KEY);
        return stored ? JSON.parse(stored) : [];
    }

    /**
     * 1. Get lists from Server and update local cache
     */
    async getLists(groupId: string, isShared: boolean): Promise<GroceryList[]> {
        if (isShared) {
            try {
                const remoteLists = await listApiClient.fetchLists(groupId);
                const allLists = await this._getCachedLists();

                const remainingLists = allLists.filter(l => l.groupId !== groupId);

                const updatedLists = [...remainingLists, ...remoteLists];
                await AsyncStorage.setItem(this.LISTS_KEY, JSON.stringify(updatedLists));

                return remoteLists;
            } catch (error) {
                console.warn("Repository: Sync lists failed, using local fallback.", error);
            }
        }


        const cached = await this._getCachedLists();
        return cached.filter(l => l.groupId === groupId);
    }

    /**
     * 2. Create a new List
     */
    async addList(name: string, groupId: string, isShared: boolean): Promise<GroceryList> {
        let newList: GroceryList;

        if (isShared) {
            newList = await listApiClient.createList(name, groupId);
        } else {
            newList = {
                id: `list_${Date.now()}`,
                name,
                groupId,
                createdAt: new Date(),
                isArchived: false,
            };
        }

        const cachedLists = await this._getCachedLists();
        cachedLists.push(newList);
        await AsyncStorage.setItem(this.LISTS_KEY, JSON.stringify(cachedLists));

        return newList;
    }

    /**
     * 3. Delete List and orphaned Items
     */
    async removeList(listId: string, isShared: boolean): Promise<void> {
        if (isShared) {
            await listApiClient.deleteList(listId);
        }

        const cachedLists = await this._getCachedLists();
        const updatedLists = cachedLists.filter(l => l.id !== listId);
        await AsyncStorage.setItem(this.LISTS_KEY, JSON.stringify(updatedLists));

        const cachedItems = await this._getCachedItems();
        const updatedItems = cachedItems.filter(i => i.listId !== listId);
        await AsyncStorage.setItem(this.ITEMS_KEY, JSON.stringify(updatedItems));
    }

    /**
     * 4. Archive list and carry over pending items to a new list
     */
    async archiveAndCarryOver(listId: string, newName: string, groupId: string, isShared: boolean): Promise<GroceryList> {
        let newList: GroceryList;
        const allLists = await this._getCachedLists();

        if (isShared) {
            newList = await listApiClient.archiveList(listId, newName);

            const listIndex = allLists.findIndex(l => l.id === listId);
            if (listIndex !== -1) {
                allLists[listIndex].isArchived = true;
            }

            allLists.push(newList);
            await AsyncStorage.setItem(this.LISTS_KEY, JSON.stringify(allLists));

            const allItems = await this._getCachedItems();
            const updatedItems = allItems.map(item => {
                if (item.listId === listId && item.status === 'pending') {
                    return { ...item, listId: newList.id };
                }
                return item;
            });
            await AsyncStorage.setItem(this.ITEMS_KEY, JSON.stringify(updatedItems));

            return newList;
        } else {
            newList = {
                id: `list_${Date.now()}`,
                name: "Liste (Cont.)",
                groupId,
                createdAt: new Date(),
                isArchived: false,
            };

            allLists.push(newList);
            await AsyncStorage.setItem(this.LISTS_KEY, JSON.stringify(allLists));
            return newList;
        }
    }
}

export const listRepository = new ListRepository();