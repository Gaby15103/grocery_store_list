import React, { useEffect, useRef, useState } from 'react';
import {
    View,
    Text,
    StyleSheet,
    FlatList,
    TouchableOpacity,
    Modal,
    TextInput,
    ActivityIndicator,
    Platform,
    Alert,
    KeyboardAvoidingView,
    ScrollView
} from 'react-native';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { ChevronRight } from 'lucide-react-native';
import { useGroups } from "@/context/groupContext";
import { useLists } from "@/context/listContext";
import {GroceryItem, GroceryList} from "@/types/models";
import { useTheme } from "@/context/themeContext";
import { Ionicons } from "@expo/vector-icons";
import { useAuth } from "@/context/authContext";
import {useSocketEvent} from "@/context/socketContext";

export default function ListSelectionScreen() {
    const { groupId, refreshKey } = useLocalSearchParams<{ groupId: string; refreshKey: string }>();
    const { groups } = useGroups();
    const { recentContacts, sendInvitation, refreshSocialData } = useAuth();
    const { loadLists, lists } = useLists();
    const { colors } = useTheme();

    const [selectedEmails, setSelectedEmails] = useState<string[]>([]);
    const [manualEmail, setManualEmail] = useState('');
    const [searchQuery, setSearchQuery] = useState('');
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [invitationVisible, setInvitationVisible] = useState(false);
    const lastLoadedGroupId = useRef<string | null>(null);

    useEffect(() => {
        if (groupId) {
            lastLoadedGroupId.current = groupId;
            loadLists(groupId, true);
        }
        return () => {
            if (!groupId) {
                lastLoadedGroupId.current = null;
            }
        };
    }, [groupId, refreshKey]);

    useSocketEvent('list_created', (list: GroceryList) => {
        if (list.groupId === groupId ) {
            lists.push(list);
        }
    });

    const handleAddManualEmail = () => {
        const email = manualEmail.trim().toLowerCase();
        if (email.includes('@') && !selectedEmails.includes(email)) {
            setSelectedEmails([...selectedEmails, email]);
            setManualEmail('');
        }
    };

    const handleToggleContact = (email: string) => {
        if (selectedEmails.includes(email)) {
            setSelectedEmails(selectedEmails.filter(e => e !== email));
        } else {
            setSelectedEmails([...selectedEmails, email]);
        }
    };

    const handleRemoveChip = (email: string) => {
        setSelectedEmails(selectedEmails.filter(e => e !== email));
    };

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
            setInvitationVisible(false);
            setSelectedEmails([]);
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

    const onPress = (listId: string) => {
        router.replace({
            pathname: '/drawer/grocery_list_view',
            params: {
                sessionId: listId,
                refreshKey: Date.now().toString()
            }
        });
    };

    const currentGroupName = groups.find(g => g.id == groupId)?.name || "Group";

    const renderItem = ({ item }: { item: GroceryList }) => {
        const dateObj = new Date(item.createdAt);
        const day = String(dateObj.getDate()).padStart(2, '0');
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const year = dateObj.getFullYear();
        const dataString = `${day}/${month}/${year}`;

        return (
            <TouchableOpacity onPress={() => onPress(item.id)} style={[styles.item, { backgroundColor: colors.card, borderColor: colors.border }]}>
                <View style={styles.textContainer}>
                    <Text style={[styles.title, { color: colors.text }]}>{item.name}</Text>
                    <Text style={[styles.data, { color: colors.subtext }]}>Créée le {dataString}</Text>
                </View>
                <ChevronRight size={20} color={colors.subtext} />
            </TouchableOpacity>
        );
    };

    return (
        <View style={{ backgroundColor: colors.background, flex: 1 }}>
            <Stack.Screen
                options={{
                    headerLeft: () => (
                        <TouchableOpacity
                            onPress={() => router.replace({ pathname: '/drawer/home' })}
                            style={{ marginLeft: 16, marginRight: 5 }}
                        >
                            <Ionicons name="arrow-back" size={24} color={colors.text} />
                        </TouchableOpacity>
                    ),
                    headerRight: () => (
                        groupId ? (
                            <TouchableOpacity
                                onPress={() => {
                                    refreshSocialData();
                                    setInvitationVisible(true);
                                }}
                                style={{ marginRight: 16 }}
                            >
                                <Ionicons name="person-add" size={24} color={colors.text} />
                            </TouchableOpacity>
                        ) : null
                    )
                }}
            />

            <FlatList
                data={lists}
                renderItem={renderItem}
                keyExtractor={(item) => item.id}
                contentContainerStyle={styles.listContent}
            />

            {/* Repositioned & Refined Invitation Bottom Sheet */}
            <Modal
                transparent
                visible={invitationVisible}
                animationType="slide"
                onRequestClose={() => setInvitationVisible(false)}
            >
                <KeyboardAvoidingView
                    behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                    style={styles.modalOverlay}
                >
                    {/* Background overlay tap to dismiss */}
                    <TouchableOpacity
                        style={StyleSheet.absoluteFill}
                        activeOpacity={1}
                        onPress={() => setInvitationVisible(false)}
                    />

                    <View style={[styles.bottomSheet, { backgroundColor: colors.card }]}>
                        {/* Elegant Pill Handle Indicator */}
                        <View style={[styles.panelHandle, { backgroundColor: colors.border }]} />

                        <View style={styles.sheetHeader}>
                            <View style={{ flex: 1 }}>
                                <Text style={[styles.sheetTitle, { color: colors.text }]}>Invite by Email</Text>
                                <Text style={[styles.sheetSubtitle, { color: colors.subtext }]}>{currentGroupName}</Text>
                            </View>
                            <TouchableOpacity
                                onPress={() => setInvitationVisible(false)}
                                style={[styles.closeIconButton, { backgroundColor: colors.inputBg }]}
                            >
                                <Ionicons name="close" size={20} color={colors.text} />
                            </TouchableOpacity>
                        </View>

                        <View style={[styles.separator, { backgroundColor: colors.border }]} />

                        <ScrollView
                            showsVerticalScrollIndicator={false}
                            contentContainerStyle={{ paddingBottom: 16 }}
                        >
                            {/* Manual Email Input */}
                            <View style={styles.row}>
                                <TextInput
                                    style={[styles.input, { backgroundColor: colors.inputBg, borderColor: colors.inputBorder, color: colors.text }]}
                                    placeholder="Enter email address..."
                                    placeholderTextColor={colors.subtext}
                                    value={manualEmail}
                                    onChangeText={setManualEmail}
                                    keyboardType="email-address"
                                    autoCapitalize="none"
                                    autoCorrect={false}
                                />
                                <TouchableOpacity onPress={handleAddManualEmail} style={styles.addButton}>
                                    <Ionicons name="add-circle" size={36} color={colors.primary || "#007AFF"} />
                                </TouchableOpacity>
                            </View>

                            {/* Section: Recent Contacts */}
                            <Text style={[styles.sectionTitle, { color: colors.text }]}>Recent Contacts</Text>
                            <View style={[styles.searchBarContainer, { backgroundColor: colors.inputBg, borderColor: colors.inputBorder }]}>
                                <Ionicons name="search" size={18} color={colors.subtext} style={styles.searchIcon} />
                                <TextInput
                                    style={[styles.searchInput, { color: colors.text }]}
                                    placeholder="Search recent..."
                                    placeholderTextColor={colors.subtext}
                                    value={searchQuery}
                                    onChangeText={setSearchQuery}
                                    autoCapitalize="none"
                                />
                            </View>

                            <View style={[styles.contactsBox, { backgroundColor: colors.inputBg, borderColor: colors.border }]}>
                                {filteredContacts.length === 0 ? (
                                    <Text style={[styles.emptyText, { color: colors.subtext }]}>No recent contacts found</Text>
                                ) : (
                                    filteredContacts.map((email) => {
                                        const isChecked = selectedEmails.includes(email);
                                        return (
                                            <TouchableOpacity
                                                key={email}
                                                style={[styles.checkboxRow, { borderBottomColor: colors.border }]}
                                                onPress={() => handleToggleContact(email)}
                                            >
                                                <Ionicons
                                                    name={isChecked ? "checkbox" : "square-outline"}
                                                    size={22}
                                                    color={isChecked ? (colors.primary || "#007AFF") : colors.subtext}
                                                />
                                                <Text style={[styles.contactEmail, { color: colors.text }]}>{email}</Text>
                                            </TouchableOpacity>
                                        );
                                    })
                                )}
                            </View>

                            {/* Chips Section */}
                            {selectedEmails.length > 0 && (
                                <View style={styles.chipSection}>
                                    <Text style={[styles.chipTitle, { color: colors.subtext }]}>Selected to Invite:</Text>
                                    <View style={styles.chipWrapper}>
                                        {selectedEmails.map((email) => (
                                            <View key={email} style={[styles.chip, { backgroundColor: colors.background, borderColor: colors.border }]}>
                                                <Text style={[styles.chipText, { color: colors.text }]}>{email}</Text>
                                                <TouchableOpacity onPress={() => handleRemoveChip(email)}>
                                                    <Ionicons name="close-circle" size={16} color="#ef4444" style={{ marginLeft: 6 }} />
                                                </TouchableOpacity>
                                            </View>
                                        ))}
                                    </View>
                                </View>
                            )}
                        </ScrollView>

                        {/* Unified Primary Action Button */}
                        <View style={styles.actionRow}>
                            <TouchableOpacity
                                onPress={handleSendAllInvitations}
                                disabled={selectedEmails.length === 0 || isSubmitting}
                                style={[
                                    styles.btn,
                                    { backgroundColor: colors.primary || "#007AFF" },
                                    selectedEmails.length === 0 && { backgroundColor: colors.border }
                                ]}
                            >
                                {isSubmitting ? (
                                    <ActivityIndicator color="white" size="small" />
                                ) : (
                                    <Text style={styles.btnConfirmText}>
                                        Send Invite {selectedEmails.length > 0 ? `(${selectedEmails.length})` : ''}
                                    </Text>
                                )}
                            </TouchableOpacity>
                        </View>
                    </View>
                </KeyboardAvoidingView>
            </Modal>
        </View>
    );
}

