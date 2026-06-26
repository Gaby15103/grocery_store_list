// ==========================================================================
// 1. User Models
// ==========================================================================

export interface User {
    email: string;
    firstName: string;
    lastName: string;
    authorizedDevices: string[];
    isCurrentDeviceVerified: boolean;
}

export interface UserProfile {
    email: string;
    firstName: string;
    lastName: string;
}

// ==========================================================================
// 2. Grocery Group Model
// ==========================================================================

export interface GroceryGroup {
    id: string;
    name: string;
    isShared: boolean;
}

export const GroceryGroupModel = {
    fromJson(json: any): GroceryGroup {
        return {
            id: json?.id?.toString() ?? '',
            name: json?.name ?? 'Unknown Group',
            isShared: json?.isShared ?? true, // Preserving your logic fallback
        };
    },

    toJson(group: GroceryGroup): Record<string, any> {
        return {
            id: group.id,
            name: group.name,
            isShared: group.isShared,
        };
    }
};

// ==========================================================================
// 3. Grocery List Model
// ==========================================================================

export interface GroceryList {
    id: string;
    name: string;
    groupId: string;
    createdAt: Date;
    isArchived: boolean;
}

export const GroceryListModel = {
    fromJson(json: any): GroceryList {
        return {
            id: json?.id as string,
            name: json?.name as string,
            groupId: (json?.GroupId || json?.groupId) as string, // Safeguards Sequelize casing
            createdAt: json?.createdAt ? new Date(json.createdAt) : new Date(),
            isArchived: json?.isArchived ?? false,
        };
    },

    toJson(list: GroceryList): Record<string, any> {
        return {
            id: list.id,
            name: list.name,
            group_id: list.groupId, // Preserves your database snake_case contract
            created_at: list.createdAt.toISOString(),
            is_archived: list.isArchived,
        };
    }
};

// ==========================================================================
// 4. Grocery Item Model & Enums
// ==========================================================================

export type ItemStatus = 'pending' | 'bought' | 'discarded';
export type ItemSortType = 'alphabetical'| 'created'| 'status'| 'hasNote'| 'hasImage';

export interface GroceryItem {
    id?: string;
    name: string;
    status: ItemStatus;
    createdAt: Date;
    listId: string;
    groupId: string;
    addedBy?: string;
    modifiedBy?: string;
    note?: string;
    imagePath?: string;
}

export const GroceryItemModel = {
    fromJson(json: any): GroceryItem {
        return {
            id: json?.id,
            name: json?.name ?? 'Unknown',
            // Checks both PascalCase (Sequelize) and camelCase cross-matching
            listId: json?.ListId?.toString() ?? json?.listId?.toString() ?? '',
            groupId: json?.GroupId?.toString() ?? json?.groupId?.toString() ?? '',
            status: json?.status === 'bought' || json?.status === 'discarded' ? json.status : 'pending',
            createdAt: json?.createdAt ? new Date(json.createdAt) : new Date(),
            note: json?.note,
            imagePath: json?.imagePath,
            addedBy: json?.addedBy,
            modifiedBy: json?.modifiedBy,
        };
    },

    toJson(item: GroceryItem): Record<string, any> {
        return {
            id: item.id,
            name: item.name,
            status: item.status,
            createdAt: item.createdAt.toISOString(),
            listId: item.listId,
            groupId: item.groupId,
            note: item.note,
            imagePath: item.imagePath,
        };
    }
};

// ==========================================================================
// 5. Sync Task Model (For Offline Processing Queue)
// ==========================================================================

export interface SyncTask {
    method: 'POST' | 'PUT' | 'DELETE' | 'PATCH';
    path: string;
    body: Record<string, any> | null;
    timestamp: Date;
}