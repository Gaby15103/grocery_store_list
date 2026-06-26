import React, { useState, useEffect } from 'react';
import {
    View,
    Text,
    StyleSheet,
    FlatList,
    ActivityIndicator,
    TouchableOpacity,
    Modal,
    TextInput,
    Image,
    Alert,
    KeyboardAvoidingView,
    Platform,
    TouchableWithoutFeedback,
    Keyboard
} from 'react-native';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';

import { useItems } from "@/context/itemContext";
import { useGroups } from "@/context/groupContext";
import { useLists } from "@/context/listContext";
import { useTheme } from "@/context/themeContext";
import { GroceryItem, ItemStatus } from "@/types/models";

export default function GroceryListScreen() {
    const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
    const router = useRouter();
    const { colors } = useTheme();

    const {
        currentItems,
        isLoading,
        isInverse,
        currentSort,
        loadItems,
        addItem,
        updateItemDetails,
        removeItem,
        toggleStatus,
        setSort,
        applySort,
        setOpenedList
    } = useItems();
    const { activeGroupId, isCurrentGroupShared } = useGroups();
    const { archiveList, currentListId } = useLists();

    // Dialog & UI Visibility states
    const [addModalVisible, setAddModalVisible] = useState(false);
    const [editModalVisible, setEditModalVisible] = useState(false);
    const [sortSheetVisible, setSortSheetVisible] = useState(false);
    const [selectedItem, setSelectedItem] = useState<GroceryItem | null>(null);

    // Form states
    const [itemName, setItemName] = useState('');
    const [itemNote, setItemNote] = useState('');
    const [selectedImage, setSelectedImage] = useState<string | null>(null);
    const [clearImage, setClearImage] = useState(false);

    const effectiveGroupId = activeGroupId || 'default';

    // Sync active grocery session lifecycle safely
    useEffect(() => {
        if (!sessionId) return;

        setOpenedList(sessionId);
        console.log(currentItems)
        loadItems(sessionId, effectiveGroupId);

        return () => {
            setOpenedList(null);
        };
    }, [sessionId, effectiveGroupId]);

    // Media Capture Handlers
    const pickImage = async (useCamera: boolean) => {
        const permissionResult = useCamera
            ? await ImagePicker.requestCameraPermissionsAsync()
            : await ImagePicker.requestMediaLibraryPermissionsAsync();

        if (!permissionResult.granted) {
            Alert.alert("Permission Denied", "Camera or gallery access is required to attach images.");
            return;
        }

        const result = await (useCamera
            ? ImagePicker.launchCameraAsync({ quality: 0.5 })
            : ImagePicker.launchImageLibraryAsync({ quality: 0.5 }));

        if (!result.canceled && result.assets?.[0]) {
            setSelectedImage(result.assets[0].uri);
            setClearImage(false);
        }
    };

    // Save mutations
    const handleSaveNewItem = async () => {
        if (!itemName.trim() || !sessionId) return;
        try {
            await addItem({
                name: itemName.trim(),
                listId: sessionId,
                groupId: effectiveGroupId,
                note: itemNote.trim(),
                imageFile: selectedImage,
            });
            closeAddModal();
        } catch (e) {
            console.error("Error adding item:", e);
        }
    };

    const handleUpdateItem = async () => {
        if (!selectedItem || !itemName.trim()) return;
        try {
            await updateItemDetails({
                item: selectedItem,
                newName: itemName.trim(),
                newNote: itemNote.trim(),
                newImageFile: selectedImage,
                shouldClearImage: clearImage,
                groupId: effectiveGroupId,
            });
            closeEditModal();
        } catch (e) {
            console.error("Error updating item:", e);
        }
    };

    const handleArchiveListPrompt = () => {
        const boughtCount = currentItems.filter(i => i.status === 'bought').length;
        const pendingCount = currentItems.filter(i => i.status === 'pending').length;
        const dateStr = `${new Date().getDate()}/${new Date().getMonth() + 1}`;
        const defaultName = `List ${dateStr}`;

        Alert.prompt(
            "Finish Shopping?",
            `Archiving will move ${boughtCount} items to history.\n${pendingCount} items will carry over to a new list.`,
            [
                { text: "Cancel", style: "cancel" },
                {
                    text: "Archive",
                    onPress: async (chosenName?: string) => {
                        if (!sessionId) return;
                        const finalName = chosenName?.trim() || defaultName;
                        try {
                            await archiveList(sessionId, finalName, effectiveGroupId, isCurrentGroupShared);
                            router.replace({ pathname: '/drawer/list_selection', params: { sessionId: currentListId } });
                        } catch (e) {
                            Alert.alert("Failed to archive", String(e));
                        }
                    }
                }
            ],
            'plain-text',
            defaultName
        );
    };

    // Modal Lifecycle Helpers
    const openAddModal = () => {
        setItemName('');
        setItemNote('');
        setSelectedImage(null);
        setAddModalVisible(true);
    };

    const closeAddModal = () => setAddModalVisible(false);

    const openEditModal = (item: GroceryItem) => {
        setSelectedItem(item);
        setItemName(item.name);
        setItemNote(item.note || '');
        setSelectedImage(item.imagePath || null);
        setClearImage(false);
        setEditModalVisible(true);
    };

    const closeEditModal = () => {
        setSelectedItem(null);
        setEditModalVisible(false);
    };

    // Styling logic maps
    const getItemTextStyle = (status: ItemStatus) => {
        if (status === 'bought') {
            return { textDecorationLine: 'line-through', color: colors.subtext, fontWeight: '400' } as const;
        }
        if (status === 'discarded') {
            return { textDecorationLine: 'line-through', color: '#f97316', fontStyle: 'italic' } as const;
        }
        return { fontWeight: 'bold', color: colors.text } as const;
    };

    if (!sessionId) {
        return (
            <View style={[styles.center, { backgroundColor: colors.background }]}>
                <Text style={{ color: colors.text }}>Error: No list selected.</Text>
            </View>
        );
    }

    return (
        <View style={[styles.container, { backgroundColor: colors.background }]}>
            <Stack.Screen
                options={{
                    title: "Items",
                    headerRight: () => (
                        <View style={styles.headerRow}>
                            <TouchableOpacity onPress={() => setSortSheetVisible(true)} style={styles.headerButton}>
                                <Ionicons name="swap-vertical" size={22} color={colors.text} />
                            </TouchableOpacity>
                            <TouchableOpacity onPress={handleArchiveListPrompt} style={styles.headerButton}>
                                <Ionicons name="archive-outline" size={22} color={colors.text} />
                            </TouchableOpacity>
                        </View>
                    )
                }}
            />

            {isLoading && <ActivityIndicator size="small" color={colors.primary} style={{ marginVertical: 4 }} />}

            <FlatList
                data={currentItems}
                keyExtractor={(item) => item.id?.toString() || `${item.name}-${item.createdAt}`}
                ItemSeparatorComponent={() => <View style={[styles.separator, { backgroundColor: colors.border }]} />}
                ListEmptyComponent={() => !isLoading ? (
                    <View style={styles.center}><Text style={{ color: colors.subtext }}>No items in this list</Text></View>
                ) : null}
                renderItem={({ item }) => {
                    const isDiscarded = item.status === 'discarded';
                    const hasExtra = !!item.note || !!item.imagePath;

                    return (
                        <ItemRow
                            item={item}
                            isDiscarded={isDiscarded}
                            hasExtra={hasExtra}
                            colors={colors}
                            getItemTextStyle={getItemTextStyle}
                            onToggleStatus={() => toggleStatus(item, effectiveGroupId)}
                            onEdit={() => openEditModal(item)}
                            onDelete={() => removeItem(item, effectiveGroupId)}
                            onForceStatus={(status: string | undefined) => toggleStatus(item, effectiveGroupId, status)}
                        />
                    );
                }}
            />

            {/* Floating Action Button */}
            <TouchableOpacity
                style={[styles.fab, { backgroundColor: colors.primary }]}
                onPress={openAddModal}
                activeOpacity={0.8}
            >
                <Ionicons name="cart" size={24} color="white" />
            </TouchableOpacity>

            {/* Sort Sheet Modal */}
            <Modal transparent visible={sortSheetVisible} animationType="slide" onRequestClose={() => setSortSheetVisible(false)}>
                <TouchableOpacity style={styles.modalOverlay} activeOpacity={1} onPress={() => setSortSheetVisible(false)}>
                    <View style={[styles.bottomSheet, { backgroundColor: colors.card }]}>
                        <View style={styles.sheetRow}>
                            <Text style={{ color: colors.text, fontSize: 16 }}>Inverse Order</Text>
                            <TouchableOpacity onPress={() => setSort(currentSort, !isInverse)}>
                                <Ionicons name={isInverse ? "checkbox" : "square-outline"} size={24} color={colors.primary} />
                            </TouchableOpacity>
                        </View>
                        <View style={[styles.separator, { backgroundColor: colors.border, marginVertical: 8 }]} />

                        {([
                            { type: 'alphabetical', icon: "text-outline", label: "Alphabetical" },
                            { type: 'created', icon: "calendar-outline", label: "Date Created" },
                            { type: 'hasNote', icon: "document-text-outline", label: "Items with Notes" },
                            { type: 'hasImage', icon: "image-outline", label: "Items with Images" }
                        ] as const).map((sortOpt) => (
                            <TouchableOpacity
                                key={sortOpt.type}
                                style={styles.sheetOption}
                                onPress={() => { setSort(sortOpt.type, isInverse); setSortSheetVisible(false); }}
                            >
                                <Ionicons name={sortOpt.icon} size={20} color={currentSort === sortOpt.type ? colors.primary : colors.subtext} />
                                <Text style={[styles.sheetOptionText, { color: currentSort === sortOpt.type ? colors.primary : colors.text }]}>{sortOpt.label}</Text>
                                {currentSort === sortOpt.type && <Ionicons name="checkmark" size={20} color={colors.primary} />}
                            </TouchableOpacity>
                        ))}
                    </View>
                </TouchableOpacity>
            </Modal>

            {/* Add / Edit Form Modal Container with Keyboard Prevention */}
            <Modal visible={addModalVisible || editModalVisible} animationType="fade" transparent onRequestClose={addModalVisible ? closeAddModal : closeEditModal}>
                <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
                    <View style={styles.modalOverlay}>
                        <KeyboardAvoidingView
                            behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                            style={{ width: '100%', alignItems: 'center' }}
                        >
                            <View style={[styles.dialogCard, { backgroundColor: colors.card }]}>
                                <Text style={[styles.dialogTitle, { color: colors.text }]}>{addModalVisible ? "Add to List" : "Edit Item"}</Text>
                                <TextInput
                                    style={[styles.input, { color: colors.text, borderColor: colors.border }]}
                                    placeholder="Item name..."
                                    placeholderTextColor={colors.subtext}
                                    value={itemName}
                                    onChangeText={setItemName}
                                    autoFocus
                                />
                                <TextInput
                                    style={[styles.input, { color: colors.text, borderColor: colors.border }]}
                                    placeholder="Note..."
                                    placeholderTextColor={colors.subtext}
                                    value={itemNote}
                                    onChangeText={setItemNote}
                                />

                                {selectedImage && !clearImage && (
                                    <View style={styles.imagePreviewContainer}>
                                        <Image source={{ uri: selectedImage }} style={styles.dialogImage} />
                                        <TouchableOpacity style={styles.clearImageBtn} onPress={() => setClearImage(true)}>
                                            <Ionicons name="close-circle" size={24} color="#ef4444" />
                                        </TouchableOpacity>
                                    </View>
                                )}

                                <View style={styles.mediaActions}>
                                    <TouchableOpacity onPress={() => pickImage(true)} style={styles.mediaBtn}>
                                        <Ionicons name="camera" size={28} color={colors.subtext} />
                                    </TouchableOpacity>
                                    <TouchableOpacity onPress={() => pickImage(false)} style={styles.mediaBtn}>
                                        <Ionicons name="images" size={28} color={colors.subtext} />
                                    </TouchableOpacity>
                                </View>

                                <View style={styles.dialogActions}>
                                    <TouchableOpacity onPress={addModalVisible ? closeAddModal : closeEditModal} style={styles.actionBtn}>
                                        <Text style={{ color: colors.subtext }}>Cancel</Text>
                                    </TouchableOpacity>
                                    <TouchableOpacity onPress={addModalVisible ? handleSaveNewItem : handleUpdateItem} style={[styles.actionBtn, styles.primaryActionBtn, { backgroundColor: colors.primary }]}>
                                        <Text style={{ color: '#fff', fontWeight: 'bold' }}>{addModalVisible ? "Add" : "Save"}</Text>
                                    </TouchableOpacity>
                                </View>
                            </View>
                        </KeyboardAvoidingView>
                    </View>
                </TouchableWithoutFeedback>
            </Modal>
        </View>
    );
}

