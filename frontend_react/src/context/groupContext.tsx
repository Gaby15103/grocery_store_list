import React, { createContext, useContext, useState, useEffect } from 'react';
import { groupRepository } from '@/repositories/groupRepository';
import { GroceryGroup } from '@/types/models';
import { socketService } from '@/services/socketService';

interface GroupContextType {
    groups: GroceryGroup[];
    activeGroupId: string;
    isLoading: boolean;
    isCurrentGroupShared: boolean;
    loadGroups: () => Promise<void>;
    changeActiveGroup: (id: string) => Promise<void>;
    makeGroupPublic: (id: string) => Promise<void>;
    handleShareAction: (group: GroceryGroup) => void;
    createGroup: (name: string) => Promise<string>;
    deleteGroup: (id: string) => Promise<void>;
}

const GroupContext = createContext<GroupContextType | undefined>(undefined);

export const GroupProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [groups, setGroups] = useState<GroceryGroup[]>([]);
    const [activeGroupId, setActiveGroupId] = useState<string>('default');
    const [isLoading, setIsLoading] = useState<boolean>(false);

    useEffect(() => {
        const initializeGroups = async () => {
            await groupRepository.refreshGroups();
            const cachedGroups = await groupRepository.getCachedGroups();
            const activeId = await groupRepository.getActiveGroupId();

            setGroups(cachedGroups);
            setActiveGroupId(activeId);

            if (activeId && activeId !== 'default') {
                socketService.joinGroup(activeId);
            }
        };

        initializeGroups();
    }, []);

    const isCurrentGroupShared = (() => {
        const currentGroup = groups.find(g => g.id === activeGroupId);
        console.log('currentGroup', currentGroup);
        return currentGroup ? currentGroup.isShared : false;
    })();

    /**
     * Called by the UI (e.g., Pull-to-Refresh)
     */
    const loadGroups = async () => {
        setIsLoading(true);
        try {
            const refreshedGroups = await groupRepository.refreshGroups();
            setGroups(refreshedGroups);
        } finally {
            setIsLoading(false);
        }
    };

    /**
     * Changes the active group and handles the Socket Room swap
     */
    const changeActiveGroup = async (id: string) => {
        await groupRepository.saveActiveGroupId(id);
        setActiveGroupId(id);
        socketService.joinGroup(id);
    };

    const makeGroupPublic = async (id: string) => {
        setIsLoading(true);
        try {
            await groupRepository.makeGroupPublic(id);
            await loadGroups();
        } finally {
            setIsLoading(false);
        }
    };

    /**
     * Handles contextual sharing rules for the top-right header action button
     */
    const handleShareAction = (group: GroceryGroup) => {
        if (group.isShared) {
            // Trigger intended context layer when your invitations system hooks up
            console.log("Opening share panel for group:", group.id);
        } else {
            makeGroupPublic(group.id);
        }
    };

    const createGroup = async (name: string) => {
        setIsLoading(true);
        let group_id = '';
        try {
            group_id = await groupRepository.createGroup(name);
            await loadGroups();
        } finally {
            setIsLoading(false);
        }
        return group_id;
    };

    const deleteGroup = async (id: string) => {
        setIsLoading(true);
        try {
            await groupRepository.removeGroup(id);

            const nextActiveId = await groupRepository.getActiveGroupId();
            setActiveGroupId(nextActiveId);

            await loadGroups();
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <GroupContext.Provider
            value={{
                groups,
                activeGroupId,
                isLoading,
                isCurrentGroupShared,
                loadGroups,
                changeActiveGroup,
                makeGroupPublic,
                handleShareAction,
                createGroup,
                deleteGroup,
            }}
        >
            {children}
        </GroupContext.Provider>
    );
};

export const useGroups = () => {
    const context = useContext(GroupContext);
    if (!context) throw new Error('useGroups must be used within a GroupProvider');
    return context;
};