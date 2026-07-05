import {io, Socket} from 'socket.io-client';
import {AppState, NativeEventSubscription} from 'react-native';
import {GroceryItem, GroceryList} from "@/types/models";

// 1. Strictly define schemas for your payloads to replace 'any'
export interface SocketEventPayloads {
    item_added: GroceryItem;
    item_updated: GroceryItem;
    item_deleted: { id: string; name: string; listId: string };
    list_created: GroceryList;
}

export type ValidEvents = keyof SocketEventPayloads;

// Generic listener type mapping events safely to their exact payload structures
export type SocketEventListener<E extends ValidEvents = ValidEvents> = (
    event: E,
    data: SocketEventPayloads[E]
) => void;

export class SocketService {
    private socket: Socket | null = null;
    private eventListeners: Set<SocketEventListener<any>> = new Set();
    private appStateSubscription: NativeEventSubscription | null = null;
    private cachedUserEmail: string | null = null;

    connect(userEmail: string) {
        this.cachedUserEmail = userEmail;

        // 2. Clear previous socket to prevent dangling connection memory leaks
        if (this.socket) {
            this.disconnect();
        }

        // Match Dart lifecycle checks
        if (AppState.currentState !== 'active') {
            console.log("🚫 Skipping Socket Connection: App is in background");
            this.setupAppStateTracking(); // Ensure we listen for when it comes to foreground
            return;
        }

        this.socket = io(__DEV__ ? "http://localhost:3000" : "https://apigrocery.gaby15103.org", {
            transports: ['websocket'],
            autoConnect: false,
            auth: {email: userEmail},
            extraHeaders: {'x-user-email': userEmail}
        });

        this.socket.connect();

        // 3. Strongly typed onAny catch-all router
        this.socket.onAny((event: string, data: any) => {
            const validEvents: ValidEvents[] = ['item_added', 'item_updated', 'item_deleted', 'list_created'];

            if (validEvents.includes(event as ValidEvents)) {
                console.log(`📩 Valid Event: ${event} \n data: ${JSON.stringify(data)}`);
                this.eventListeners.forEach(listener => {
                    listener(event as ValidEvents, data);
                });
            } else {
                console.log(`⚙️ System Socket Event: ${event}`);
            }
        });


        this.socket.on('connect', () => console.log('✅ Socket Connected'));
        this.socket.on('disconnect', (reason) => console.log(`❌ Socket Disconnected: ${reason}`));

        this.setupAppStateTracking();
    }

    // 4. Reactive AppState Handler (replaces Dart App lifecycle system)
    private setupAppStateTracking() {
        if (this.appStateSubscription) return;

        this.appStateSubscription = AppState.addEventListener('change', (nextAppState) => {
            if (nextAppState === 'active' && !this.socket?.connected && this.cachedUserEmail) {
                console.log('🔄 App foregrounded: Connecting socket...');
                this.connect(this.cachedUserEmail);
            } else if (nextAppState !== 'active' && this.socket?.connected) {
                console.log('💤 App backgrounded: Disconnecting socket...');
                this.socket.disconnect();
            }
        });
    }

    subscribe(callback: SocketEventListener<any>) {
        this.eventListeners.add(callback);
        return () => {
            this.eventListeners.delete(callback);
        };
    }

    joinGroup(groupId: string) {
        if (this.socket?.connected) {
            console.log(`🚀 Joining room: ${groupId}`);
            this.socket.emit('join_group', groupId);
        }
    }

    disconnect() {
        // Clean up connection
        if (this.socket) {
            this.socket.removeAllListeners();
            this.socket.disconnect();
            this.socket = null;
        }

        // Clean up lifecycle listeners to avoid native leaks
        if (this.appStateSubscription) {
            this.appStateSubscription.remove();
            this.appStateSubscription = null;
        }

        //this.eventListeners.clear();
        console.log('🔌 SocketService Fully Cleaned & Reset');
    }
}

export const socketService = new SocketService();
