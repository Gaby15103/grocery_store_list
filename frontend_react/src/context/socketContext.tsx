import React, { createContext, useContext, useEffect, ReactNode } from 'react';
import { socketService, SocketEventListener, SocketEventPayloads, ValidEvents } from "@/services/socketService";

interface SocketContextType {
    joinGroup: (groupId: string) => void;
    subscribeToEvents: (callback: SocketEventListener) => () => void;
}

const SocketContext = createContext<SocketContextType | null>(null);

interface SocketProviderProps {
    children: ReactNode;
    userEmail: string | null;
}

export const SocketProvider = ({ children, userEmail }: SocketProviderProps) => {
    useEffect(() => {
        if (userEmail) {
            socketService.connect(userEmail);
        }

        return () => {
            socketService.disconnect();
        };
    }, [userEmail]);

    const joinGroup = (groupId: string) => {
        socketService.joinGroup(groupId);
    };

    const subscribeToEvents = (callback: SocketEventListener) => {
        return socketService.subscribe(callback);
    };

    return (
        <SocketContext.Provider value={{ joinGroup, subscribeToEvents }}>
            {children}
        </SocketContext.Provider>
    );
};

export const useSocket = () => {
    const context = useContext(SocketContext);
    if (!context) {
        throw new Error('useSocket must be used within a SocketProvider');
    }
    return context;
};

export function useSocketEvent<E extends ValidEvents>(
    targetEvent: E,
    callback: (data: SocketEventPayloads[E]) => void
) {
    const { subscribeToEvents } = useSocket();

    const savedCallback = React.useRef(callback);

    useEffect(() => {
        savedCallback.current = callback;
    }, [callback]);

    useEffect(() => {
        const handleIncomingPayload = (event: ValidEvents, data: any) => {
            if (event === targetEvent) {
                console.log(`🎯 HOOK MATCHED! Event "${event}" is being sent to your component. \n dat ${JSON.stringify(data)}`);
                savedCallback.current(data as SocketEventPayloads[E]);
            }
        };

        const unsubscribe = subscribeToEvents(handleIncomingPayload);
        return () => {
            console.log(`🔌 Unsubscribing hook from event: ${targetEvent}`);
            unsubscribe();
        };
    }, [targetEvent, subscribeToEvents]); // Removed callback from dependencies safely
}
