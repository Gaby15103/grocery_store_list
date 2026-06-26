import React, { useState } from 'react';
import {
    View,
    Text,
    StyleSheet,
    TextInput,
    TouchableOpacity,
    ScrollView,
    ActivityIndicator,
    Alert,
    Platform
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useAuth } from '@/context/authContext';

export default function SendInviteModal() {
    const router = useRouter();
    const { groupId } = useLocalSearchParams<{ groupId: string }>();
    const { recentContacts, sendInvitation } = useAuth(); // Gathered from your Auth context provider

    const [selectedEmails, setSelectedEmails] = useState<string[]>([]);
    const [manualEmail, setManualEmail] = useState('');
    const [searchQuery, setSearchQuery] = useState('');
    const [isSubmitting, setIsSubmitting] = useState(false);

    // 1. Add Email directly from text field
    const handleAddManualEmail = () => {
        const email = manualEmail.trim().toLowerCase();
        if (email.includes('@') && !selectedEmails.includes(email)) {
            setSelectedEmails([...selectedEmails, email]);
            setManualEmail('');
        }
    };

    // 2. Toggle emails selected from the contacts checklist
    const handleToggleContact = (email: string) => {
        if (selectedEmails.includes(email)) {
            setSelectedEmails(selectedEmails.filter(e => e !== email));
        } else {
            setSelectedEmails([...selectedEmails, email]);
        }
    };

    // 3. Remove chip
    const handleRemoveChip = (email: string) => {
        setSelectedEmails(selectedEmails.filter(e => e !== email));
    };

    // 4. Batch dispatch invitations
    const handleSendAllInvitations = async () => {
        if (!groupId || selectedEmails.length === 0) return;

        setIsSubmitting(true);
        try {
            for (const email of selectedEmails) {
                await sendInvitation(groupId, email);
            }

            if (Platform.OS === 'web') {
                window.alert("Invitations sent successfully!");
            } else {
                Alert.alert("Success", "Invitations sent successfully!");
            }
            router.back();
        } catch (error) {
            const msg = error instanceof Error ? error.message : String(error);
            if (Platform.OS === 'web') {
                window.alert(`Failed to send: ${msg}`);
            } else {
                Alert.alert("Error", `Failed to send: ${msg}`);
            }
        } finally {
            setIsSubmitting(false);
        }
    };

    const filteredContacts = (recentContacts || []).filter(email =>
        email.toLowerCase().includes(searchQuery.toLowerCase())
    );

    return (
        <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
            <Text style={styles.sectionTitle}>Invite by Email</Text>
            <View style={styles.row}>
                <TextInput
                    style={styles.input}
                    placeholder="Enter email address..."
                    placeholderTextColor="#8e8e93"
                    value={manualEmail}
                    onChangeText={setManualEmail}
                    keyboardType="email-address"
                    autoCapitalize="none"
                    autoCorrect={false}
                />
                <TouchableOpacity onPress={handleAddManualEmail} style={styles.addButton}>
                    <Ionicons name="add-circle" size={32} color="#007AFF" />
                </TouchableOpacity>
            </View>

            <Text style={styles.sectionTitle}>Recent Contacts</Text>
            <View style={styles.searchBarContainer}>
                <Ionicons name="search" size={18} color="#8e8e93" style={styles.searchIcon} />
                <TextInput
                    style={styles.searchInput}
                    placeholder="Search recent..."
                    placeholderTextColor="#8e8e93"
                    value={searchQuery}
                    onChangeText={setSearchQuery}
                    autoCapitalize="none"
                />
            </View>

            <View style={styles.contactsBox}>
                {filteredContacts.length === 0 ? (
                    <Text style={styles.emptyText}>No recent contacts found</Text>
                ) : (
                    filteredContacts.map((email) => {
                        const isChecked = selectedEmails.includes(email);
                        return (
                            <TouchableOpacity
                                key={email}
                                style={styles.checkboxRow}
                                onPress={() => handleToggleContact(email)}
                            >
                                <Ionicons
                                    name={isChecked ? "checkbox" : "square-outline"}
                                    size={20}
                                    color={isChecked ? "#007AFF" : "#8e8e93"}
                                />
                                <Text style={styles.contactEmail}>{email}</Text>
                            </TouchableOpacity>
                        );
                    })
                )}
            </View>

            {selectedEmails.length > 0 && (
                <View style={styles.chipSection}>
                    <Text style={styles.chipTitle}>Selected to Invite:</Text>
                    <View style={styles.chipWrapper}>
                        {selectedEmails.map((email) => (
                            <View key={email} style={styles.chip}>
                                <Text style={styles.chipText}>{email}</Text>
                                <TouchableOpacity onPress={() => handleRemoveChip(email)}>
                                    <Ionicons name="close-circle" size={16} color="red" style={{ marginLeft: 6 }} />
                                </TouchableOpacity>
                            </View>
                        ))}
                    </View>
                </View>
            )}

            <View style={styles.actionRow}>
                <TouchableOpacity onPress={() => router.back()} style={[styles.btn, styles.btnCancel]}>
                    <Text style={styles.btnCancelText}>Cancel</Text>
                </TouchableOpacity>
                <TouchableOpacity
                    onPress={handleSendAllInvitations}
                    disabled={selectedEmails.length === 0 || isSubmitting}
                    style={[
                        styles.btn,
                        styles.btnConfirm,
                        selectedEmails.length === 0 && styles.btnDisabled
                    ]}
                >
                    {isSubmitting ? (
                        <ActivityIndicator color="white" size="small" />
                    ) : (
                        <Text style={styles.btnConfirmText}>Invite ({selectedEmails.length})</Text>
                    )}
                </TouchableOpacity>
            </View>
        </ScrollView>
    );
}

