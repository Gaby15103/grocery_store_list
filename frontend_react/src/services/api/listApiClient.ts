import { BaseApi } from './baseApi';
import {GroceryList} from "@/types/models";


class ListApiClient extends BaseApi {

  /**
   * GET: Fetch all grocery lists associated with a specific group
   */
  async fetchLists(groupId: string): Promise<GroceryList[]> {
    return this.request<GroceryList[]>({
      method: 'GET',
      path: `/groups/${groupId}/lists`,
    });
  }

  /**
   * POST: Create a new grocery list inside a group
   */
  async createList(name: string, groupId: string): Promise<GroceryList> {
    return this.request<GroceryList>({
      method: 'POST',
      path: '/lists',
      body: {
        name,
        GroupId: groupId, // Preserved exact casing from your Dart body ('GroupId')
      },
    });
  }

  /**
   * DELETE: Remove a grocery list by ID
   */
  async deleteList(listId: string): Promise<void> {
    return this.request<void>({
      method: 'DELETE',
      path: `/lists/${listId}`,
    });
  }

  /**
   * POST: Archive an existing list and assign it a new name
   */
  async archiveList(listId: string, newName: string): Promise<GroceryList> {
    return this.request<GroceryList>({
      method: 'POST',
      path: `/lists/${listId}/archive`,
      body: { newName },
    });
  }
}

export const listApiClient = new ListApiClient();