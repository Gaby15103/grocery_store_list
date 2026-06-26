import { io, Socket } from 'socket.io-client';
import { AppState, AppStateStatus } from 'react-native';

type ValidEvents = 'item_added' | 'item_updated' | 'item_deleted' | 'list_created';

export class SocketService {
    private socket: Socket | null = null;
    private eventListeners: Set<(event: ValidEvents, data: any) => void> = new Set();

    connect(userEmail: string) {
        // Match Dart validation checking background state before firing up sockets
        if (AppState.currentState !== 'active') {
            console.log("🚫 Skipping Socket Connection: App is in background");
            return;
        }

        this.socket = io("https://apigrocery.gaby15103.org", {
            transports: ['websocket'],
            autoConnect: false,
            auth: { email: userEmail },
            extraHeaders: { 'x-user-email': userEmail }
        });

        this.socket.connect();

        // Catch-all structural listener equivalent to socket.onAny()
        this.socket.onAny((event: string, data: any) => {
            const validEvents: string[] = ['item_added', 'item_updated', 'item_deleted', 'list_created'];

            if (validEvents.includes(event)) {
                console.log(`📩 Valid Event: ${event}`);
                this.eventListeners.forEach(listener => listener(event as ValidEvents, data));
            } else {
                console.log(`⚙️ System Socket Event: ${event}`);
            }
        });

        this.socket.on('connect', () => console.log('✅ Socket Connected'));
        this.socket.on('disconnect', () => console.log('❌ Socket Disconnected'));
    }

    // Allow repositories or context to subscribe to the stream
    subscribe(callback: (event: ValidEvents, data: any) => void) {
        this.eventListeners.add(callback);
        return () => this.eventListeners.delete(callback); // Unsubscribe clean cleanup function
    }

    joinGroup(groupId: string) {
        if (this.socket?.connected) {
            console.log(`🚀 Joining room: ${groupId}`);
            this.socket.emit('join_group', groupId);
        }
    }

    disconnect() {
        this.socket?.disconnect();
        this.eventListeners.clear();
    }
}

export const socketService = new SocketService();