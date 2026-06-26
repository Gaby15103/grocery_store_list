import React, { createContext, useContext, useState } from 'react';
import { GroceryList } from '@/types/models';
import {listRepository} from "@/repositories/ListRepository";

interface ListContextType {
    lists: GroceryList[];
    isLoading: boolean;
    currentListId: string | null;
    loadLists: (groupId: string, isShared: boolean) => Promise<void>;
    setOpenedList: (id: string | null) => void;
    createList: (name: string, groupId: string, isShared: boolean) => Promise<void>;
    deleteList: (listId: string, groupId: string, isShared: boolean) => Promise<void>;
    archiveList: (listId: string, newName: string, groupId: string, isShared: boolean) => Promise<void>;
}

const ListContext = createContext<ListContextType | undefined>(undefined);

export const ListProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [lists, setLists] = useState<GroceryList[]>([]);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [currentListId, setCurrentListId] = useState<string | null>(null);

    /**
     * Fetch lists and sort them by descending creation date (newest first)
     */
    const loadLists = async (groupId: string, isShared: boolean) => {
        setIsLoading(true);
        try {
            const refreshedLists = await listRepository.getLists(groupId, isShared);

            // Mimics: b.createdAt.compareTo(a.createdAt)
            const sortedLists = [...refreshedLists].sort(
                (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
            );

            setLists(sortedLists);
        } finally {
            setIsLoading(false);
        }
    };

    const setOpenedList = (id: string | null) => {
        setCurrentListId(id);
    };

    const createList = async (name: string, groupId: string, isShared: boolean) => {
        await listRepository.addList(name, groupId, isShared);
        await loadLists(groupId, isShared);
    };

    const deleteList = async (listId: string, groupId: string, isShared: boolean) => {
        await listRepository.removeList(listId, isShared);
        await loadLists(groupId, isShared);
    };

    const archiveList = async (listId: string, newName: string, groupId: string, isShared: boolean) => {
        setIsLoading(true);
        try {
            const newList = await listRepository.archiveAndCarryOver(listId, newName, groupId, isShared);

            setOpenedList(newList.id);

            await loadLists(groupId, isShared);
        } catch (e) {
            console.error("Archive Error:", e);
            throw e;
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <ListContext.Provider
            value={{
                lists,
                isLoading,
                currentListId,
                loadLists,
                setOpenedList,
                createList,
                deleteList,
                archiveList,
            }}
        >
            {children}
        </ListContext.Provider>
    );
};

export const useLists = () => {
    const context = useContext(ListContext);
    if (!context) throw new Error('useLists must be used within a ListProvider');
    return context;
};