const styles = StyleSheet.create({
    container: { flex: 1, backgroundColor: '#fff', padding: 16 },
    sectionTitle: { fontSize: 14, fontWeight: 'bold', color: '#1c1c1e', marginBottom: 8, marginTop: 12 },
    row: { flexDirection: 'row', alignItems: 'center', marginBottom: 16 },
    input: { flex: 1, height: 44, borderWidth: 1, borderColor: '#e5e5ea', borderRadius: 8, paddingHorizontal: 12, color: '#1c1c1e' },
    addButton: { marginLeft: 8, justifyContent: 'center', alignItems: 'center' },
    searchBarContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#f2f2f7', borderRadius: 8, paddingHorizontal: 10, height: 40, marginBottom: 10 },
    searchIcon: { marginRight: 6 },
    searchInput: { flex: 1, height: '100%', color: '#1c1c1e' },
    contactsBox: { borderWidth: 1, borderColor: '#e5e5ea', borderRadius: 8, maxHeight: 150, overflow: 'scroll' },
    emptyText: { textAlign: 'center', padding: 20, color: '#8e8e93', fontSize: 13 },
    checkboxRow: { flexDirection: 'row', alignItems: 'center', padding: 12, borderBottomWidth: 1, borderBottomColor: '#f2f2f7' },
    contactEmail: { marginLeft: 12, fontSize: 14, color: '#1c1c1e' },
    chipSection: { marginTop: 16 },
    chipTitle: { fontSize: 12, fontWeight: 'bold', color: '#8e8e93', marginBottom: 8 },
    chipWrapper: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
    chip: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#f2f2f7', borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
    chipText: { fontSize: 12, color: '#1c1c1e' },
    actionRow: { flexDirection: 'row', justifyContent: 'flex-end', marginTop: 30, marginBottom: 40, gap: 12 },
    btn: { paddingVertical: 12, paddingHorizontal: 20, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
    btnCancel: { backgroundColor: '#f2f2f7' },
    btnCancelText: { color: '#007AFF', fontWeight: '600' },
    btnConfirm: { backgroundColor: '#007AFF', minWidth: 100 },
    btnConfirmText: { color: 'white', fontWeight: '600' },
    btnDisabled: { backgroundColor: '#b3d7ff' }
});