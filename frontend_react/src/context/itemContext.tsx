import React, { createContext, useContext, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { itemRepository, FilePayload } from '../repositories/itemRepository';
import { GroceryItem, ItemStatus, GroceryItemModel } from '../types/models';

export type ItemSortType = 'alphabetical' | 'created' | 'status' | 'hasNote' | 'hasImage';

interface ItemContextType {
    currentItems: GroceryItem[];
    isLoading: boolean;
    errorMessage: string | null;
    currentListId: string | null;
    currentSort: ItemSortType;
    isInverse: boolean;
    setOpenedList: (listId: string | null) => void;
    setSort: (type: ItemSortType, inverse?: boolean) => Promise<void>;
    loadItems: (listId: string, groupId: string) => Promise<void>;
    addItem: (params: { name: string; listId: string; groupId: string; note?: string; imageFile?: FilePayload }) => Promise<void>;
    toggleStatus: (item: GroceryItem, groupId: string, forceStatus?: ItemStatus) => Promise<void>;
    removeItem: (item: GroceryItem, groupId: string) => Promise<void>;
    updateItemDetails: (params: { item: GroceryItem; newName: string; newNote?: string; newImageFile?: FilePayload; shouldClearImage?: boolean; groupId?: string }) => Promise<void>;
    syncFromSocket: (eventType: string, data: any) => void;
}

const ItemContext = createContext<ItemContextType | undefined>(undefined);

export const ItemProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [currentItems, setCurrentItems] = useState<GroceryItem[]>([]);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);
    const [currentListId, setCurrentListId] = useState<string | null>(null);
    const [currentSort, setCurrentSort] = useState<ItemSortType>('created');
    const [isInverse, setIsInverse] = useState<boolean>(false);

    const setOpenedList = (listId: string | null) => {
        setCurrentListId(listId);
        console.log(`📍 UI State: User is now viewing list: ${listId}`);
    };

    const _sortItems = (items: GroceryItem[], sortType: ItemSortType, inverse: boolean): GroceryItem[] => {
        return [...items].sort((a, b) => {
            let cmp = 0;
            switch (sortType) {
                case 'alphabetical':
                    cmp = a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                    break;
                case 'hasNote':
                    cmp = (b.note?.length ?? 0) - (a.note?.length ?? 0);
                    break;
                case 'hasImage':
                    const aHas = a.imagePath ? 1 : 0;
                    const bHas = b.imagePath ? 1 : 0;
                    cmp = bHas - aHas;
                    break;
                case 'created':
                default:
                    cmp = new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
                    break;
            }
            return inverse ? -cmp : cmp;
        });
    };

    const setSort = async (type: ItemSortType, inverse?: boolean) => {
        const targetInverse = inverse !== undefined ? inverse : isInverse;
        setCurrentSort(type);
        setIsInverse(targetInverse);

        await AsyncStorage.setItem('sort_type', type);
        await AsyncStorage.setItem('sort_inverse', String(targetInverse));

        setCurrentItems(prev => _sortItems(prev, type, targetInverse));
    };

    /**
     * Realtime socket event gateway
     */
    const syncFromSocket = (eventType: string, data: any) => {
        const incomingListId = data?.listId?.toString() ?? data?.ListId?.toString();
        if (currentListId !== incomingListId) return;

        const socketItem = GroceryItemModel.fromJson(data);

        setCurrentItems(prev => {
            let updated = [...prev];

            switch (eventType) {
                case 'item_added': {
                    const exists = updated.some(i => i.id === socketItem.id || (!i.id && i.name === socketItem.name));
                    if (!exists) {
                        updated.unshift(socketItem);
                    } else if (socketItem.id) {
                        const tempIndex = updated.findIndex(i => !i.id && i.name === socketItem.name);
                        if (tempIndex !== -1) updated[tempIndex] = socketItem;
                    }
                    break;
                }
                case 'item_updated': {
                    const index = updated.findIndex(i => i.id === socketItem.id);
                    if (index !== -1) updated[index] = socketItem;
                    break;
                }
                case 'item_removed':
                case 'item_deleted': {
                    updated = updated.filter(i => i.id !== socketItem.id);
                    break;
                }
            }

            return _sortItems(updated, currentSort, isInverse);
        });
    };

    /**
     * STANDARD FETCH
     */
    const loadItems = async (listId: string, groupId: string) => {
        setIsLoading(true);
        setErrorMessage(null);
        try {
            const items = await itemRepository.getItems(listId, groupId);
            setCurrentItems(_sortItems(items, currentSort, isInverse));
        } catch (e) {
            setErrorMessage("Offline: Showing cached items.");
        } finally {
            setIsLoading(false);
        }
    };

    /**
     * OPTIMISTIC ADD ITEM
     */
    const addItem = async ({
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
    }) => {
        const tempItem: GroceryItem = {
            name,
            listId,
            groupId,
            status: 'pending',
            createdAt: new Date(),
            note,
        };

        // UI Updates instantly
        setCurrentItems(prev => [tempItem, ...prev]);

        try {
            await itemRepository.addItemToList({ name, listId, groupId, note, imageFile });
            await loadItems(listId, groupId);
        } catch (error: any) {
            if (error.message?.includes("queued") || error.message?.includes("Offline")) {
                // Graceful fallback: Actions will sync later on
            } else {
                setCurrentItems(prev => prev.filter(i => i !== tempItem));
                setErrorMessage("Failed to add item.");
            }
        }
    };

    /**
     * OPTIMISTIC STATUS TOGGLE
     */
    const toggleStatus = async (item: GroceryItem, groupId: string, forceStatus?: ItemStatus) => {
        const oldStatus = item.status;
        let targetStatus: ItemStatus = oldStatus === 'bought' ? 'pending' : 'bought';

        if (forceStatus) {
            targetStatus = forceStatus;
        }

        // Apply mutation instantly locally
        setCurrentItems(prev =>
            prev.map(i => (i.id === item.id ? { ...i, status: targetStatus } : i))
        );

        try {
            await itemRepository.updateItem({ ...item, status: targetStatus }, groupId);
            setErrorMessage(null);
        } catch (error: any) {
            if (error.message?.includes("queued") || error.message?.includes("Offline")) {
                // Item holds updated state pending background processing
            } else {
                // Rollback on server error rejection
                setCurrentItems(prev =>
                    prev.map(i => (i.id === item.id ? { ...i, status: oldStatus } : i))
                );
                setErrorMessage("Sync failed: Server rejected the change.");
            }
        }
    };

    /**
     * OPTIMISTIC ITEM REMOVAL
     */
    const removeItem = async (item: GroceryItem, groupId: string) => {
        let originalIndex = -1;

        setCurrentItems(prev => {
            originalIndex = prev.findIndex(i => i.id === item.id);
            return prev.filter(i => i.id !== item.id);
        });

        try {
            await itemRepository.deleteItem(item, groupId);
        } catch (error: any) {
            if (error.message?.includes("queued") || error.message?.includes("Offline")) {
                // Action is safely recorded locally
            } else {
                // Re-insert item on standard api failure
                setCurrentItems(prev => {
                    const rolledBack = [...prev];
                    if (originalIndex !== -1) rolledBack.splice(originalIndex, 0, item);
                    return rolledBack;
                });
                setErrorMessage("Could not delete item.");
            }
        }
    };

    /**
     * UPDATE ITEM DETAILS
     */
    const updateItemDetails = async ({
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
        groupId?: string;
    }) => {
        setIsLoading(true);
        try {
            await itemRepository.updateItemDetails({
                item,
                newName,
                newNote,
                newImageFile,
                shouldClearImage,
                groupId: groupId ?? 'default',
            });
            await loadItems(item.listId, groupId ?? 'default');
        } catch (e: any) {
            setErrorMessage(`Update failed: ${e.message}`);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <ItemContext.Provider
            value={{
                currentItems,
                isLoading,
                errorMessage,
                currentListId,
                currentSort,
                isInverse,
                setOpenedList,
                setSort,
                loadItems,
                addItem,
                toggleStatus,
                removeItem,
                updateItemDetails,
                syncFromSocket,
            }}
        >
            {children}
        </ItemContext.Provider>
    );
};

export const useItems = () => {
    const context = useContext(ItemContext);
    if (!context) throw new Error('useItems must be used within an ItemProvider');
    return context;
};