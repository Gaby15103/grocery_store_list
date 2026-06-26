import React, { createContext, useContext, useState, useEffect } from 'react';
import { authRepository } from '@/repositories/authRepository';
import { User } from '@/types/models';
// import messaging from '@react-native-firebase/messaging'; // Uncomment if using React Native Firebase Messaging

interface AuthContextType {
    isLoggedIn: boolean;
    isLoading: boolean;
    userProfile: User | null;
    syncCode: string;
    pendingInvites: any[];
    recentContacts: string[];
    loadProfile: () => Promise<void>;
    register: (fName: string, lName: string, email: string) => Promise<void>;
    updateProfile: (firstName: string, lastName: string, email: string) => Promise<void>;
    linkWithCode: (code: string) => Promise<void>;
    syncTokenWithServer: () => Promise<void>;
    refreshSocialData: () => Promise<void>;
    sendInvitation: (groupId: string, email: string) => Promise<void>;
    fetchInvitations: () => Promise<void>;
    respondToInvitation: (groupId: string, status: string) => Promise<void>;
    logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [isLoggedIn, setIsLoggedIn] = useState<boolean>(false);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [userProfile, setUserProfile] = useState<User | null>(null);
    const [syncCode, setSyncCode] = useState<string>('Not Generated');
    const [pendingInvites, setPendingInvites] = useState<any[]>([]);
    const [recentContacts, setRecentContacts] = useState<string[]>([]);

    // Equivalent to the Flutter Constructor Initialization block
    useEffect(() => {
        const initializeAuth = async () => {
            const loggedIn = await authRepository.isLoggedIn();
            const code = await authRepository.getSyncCode();

            setIsLoggedIn(loggedIn);
            setSyncCode(code);

            if (loggedIn) {
                loadProfile();
            }
        };
        initializeAuth();
    }, []);

    const loadProfile = async () => {
        try {
            const profile = await authRepository.fetchProfile();
            setUserProfile(profile);
        } catch (e) {
            console.error("Could not fetch user profile:", e);
        }
    };

    const register = async (fName: string, lName: string, email: string) => {
        setIsLoading(true);
        try {
            await authRepository.registerUser(fName, lName, email);
            setIsLoggedIn(true);

            // Refresh sync registration code token states
            const code = await authRepository.getSyncCode();
            setSyncCode(code);

            await loadProfile();
        } finally {
            setIsLoading(false);
        }
    };

    const updateProfile = async (firstName: string, lastName: string, email: string) => {
        setIsLoading(true);
        try {
            await authRepository.updateProfile(firstName, lastName, email);
            await loadProfile();
        } finally {
            setIsLoading(false);
        }
    };

    const linkWithCode = async (code: string) => {
        setIsLoading(true);
        try {
            await authRepository.linkAccount(code);
            setIsLoggedIn(true);

            const newCode = await authRepository.getSyncCode();
            setSyncCode(newCode);

            await loadProfile();
        } finally {
            setIsLoading(false);
        }
    };

    const syncTokenWithServer = async () => {
        const email = await authRepository.getEmail();
        if (!email) return;
        try {
            // If using native Firebase Messaging:
            // const token = await messaging().getToken();
            const token = "mock-device-token-string";

            if (token) {
                await authRepository.saveToken(token);
                console.log(`✅ FCM Token synced to DB for ${email}`);
            }
        } catch (e) {
            console.error("❌ Token sync failed:", e);
        }
    };

    const refreshSocialData = async () => {
        try {
            const invites = await authRepository.getInvites();
            const contacts = await authRepository.getContacts();
            setPendingInvites(invites);
            setRecentContacts(contacts);
        } catch (e) {
            console.error("Social sync failed:", e);
        }
    };

    const sendInvitation = async (groupId: string, email: string) => {
        await authRepository.inviteUser(groupId, email);
        await refreshSocialData();
    };

    const fetchInvitations = async () => {
        setIsLoading(true);
        try {
            await refreshSocialData();
        } finally {
            setIsLoading(false);
        }
    };

    const respondToInvitation = async (groupId: string, status: string) => {
        try {
            await authRepository.acceptInvite(groupId, status);

            // Inline filtering optimization replaces removeWhere mutable loops
            setPendingInvites(prev => prev.filter(invite => invite.groupId !== groupId));

            await refreshSocialData();
        } catch (e) {
            console.error("Failed to respond to invitation:", e);
            throw e;
        }
    };

    const logout = async () => {
        await authRepository.clearAllLocalData();
        setIsLoggedIn(false);
        setUserProfile(null);
        setPendingInvites([]);
        setRecentContacts([]);
        setSyncCode('Not Generated');
    };

    return (
        <AuthContext.Provider
            value={{
                isLoggedIn,
                isLoading,
                userProfile,
                syncCode,
                pendingInvites,
                recentContacts,
                loadProfile,
                register,
                updateProfile,
                linkWithCode,
                syncTokenWithServer,
                refreshSocialData,
                sendInvitation,
                fetchInvitations,
                respondToInvitation,
                logout,
            }}
        >
            {children}
        </AuthContext.Provider>
    );
};

// Global shorthand hook to consume context across screen items cleanly
export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) throw new Error('useAuth must be used within an AuthProvider');
    return context;
};