import { BaseApi } from './baseApi';
import {GroceryGroup, GroceryGroupModel} from "@/types/models";


class GroupApiClient extends BaseApi {

    /**
     * PUT: Make a specific group public
     */
    async makeGroupPublic(groupId: string): Promise<GroceryGroup> {
        return this.request<GroceryGroup>({
            method: 'PUT',
            path: `/groups/${groupId}/make-public`,
        });
    }

    /**
     * GET: Fetch all groups for the logged-in user
     */
    async fetchGroups(): Promise<GroceryGroup[]> {
        return this.request<GroceryGroup[]>({
            method: 'GET',
            path: '/groups',
            fromJson: (json) =>
                (json as any[]).map((g) => GroceryGroupModel.fromJson(g)),
        });
    }

    /**
     * GET: Fetch detailed information for a single group
     */
    async fetchGroup(groupId: string): Promise<GroceryGroup> {
        return this.request<GroceryGroup>({
            method: 'GET',
            path: `/groups/${groupId}`,
        });
    }

    /**
     * POST: Create a new grocery group
     */
    async createGroup(name: string): Promise<GroceryGroup> {
        return this.request<GroceryGroup>({
            method: 'POST',
            path: '/groups',
            body: { name },
        });
    }

    /**
     * DELETE: Delete a grocery group by ID
     */
    async deleteGroup(id: string): Promise<void> {
        return this.request<void>({
            method: 'DELETE',
            path: `/groups/${id}`,
        });
    }
}

export const groupApiClient = new GroupApiClient();