function ItemRow({ item, isDiscarded, hasExtra, colors, getItemTextStyle, onToggleStatus, onEdit, onDelete, onForceStatus }: any) {
    const [expanded, setExpanded] = useState(false);

    const mainRowLayout = (
        <View style={styles.itemRowInner}>
            {item.id === -1 ? (
                <ActivityIndicator size="small" color={colors.primary} style={{ marginRight: 12 }} />
            ) : isDiscarded ? (
                <Ionicons name="trash-bin-outline" size={22} color="#f97316" style={{ marginRight: 12 }} />
            ) : (
                <TouchableOpacity onPress={onToggleStatus} style={styles.checkboxTouch}>
                    <Ionicons
                        name={item.status === 'bought' ? "checkbox" : "square-outline"}
                        size={24}
                        color={item.status === 'bought' ? colors.primary : colors.subtext}
                    />
                </TouchableOpacity>
            )}

            <View style={styles.itemMeta}>
                <View style={styles.titleIconRow}>
                    <Text style={[getItemTextStyle(item.status), styles.itemTitle]} numberOfLines={1}>{item.name}</Text>
                    {!!item.note && <Ionicons name="information-circle-outline" size={16} color={colors.subtext} style={{ marginLeft: 6 }} />}
                    {!!item.imagePath && <Ionicons name="image-outline" size={16} color={colors.subtext} style={{ marginLeft: 4 }} />}
                </View>
                {isDiscarded && <Text style={{ color: '#f97316', fontSize: 12 }}>Discarded</Text>}
            </View>

            <TouchableOpacity
                onPress={() => Alert.alert(
                    "Item Options",
                    item.name,
                    [
                        { text: "Mark Pending", onPress: () => onForceStatus('pending') },
                        { text: "Discard", onPress: () => onForceStatus('discarded') },
                        { text: "Edit Details", onPress: onEdit },
                        { text: "Delete", onPress: onDelete, style: 'destructive' },
                        { text: "Cancel", style: 'cancel' }
                    ]
                )}
                style={styles.moreBtn}
            >
                <Ionicons name="ellipsis-vertical" size={20} color={colors.subtext} />
            </TouchableOpacity>
        </View>
    );

    if (!hasExtra) return <View style={styles.itemRow}>{mainRowLayout}</View>;

    return (
        <View style={styles.itemRow}>
            <TouchableOpacity activeOpacity={0.9} onPress={() => setExpanded(!expanded)}>
                {mainRowLayout}
            </TouchableOpacity>
            {expanded && (
                <View style={styles.expansionContent}>
                    {!!item.note && <Text style={[styles.expansionNote, { color: colors.subtext }]}>{item.note}</Text>}
                    {!!item.imagePath && (
                        <Image source={{ uri: item.imagePath }} style={styles.expandedItemImage} resizeMode="cover" />
                    )}
                </View>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    container: { flex: 1 },
    center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 },
    headerRow: { flexDirection: 'row', alignItems: 'center' },
    headerButton: { paddingHorizontal: 8 },
    separator: { height: 1 },
    itemRow: { paddingVertical: 4 },
    itemRowInner: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16 },
    checkboxTouch: { marginRight: 12 },
    itemMeta: { flex: 1, justifyContent: 'center' },
    titleIconRow: { flexDirection: 'row', alignItems: 'center' },
    itemTitle: { fontSize: 16, maxWidth: '85%' },
    moreBtn: { paddingLeft: 12, paddingVertical: 4 },
    expansionContent: { paddingLeft: 52, paddingRight: 16, paddingBottom: 12 },
    expansionNote: { fontSize: 14, marginBottom: 8 },
    expandedItemImage: { width: '100%', height: 180, borderRadius: 8 },
    fab: {
        position: 'absolute', right: 16, bottom: 16, width: 56, height: 56, borderRadius: 28,
        justifyContent: 'center', alignItems: 'center', elevation: 4, shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.25, shadowRadius: 3.84,
    },
    modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', alignItems: 'center' },
    bottomSheet: {
        position: 'absolute', bottom: 0, left: 0, right: 0, borderTopLeftRadius: 16, borderTopRightRadius: 16,
        padding: 20, paddingBottom: 32,
    },
    sheetRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8 },
    sheetOption: { flexDirection: 'row', alignItems: 'center', paddingVertical: 12 },
    sheetOptionText: { flex: 1, marginLeft: 12, fontSize: 15 },
    dialogCard: { width: '85%', borderRadius: 14, padding: 20, elevation: 5 },
    dialogTitle: { fontSize: 18, fontWeight: 'bold', marginBottom: 16 },
    input: { borderWidth: 1, borderRadius: 8, paddingVertical: 8, paddingHorizontal: 12, fontSize: 15, marginBottom: 12 },
    imagePreviewContainer: { width: 100, height: 100, marginBottom: 12, position: 'relative' },
    dialogImage: { width: '100%', height: '100%', borderRadius: 8 },
    clearImageBtn: { position: 'absolute', top: -6, right: -6, backgroundColor: '#fff', borderRadius: 12 },
    mediaActions: { flexDirection: 'row', marginBottom: 16 },
    mediaBtn: { marginRight: 16, padding: 4 },
    dialogActions: { flexDirection: 'row', justifyContent: 'flex-end' },
    actionBtn: { paddingVertical: 8, paddingHorizontal: 16, borderRadius: 6, marginLeft: 8 },
    primaryActionBtn: { justifyContent: 'center' }
});