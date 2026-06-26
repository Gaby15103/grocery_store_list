import React, { useEffect, useState } from 'react';
import {View, FlatList, StyleSheet, TouchableOpacity} from 'react-native';
import { Text, List, IconButton, ActivityIndicator, Divider } from 'react-native-paper';
import { useAuth } from '@/context/authContext';
import { useGroups } from '@/context/groupContext';
import {useTheme} from "@/context/themeContext";
import {router} from "expo-router";

export default function InvitationsScreen() {
    const { pendingInvites, respondToInvitation, refreshSocialData } = useAuth();
    const { loadGroups } = useGroups();
    const { colors } = useTheme();
    const [processingId, setProcessingId] = useState<string | null>(null);

    useEffect(() => {
        refreshSocialData();
    }, []);

    const handleResponse = async (groupId: string, status: 'accepted' | 'declined') => {
        setProcessingId(groupId);
        try {
            await respondToInvitation(groupId, status);
            if (status === 'accepted') {
                await loadGroups();
            }
        } catch (error) {
            console.error(error);
        } finally {
            setProcessingId(null);
        }
    };

    if (pendingInvites.length === 0) {
        return (
            <View style={[styles.centered, {backgroundColor: colors.primary}]}>
                <TouchableOpacity onPress={() => router.back()} style={[styles.btn, styles.btnCancel]}>
                    <Text style={styles.btnCancelText}>Return</Text>
                </TouchableOpacity>
                <List.Icon icon="email-outline" color="orange" />
                <Text variant="bodyMedium">No pending invitations found.</Text>
            </View>
        );
    }

    return (
        <FlatList
            data={pendingInvites}
            keyExtractor={(item) => item.groupId}
            ItemSeparatorComponent={Divider}
            renderItem={({ item }) => (
                <List.Item
                    title={item.GroupName ?? 'Unnamed Group'}
                    description={`From: ${item.OwnerEmail}`}
                    right={(props) => (
                        <View style={styles.actionRow}>
                            {processingId === item.groupId ? (
                                <ActivityIndicator size="small" />
                            ) : (
                                <>
                                    <IconButton
                                        icon="check-circle"
                                        iconColor="green"
                                        onPress={() => handleResponse(item.groupId, 'accepted')}
                                    />
                                    <IconButton
                                        icon="cancel"
                                        iconColor="red"
                                        onPress={() => handleResponse(item.groupId, 'declined')}
                                    />
                                </>
                            )}
                        </View>
                    )}
                />
            )}
        />
    );
}

const styles = StyleSheet.create({
    centered: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 },
    actionRow: { flexDirection: 'row', alignItems: 'center' },
    btnCancelText: { color: '#007AFF', fontWeight: '600' },
    btn: { paddingVertical: 12, paddingHorizontal: 20, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
    btnCancel: { backgroundColor: '#f2f2f7' },
});