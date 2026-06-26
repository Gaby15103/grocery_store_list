import { groupRepository } from './groupRepository';
import {groupApiClient} from "@/services/api/groupApiClient";
import { itemApiClient} from "@/services/api/itemApiClient";
import {GroceryItem, ItemStatus} from "@/types/models";

// Interface defining the cross-platform React Native file references
export interface FilePayload {
    uri: string;
    name: string;
    type: string;
}

class ItemRepository {

    private async _isShared(groupId: string): Promise<boolean> {
        console.log(`DEBUG: Entrée dans _isShared pour ${groupId}`);
        if (groupId === 'default') {
            return false;
        }

        const cachedGroups = await groupRepository.getCachedGroups();
        let group = cachedGroups.find(g => g.id === groupId);

        if (!group) {
            try {
                group = await groupApiClient.fetchGroup(groupId);
            } catch (e) {
                console.error("Repository: Failed to fetch group data remotely", e);
                return false;
            }
        }

        return group ? (group.isShared || false) : false;
    }

    /**
     * GET: Absolute truth from server
     */
    async getItems(listId: string, groupId: string): Promise<GroceryItem[]> {
        if (await this._isShared(groupId)) {
            return await itemApiClient.fetchItems(listId);
        }
        return [];
    }

    /**
     * POST: Creates item on server and gets the Real ID
     */
    async addItemToList({
                            name,
                            listId,
                            groupId,
                            note,
                            imageFile,
                        }: {
        name: string;
        listId: string;
        groupId: string;
        note?: string;
        imageFile?: FilePayload;
    }): Promise<void> {
        if (!(await this._isShared(groupId))) return;

        let finalImagePath: string | undefined;
        if (imageFile) {
            const uploadedPath = await itemApiClient.uploadImage(imageFile as any);
            if (uploadedPath) finalImagePath = uploadedPath;
        }

        const newItem: GroceryItem = {
            createdAt: new Date(),
            status: "pending",
            name,
            listId,
            groupId,
            note
        };

        const serverItem = await itemApiClient.addItem(newItem);
        newItem.id = serverItem.id;
    }

    /**
     * PUT: Update the item
     */
    async updateItem(item: GroceryItem, groupId: string): Promise<void> {
        if (await this._isShared(groupId)) {
            await itemApiClient.updateItem(item, groupId);
        }
    }

    async updateItemDetails({
                                item,
                                newName,
                                newNote,
                                newImageFile,
                                shouldClearImage = false,
                                groupId,
                            }: {
        item: GroceryItem;
        newName: string;
        newNote?: string;
        newImageFile?: FilePayload;
        shouldClearImage?: boolean;
        groupId: string;
    }): Promise<void> {
        item.name = newName;
        item.note = newNote;

        if (!(await this._isShared(groupId))) {
            if (shouldClearImage) {
                item.imagePath = undefined;
            } else if (newImageFile) {
                item.imagePath = newImageFile.uri;
            }
            return;
        }

        if (shouldClearImage) {
            item.imagePath = undefined;
        } else if (newImageFile) {
            const uploadedPath = await itemApiClient.uploadImage(newImageFile as any);
            if (uploadedPath) {
                item.imagePath = uploadedPath;
            }
        }

        await itemApiClient.updateItem(item, groupId);
    }

    /**
     * DELETE: Remove from server
     */
    async deleteItem(item: GroceryItem, groupId: string): Promise<void> {
        const shared = await this._isShared(groupId);
        if (shared && item.id) {
            await itemApiClient.deleteItem(item.id, item.name, item.listId, groupId);
        }
    }
}

export const itemRepository = new ItemRepository();