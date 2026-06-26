import AsyncStorage from '@react-native-async-storage/async-storage';

export interface SyncTask {
    id: string;
    method: 'POST' | 'PUT' | 'DELETE' | 'PATCH';
    path: string;
    body: Record<string, any> | null;
}

class SyncManager {
    private readonly STORAGE_KEY = 'sync_queue';
    private isProcessing = false;

    /**
     * Enqueues a mutations task to AsyncStorage for offline fallback
     */
    async enqueue(method: SyncTask['method'], path: string, body: any): Promise<void> {
        try {
            const queue = await this.getQueue();

            const newTask: SyncTask = {
                id: Math.random().toString(36).substring(2, 9) + Date.now().toString(),
                method,
                path,
                body: body || null,
            };

            queue.push(newTask);
            await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify(queue));
            console.log(`📥 Task queued offline: ${method} ${path}`);
        } catch (error) {
            console.error('❌ Failed to enqueue offline task:', error);
        }
    }

    /**
     * Processes the backlog queue sequentially when connection returns
     */
    async processQueue(apiInstance: any): Promise<void> {
        if (this.isProcessing) return;

        const queue = await this.getQueue();
        if (queue.length === 0) return;

        this.isProcessing = true;
        console.log(`🔄 Processing offline sync queue (${queue.length} tasks)...`);

        const remainingTasks = [...queue];

        for (const task of queue) {
            try {
                await apiInstance.request({
                    method: task.method,
                    path: task.path,
                    body: task.body,
                });

                remainingTasks.shift();
                await AsyncStorage.setItem(this.STORAGE_KEY, JSON.stringify(remainingTasks));
                console.log(`✅ Replay success for: ${task.path}`);
            } catch (error) {
                console.error(`❌ Replay failed for ${task.path}:`, error);
                break;
            }
        }

        this.isProcessing = false;
    }

    /**
     * Helper to retrieve and parse the current queue array safely
     */
    async getQueue(): Promise<SyncTask[]> {
        try {
            const storedQueue = await AsyncStorage.getItem(this.STORAGE_KEY);
            return storedQueue ? (JSON.parse(storedQueue) as SyncTask[]) : [];
        } catch (_) {
            return [];
        }
    }
}

export const syncManager = new SyncManager();