const styles = StyleSheet.create({
    modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    bottomSheet: {
        borderTopLeftRadius: 24,
        borderTopRightRadius: 24,
        paddingHorizontal: 24,
        paddingTop: 12,
        paddingBottom: Platform.OS === 'ios' ? 40 : 24,
        height: '75%',
        maxHeight: '85%',
    },
    scrollableContent: {
        flex: 1,
    },
    contactsBox: {
        borderWidth: 1,
        borderRadius: 10,
    },
    actionRow: {
        marginTop: 10,
        paddingTop: 10,
    },
    panelHandle: {
        width: 40,
        height: 5,
        borderRadius: 3,
        alignSelf: 'center',
        marginBottom: 14,
    },
    sheetHeader: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 14
    },
    sheetTitle: { fontSize: 20, fontWeight: '700' },
    sheetSubtitle: { fontSize: 14, marginTop: 2 },
    closeIconButton: {
        padding: 8,
        borderRadius: 20,
    },
    separator: { height: 1, marginBottom: 18 },
    sectionTitle: { fontSize: 14, fontWeight: '600', marginBottom: 8, marginTop: 10 },
    row: { flexDirection: 'row', alignItems: 'center', marginBottom: 14 },
    input: { flex: 1, height: 46, borderWidth: 1, borderRadius: 10, paddingHorizontal: 14, fontSize: 15 },
    addButton: { marginLeft: 10 },
    searchBarContainer: { flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderRadius: 10, paddingHorizontal: 12, height: 42, marginBottom: 12 },
    searchIcon: { marginRight: 8 },
    searchInput: { flex: 1, height: '100%', fontSize: 14 },
    emptyText: { textAlign: 'center', padding: 24, fontSize: 14 },
    checkboxRow: { flexDirection: 'row', alignItems: 'center', padding: 14, borderBottomWidth: 1 },
    contactEmail: { marginLeft: 12, fontSize: 15 },
    chipSection: { marginTop: 14 },
    chipTitle: { fontSize: 13, fontWeight: '500', marginBottom: 8 },
    chipWrapper: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
    chip: { flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderRadius: 16, paddingVertical: 6, paddingHorizontal: 12 },
    chipText: { fontSize: 13 },
    btn: { height: 50, borderRadius: 12, alignItems: 'center', justifyContent: 'center', width: '100%' },
    btnConfirmText: { color: 'white', fontWeight: '600', fontSize: 16 },
    listContent: { paddingHorizontal: 16, paddingVertical: 12 },
    item: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 16,
        paddingHorizontal: 16,
        marginVertical: 6,
        borderRadius: 12,
        borderWidth: 1,
    },
    textContainer: { flex: 1 },
    title: { fontSize: 17, fontWeight: '600', marginBottom: 4 },
    data: { fontSize: 13 }
});