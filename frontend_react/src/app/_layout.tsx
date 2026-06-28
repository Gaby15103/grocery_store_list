import React, {ReactNode, useEffect, useRef} from 'react';
import '../global.css';
import {AppState, AppStateStatus, StatusBar} from 'react-native';
import {Slot, useRouter, useSegments} from 'expo-router';
import NetInfo from '@react-native-community/netinfo';
import {AuthProvider, useAuth} from "@/context/authContext";
import {GroupProvider, useGroups} from "@/context/groupContext";
import {socketService} from "@/services/socketService";
import {ListProvider} from "@/context/listContext";
import {ThemeProvider} from "@/context/themeContext";
import {PortalHost} from '@rn-primitives/portal';
import {ItemProvider} from "@/context/itemContext";
import {SocketProvider} from "@/context/socketContext";

function AppLifecycleObserver() {
    const {loadGroups} = useGroups();
    const {syncTokenWithServer, isLoggedIn, isLoading, userProfile} = useAuth();
    const appState = useRef(AppState.currentState);
    const router = useRouter();
    const segments = useSegments();

    // 1. Structural Navigation Guard (Auth Gate)
    useEffect(() => {
        if (isLoading) return;

        // Determine if user is currently trying to view setup screen
        const inAuthGroup = segments[0] === 'setup';

        if (!isLoggedIn && !inAuthGroup) {
            router.replace('/setup');
        } else if (isLoggedIn && inAuthGroup) {
            router.replace('/drawer/home');
        }
    }, [isLoggedIn, isLoading, segments]);

    // 2. Resource Lifecycle hooks
    useEffect(() => {
        if (!isLoggedIn) return;

        syncTokenWithServer();

        const unsubscribeNet = NetInfo.addEventListener((state) => {
            if (state.isConnected && state.type !== 'none') {
                console.log('🌐 Internet restored.');
                loadGroups();
            }
        });

        const handleAppStateChange = (nextAppState: AppStateStatus) => {
            if (appState.current.match(/inactive|background/) && nextAppState === 'active' && isLoggedIn) {
                console.log('App resumed: reloading group collections');
                loadGroups();
            }
            appState.current = nextAppState;
        };

        const subscription = AppState.addEventListener('change', handleAppStateChange);

        return () => {
            unsubscribeNet();
            subscription.remove();
        };
    }, [isLoggedIn]);

    return <Slot/>;
}

export default function RootLayout() {
    return (
        <AuthProvider>
            <AuthenticatedAppContent />
        </AuthProvider>
    );
}
function AuthenticatedAppContent() {
    const { userProfile, isLoggedIn } = useAuth();

    const activeEmail = isLoggedIn ? userProfile?.email : null;

    return (
        <SocketProvider userEmail={activeEmail || null}>
            <GroupProvider>
                <ListProvider>
                    <ThemeProvider>
                        <ItemProvider>
                            <AppLifecycleObserver />
                            <PortalHost />
                        </ItemProvider>
                    </ThemeProvider>
                </ListProvider>
            </GroupProvider>
        </SocketProvider>
    );
}