import { BaseApi } from './baseApi';
import {GroceryItem} from "@/types/models";
import {Platform} from "react-native";

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
    async fetchItemTypes(): Promise<GroceryItem[]> {
        return this.request<GroceryItem[]>({
            method:'GET',
            path: '/items/type'
        })
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
        try {
            const result = await this.uploadNativeMultipart<{ path: string | null }>({
                method: 'POST',
                path: '/upload',
                file: file,
                fieldName: 'file',
            });

            return result ? result.path : null;

        } catch (error) {
            console.error("Upload image execution sequence failed:", error);
            throw error;
        }
    }
}

export const itemApiClient = new ItemApiClient();