import { BaseApi } from './baseApi';
import {GroceryItem} from "@/types/models";

export interface UploadFilePayload {
    uri: string;
    name: string;
    type: string;
}

class ItemApiClient extends BaseApi {

    async fetchItems(listId: string): Promise<GroceryItem[]> {
        return this.request<GroceryItem[]>({
            method: 'GET',
            path: `/lists/${listId}/items`,
        });
    }

    async addItem(item: GroceryItem): Promise<GroceryItem> {
        return this.request<GroceryItem>({
            method: 'POST',
            path: '/items',
            body: item,
        });
    }

    async updateItem(item: GroceryItem, groupId: string): Promise<void> {
        return this.request<void>({
            method: 'PUT',
            path: '/items/update',
            body: { ...item, groupId },
        });
    }

    async deleteItem(itemId: string, name: string, listId: string, groupId: string): Promise<void> {
        return this.request<void>({
            method: 'DELETE',
            path: `/items/${itemId}`,
            body: { name, listId, groupId },
        });
    }
    /**
     * Specialized method for file uploads (handles images for grocery items)
     */
    /**
     * PUT: Update the item
     */
    async uploadImage(file: UploadFilePayload): Promise<string | null> {
        const formData = new FormData();
        formData.append('file', {
            uri: file.uri,
            name: file.name,
            type: file.type,
        } as any);

        const result = await this.request<{ path: string | null }>({
            method: 'POST',
            path: '/upload',
            body: formData,
        });

        return result ? result.path : null;
    }
}

export const itemApiClient = new ItemApiClient();