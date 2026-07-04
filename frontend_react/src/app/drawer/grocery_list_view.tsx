import React, {useState, useEffect, useRef} from 'react';
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
import {useLocalSearchParams, useRouter, Stack} from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import {Ionicons} from '@expo/vector-icons';

import {useItems} from "@/context/itemContext";
import {useGroups} from "@/context/groupContext";
import {useLists} from "@/context/listContext";
import {useTheme} from "@/context/themeContext";
import {GroceryItem, GroceryList, ItemStatus} from "@/types/models";
import CustomAlert, {AlertButton} from "@/components/CustomAlert";
import {CONFIG} from '@/config/constants';
import {useSocketEvent} from "@/context/socketContext";

export default function GroceryListScreen() {
    const {sessionId, refreshKey} = useLocalSearchParams<{ sessionId: string, refreshKey: string }>();
    const router = useRouter();
    const {colors} = useTheme();

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
    const {activeGroupId, isCurrentGroupShared} = useGroups();
    const {archiveList, currentListId} = useLists();

    const [addModalVisible, setAddModalVisible] = useState(false);
    const [editModalVisible, setEditModalVisible] = useState(false);
    const [sortSheetVisible, setSortSheetVisible] = useState(false);
    const [selectedItem, setSelectedItem] = useState<GroceryItem | null>(null);

    const [itemName, setItemName] = useState('');
    const [itemNote, setItemNote] = useState('');
    const [selectedImage, setSelectedImage] = useState<string | null>(null);
    const [selectedImageName, setSelectedImageName] = useState<string | null>(null);
    const [selectedImageType, setSelectedImageType] = useState<string | null>(null);
    const [clearImage, setClearImage] = useState(false);

    const [alertConfig, setAlertConfig] = useState<{
        visible: boolean;
        title: string;
        message: string;
        buttons: AlertButton[];
    }>({
        visible: false,
        title: '',
        message: '',
        buttons: []
    });

    const triggerAlert = (title: string, message: string, buttons?: AlertButton[]) => {
        setAlertConfig({
            visible: true,
            title,
            message,
            buttons: buttons || [{text: "OK", onPress: () => closeAlert()}]
        });
    };

    const closeAlert = () => setAlertConfig(prev => ({...prev, visible: false}));

    const effectiveGroupId = activeGroupId || 'default';


    useEffect(() => {
        if (!sessionId) return;
        setOpenedList(sessionId);
        loadItems(sessionId, effectiveGroupId);

        return () => {
            if (!sessionId) {
                setOpenedList(null);
            }
        };
    }, [sessionId, effectiveGroupId, refreshKey]);

    useSocketEvent('item_added', (item: GroceryItem) => {
        if (item.listId === sessionId) {
            loadItems(sessionId, effectiveGroupId);
        }
    });
    useSocketEvent('item_deleted', (item: { id: string; name: string; listId: string }) => {
        if (item.listId === sessionId) {
            console.log('item_deleted', item);
            loadItems(sessionId, effectiveGroupId);
        }
    });
    useSocketEvent('item_updated', (item: GroceryItem) => {
        if (item.listId === sessionId) {
            loadItems(sessionId, effectiveGroupId);
        }
    });

    const pickImage = async (useCamera: boolean) => {
        const permissionResult = useCamera
            ? await ImagePicker.requestCameraPermissionsAsync()
            : await ImagePicker.requestMediaLibraryPermissionsAsync();

        if (!permissionResult.granted) {
            triggerAlert(
                "Accès refusé",
                "L'accès à l'appareil photo ou à la galerie est requis pour joindre des images.",
                [{text: 'Ok', style: 'Annuler', onPress: closeAlert}]);
            return;
        }

        const result = await (useCamera
            ? ImagePicker.launchCameraAsync({quality: 0.5})
            : ImagePicker.launchImageLibraryAsync({quality: 0.5}));

        if (!result.canceled && result.assets?.[0]) {
            setSelectedImage(result.assets[0].uri);
            setSelectedImageName(result.assets[0].fileName)
            setSelectedImageType(result.assets[0].type)
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
                imageFile: {
                    uri: selectedImage,
                    name: selectedImageName,
                    type: selectedImageType
                },
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
                newImageFile: {
                    uri: selectedImage,
                    name: selectedImageName,
                    type: selectedImageType
                },
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

        triggerAlert(
            "Terminer les courses ?",
            `L'archivage déplacera ${boughtCount} article(s) vers l'historique.\n${pendingCount} article(s) restant(s) seront reportés sur une nouvelle liste.`,
            [
                {text: "Annuler", style: "cancel", onPress: closeAlert},
                {
                    text: "Archiver",
                    onPress: async () => {
                        if (!sessionId) return;
                        const date = new Date();
                        const formattedDate = new Intl.DateTimeFormat('fr-CA', {
                            year: '2-digit',
                            month: 'numeric',
                            day: 'numeric'
                        }).format(date);
                        const finalName = `Liste du ${formattedDate}`;
                        try {
                            closeAlert();
                            const nextListId = await archiveList(sessionId, finalName, effectiveGroupId, isCurrentGroupShared);

                            if (nextListId) {
                                router.replace({
                                    pathname: '/drawer/grocery_list_view',
                                    params: {sessionId: nextListId}
                                });
                            }
                        } catch (e) {
                            triggerAlert(
                                "Échec de l'archivage",
                                String(e)
                            );
                        }
                    }
                }
            ]
        );
    };

    const openAddModal = () => {
        setItemName('');
        setItemNote('');
        setSelectedImage(null);
        setClearImage(false);
        setAddModalVisible(true);
    };

    const closeAddModal = () => {
        setItemName('');
        setItemNote('');
        setSelectedImage(null);
        setClearImage(false);
        setAddModalVisible(false);
    };

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
        setItemName('');
        setItemNote('');
        setSelectedImage(null);
        setClearImage(false);
        setEditModalVisible(false);
    };

    const getItemTextStyle = (status: ItemStatus) => {
        if (status === 'bought') {
            return {textDecorationLine: 'line-through', color: colors.subtext, fontWeight: '400'} as const;
        }
        if (status === 'discarded') {
            return {textDecorationLine: 'line-through', color: '#f97316', fontStyle: 'italic'} as const;
        }
        return {fontWeight: 'bold', color: colors.text} as const;
    };

    if (!sessionId) {
        return (
            <View style={[styles.center, {backgroundColor: colors.background}]}>
                <Text style={{color: colors.text}}>Error: No list selected.</Text>
            </View>
        );
    }

    return (
        <View style={[styles.container, {backgroundColor: colors.background}]}>
            <Stack.Screen
                options={{
                    title: "Items",
                    headerRight: () => (
                        <View style={styles.headerRow}>
                            <TouchableOpacity onPress={() => setSortSheetVisible(true)} style={styles.headerButton}>
                                <Ionicons name="swap-vertical" size={22} color={colors.text}/>
                            </TouchableOpacity>
                            <TouchableOpacity onPress={handleArchiveListPrompt} style={styles.headerButton}>
                                <Ionicons name="archive-outline" size={22} color={colors.text}/>
                            </TouchableOpacity>
                        </View>
                    ),
                    headerLeft: () => (
                        <TouchableOpacity
                            onPress={() => router.replace({
                                pathname: '/drawer/list_selection',
                                params: {groupId: activeGroupId}
                            })}
                            style={{marginLeft: 16, marginRight: 5}}
                        >
                            <Ionicons
                                name="arrow-back"
                                size={24}
                                color={colors.text}
                            />
                        </TouchableOpacity>
                    ),
                }}
            />

            {isLoading && <ActivityIndicator size="small" color={colors.primary} style={{marginVertical: 4}}/>}

            <FlatList
                data={currentItems}
                keyExtractor={(item) => item.id?.toString() || `${item.name}-${item.createdAt}`}
                ItemSeparatorComponent={() => <View style={[styles.separator, {backgroundColor: colors.border}]}/>}
                ListEmptyComponent={() => !isLoading ? (
                    <View style={styles.center}><Text style={{color: colors.subtext}}>Aucun élément dans cette liste
                        liste</Text></View>
                ) : null}
                renderItem={({item}) => {
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
                            onForceStatus={(status: 'pending' | 'bought' | 'discarded') => toggleStatus(item, effectiveGroupId, status)}
                        />
                    );
                }}
            />

            <TouchableOpacity
                style={[styles.fab, {backgroundColor: colors.primary}]}
                onPress={openAddModal}
                activeOpacity={0.8}
            >
                <Ionicons name="cart" size={24} color="white"/>
            </TouchableOpacity>

            <Modal transparent visible={sortSheetVisible} animationType="slide"
                   onRequestClose={() => setSortSheetVisible(false)}>
                <TouchableOpacity style={styles.modalOverlay} activeOpacity={1}
                                  onPress={() => setSortSheetVisible(false)}>
                    <View style={[styles.bottomSheet, {backgroundColor: colors.card}]}>
                        <View style={styles.sheetRow}>
                            <Text style={{color: colors.text, fontSize: 16}}>Ordre inverse</Text>
                            <TouchableOpacity onPress={() => setSort(currentSort, !isInverse)}>
                                <Ionicons name={isInverse ? "checkbox" : "square-outline"} size={24}
                                          color={colors.primary}/>
                            </TouchableOpacity>
                        </View>
                        <View style={[styles.separator, {backgroundColor: colors.border, marginVertical: 8}]}/>

                        {([
                            {type: 'alphabetical', icon: "text-outline", label: "alphabétique"},
                            {type: 'created', icon: "calendar-outline", label: "Date de création"},
                            {type: 'hasNote', icon: "document-text-outline", label: "Articles avec notes"},
                            {type: 'hasImage', icon: "image-outline", label: "Articles avec images"}
                        ] as const).map((sortOpt) => (
                            <TouchableOpacity
                                key={sortOpt.type}
                                style={styles.sheetOption}
                                onPress={() => {
                                    setSort(sortOpt.type, isInverse);
                                    setSortSheetVisible(false);
                                }}
                            >
                                <Ionicons name={sortOpt.icon} size={20}
                                          color={currentSort === sortOpt.type ? colors.primary : colors.subtext}/>
                                <Text
                                    style={[styles.sheetOptionText, {color: currentSort === sortOpt.type ? colors.primary : colors.text}]}>{sortOpt.label}</Text>
                                {currentSort === sortOpt.type &&
                                    <Ionicons name="checkmark" size={20} color={colors.primary}/>}
                            </TouchableOpacity>
                        ))}
                    </View>
                </TouchableOpacity>
            </Modal>

            <Modal
                visible={addModalVisible || editModalVisible}
                animationType="fade"
                transparent
                onRequestClose={addModalVisible ? closeAddModal : closeEditModal}
            >
                <TouchableOpacity
                    style={styles.modalOverlay}
                    activeOpacity={1}
                    onPress={addModalVisible ? closeAddModal : closeEditModal}
                >
                    <TouchableWithoutFeedback onPress={Keyboard.dismiss}>
                        <KeyboardAvoidingView
                            behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                            style={{width: '100%', alignItems: 'center'}}
                        >
                            <TouchableOpacity activeOpacity={1} style={[styles.dialogCard, {
                                backgroundColor: colors.card,
                                borderColor: colors.border
                            }]}>
                                <Text style={[styles.dialogTitle, {color: colors.text}]}>
                                    {addModalVisible ? "Ajouter à la liste" : "Modifier l'élément"}
                                </Text>

                                <TextInput
                                    style={[styles.input, {
                                        color: colors.text,
                                        borderColor: colors.border,
                                        backgroundColor: colors.background
                                    }]}
                                    placeholder="Nom de l'article..."
                                    placeholderTextColor={colors.subtext}
                                    value={itemName}
                                    onChangeText={setItemName}
                                    autoFocus
                                />
                                <TextInput
                                    style={[styles.input, {
                                        color: colors.text,
                                        borderColor: colors.border,
                                        backgroundColor: colors.background
                                    }]}
                                    placeholder="Note..."
                                    placeholderTextColor={colors.subtext}
                                    value={itemNote}
                                    onChangeText={setItemNote}
                                />

                                {selectedImage && !clearImage && (
                                    <View style={[styles.imagePreviewContainer, {borderColor: colors.border}]}>
                                        <Image source={{uri: selectedImage}} style={styles.dialogImage}
                                               resizeMode="cover"/>
                                        <TouchableOpacity style={styles.clearImageBtn}
                                                          onPress={() => setClearImage(true)}>
                                            <Ionicons name="close-circle" size={26} color="#ef4444"/>
                                        </TouchableOpacity>
                                    </View>
                                )}

                                <View style={styles.mediaActions}>
                                    <TouchableOpacity onPress={() => pickImage(true)} style={[styles.mediaBtn, {
                                        backgroundColor: colors.background,
                                        borderColor: colors.border
                                    }]}>
                                        <Ionicons name="camera" size={24} color={colors.primary}/>
                                        <Text style={[styles.mediaBtnText, {color: colors.text}]}>Camera</Text>
                                    </TouchableOpacity>
                                    <TouchableOpacity onPress={() => pickImage(false)} style={[styles.mediaBtn, {
                                        backgroundColor: colors.background,
                                        borderColor: colors.border
                                    }]}>
                                        <Ionicons name="images" size={24} color={colors.primary}/>
                                        <Text style={[styles.mediaBtnText, {color: colors.text}]}>Gallery</Text>
                                    </TouchableOpacity>
                                </View>

                                <View style={styles.dialogActions}>
                                    <TouchableOpacity
                                        onPress={addModalVisible ? closeAddModal : closeEditModal}
                                        style={[styles.actionBtn, {borderColor: colors.border}]}
                                    >
                                        <Text style={{color: colors.subtext, fontWeight: '600'}}>Cancel</Text>
                                    </TouchableOpacity>
                                    <TouchableOpacity
                                        onPress={addModalVisible ? handleSaveNewItem : handleUpdateItem}
                                        style={[styles.actionBtn, styles.primaryActionBtn, {backgroundColor: colors.primary}]}
                                    >
                                        <Text style={{color: '#fff', fontWeight: 'bold'}}>
                                            {addModalVisible ? "Ajouter" : "Sauvegarder"}
                                        </Text>
                                    </TouchableOpacity>
                                </View>
                            </TouchableOpacity>
                        </KeyboardAvoidingView>
                    </TouchableWithoutFeedback>
                </TouchableOpacity>
            </Modal>

            <CustomAlert
                visible={alertConfig.visible}
                title={alertConfig.title}
                message={alertConfig.message}
                buttons={alertConfig.buttons}
                colors={colors}
            />
        </View>
    );
}

interface ItemRowProps {
    item: GroceryItem;
    isDiscarded: boolean;
    hasExtra: boolean;
    colors: any;
    getItemTextStyle: (status: ItemStatus) => object;
    onToggleStatus: () => void;
    onEdit: () => void;
    onDelete: () => void;
    onForceStatus: (status: ItemStatus) => void;
}

function ItemRow({
                     item,
                     isDiscarded,
                     hasExtra,
                     colors,
                     getItemTextStyle,
                     onToggleStatus,
                     onEdit,
                     onDelete,
                     onForceStatus
                 }: ItemRowProps) {
    const [expanded, setExpanded] = useState(false);
    const [optionsVisible, setOptionsVisible] = useState(false);

    const mainRowLayout = (
        <View style={styles.itemRowInner}>
            {item.id === -1 ? (
                <ActivityIndicator size="small" color={colors.primary} style={{marginRight: 12}}/>
            ) : isDiscarded ? (
                <Ionicons name="trash-bin-outline" size={22} color="#f97316" style={{marginRight: 12}}/>
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
                    {!!item.note && <Ionicons name="information-circle-outline" size={16} color={colors.subtext}
                                              style={{marginLeft: 6}}/>}
                    {!!item.imagePath &&
                        <Ionicons name="image-outline" size={16} color={colors.subtext} style={{marginLeft: 4}}/>}
                </View>
                {isDiscarded && <Text style={{color: '#f97316', fontSize: 12}}>Discarded</Text>}
            </View>

            <TouchableOpacity
                onPress={() => setOptionsVisible(true)}
                style={styles.moreBtn}
            >
                <Ionicons name="ellipsis-vertical" size={20} color={colors.subtext}/>
            </TouchableOpacity>

            <Modal
                transparent
                visible={optionsVisible}
                animationType="slide"
                onRequestClose={() => setOptionsVisible(false)}
            >
                <TouchableOpacity
                    style={styles.modalOverlay}
                    activeOpacity={1}
                    onPress={() => setOptionsVisible(false)}
                >
                    <View style={[styles.bottomSheet, {backgroundColor: colors.card}]}>

                        <View style={styles.sheetHeader}>
                            <Text style={[styles.sheetTitle, {color: colors.text}]}>{item.name}</Text>
                            <Text style={[styles.sheetSubtitle, {color: colors.subtext}]}>Options de l'article</Text>
                        </View>

                        <View style={[styles.separator, {backgroundColor: colors.border}]}/>
                        {item.status === 'bought' ? (
                            <TouchableOpacity
                                style={styles.sheetOption}
                                onPress={() => {
                                    onForceStatus('pending');
                                    setOptionsVisible(false);
                                }}
                            >
                                <Ionicons name="time-outline" size={22} color={colors.text}/>
                                <Text style={[styles.sheetOptionText, {color: colors.text}]}>En Attente</Text>
                            </TouchableOpacity>
                        ) : (
                            <TouchableOpacity
                                style={styles.sheetOption}
                                onPress={() => {
                                    onForceStatus('bought');
                                    setOptionsVisible(false);
                                }}
                            >
                                <Ionicons name="cart-outline" size={22} color={colors.text}/>
                                <Text style={[styles.sheetOptionText, {color: colors.text}]}>Acheté</Text>
                            </TouchableOpacity>
                        )}
                        <TouchableOpacity
                            style={styles.sheetOption}
                            onPress={() => {
                                onForceStatus('discarded');
                                setOptionsVisible(false);
                            }}
                        >
                            <Ionicons name="ban-outline" size={22} color="#f97316"/>
                            <Text style={[styles.sheetOptionText, {color: '#f97316'}]}>Discarté</Text>
                        </TouchableOpacity>

                        <TouchableOpacity
                            style={styles.sheetOption}
                            onPress={() => {
                                onEdit();
                                setOptionsVisible(false);
                            }}
                        >
                            <Ionicons name="create-outline" size={22} color={colors.text}/>
                            <Text style={[styles.sheetOptionText, {color: colors.text}]}>Modifier les détails</Text>
                        </TouchableOpacity>

                        <View style={[styles.separator, {backgroundColor: colors.border, marginVertical: 6}]}/>

                        <TouchableOpacity
                            style={styles.sheetOption}
                            onPress={() => {
                                onDelete();
                                setOptionsVisible(false);
                            }}
                        >
                            <Ionicons name="trash-outline" size={22} color="#ef4444"/>
                            <Text
                                style={[styles.sheetOptionText, {color: '#ef4444', fontWeight: '600'}]}>Supprimer</Text>
                        </TouchableOpacity>
                    </View>
                </TouchableOpacity>
            </Modal>
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
                    {!!item.note && <Text style={[styles.expansionNote, {color: colors.subtext}]}>{item.note}</Text>}
                    {!!item.imagePath && (
                        <Image source={{uri: `${CONFIG.BASE_URL}/${item.imagePath}`}} style={styles.expandedItemImage}
                               resizeMode="cover"/>
                    )}
                </View>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    container: {flex: 1},
    center: {flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20},
    headerRow: {flexDirection: 'row', alignItems: 'center'},
    headerButton: {paddingHorizontal: 8},
    separator: {height: 1},
    itemRow: {paddingVertical: 4},
    itemRowInner: {flexDirection: 'row', alignItems: 'center', paddingVertical: 12, paddingHorizontal: 16},
    checkboxTouch: {marginRight: 12},
    itemMeta: {flex: 1, justifyContent: 'center'},
    titleIconRow: {flexDirection: 'row', alignItems: 'center'},
    itemTitle: {fontSize: 16, maxWidth: '85%'},
    moreBtn: {paddingLeft: 12, paddingVertical: 4},
    expansionContent: {paddingLeft: 52, paddingRight: 16, paddingBottom: 12},
    expansionNote: {fontSize: 14, marginBottom: 8},
    expandedItemImage: {width: '100%', height: 180, borderRadius: 8},
    fab: {
        position: 'absolute', right: 16, bottom: 16, width: 56, height: 56, borderRadius: 28,
        justifyContent: 'center', alignItems: 'center', elevation: 4, shadowColor: '#000',
        shadowOffset: {width: 0, height: 2}, shadowOpacity: 0.25, shadowRadius: 3.84,
    },
    modalOverlay: {flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'center', alignItems: 'center'},
    bottomSheet: {
        position: 'absolute', bottom: 0, left: 0, right: 0, borderTopLeftRadius: 16, borderTopRightRadius: 16,
        padding: 20, paddingBottom: 32,
    },
    sheetRow: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 8},
    sheetOption: {flexDirection: 'row', alignItems: 'center', paddingVertical: 12},
    sheetOptionText: {flex: 1, marginLeft: 12, fontSize: 15},
    dialogCard: {
        width: '88%',
        borderRadius: 16,
        padding: 24,
        borderWidth: 1,
        elevation: 8,
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 4},
        shadowOpacity: 0.15,
        shadowRadius: 6
    },
    dialogTitle: {fontSize: 20, fontWeight: '700', marginBottom: 20},
    input: {
        borderWidth: 1,
        borderRadius: 10,
        paddingVertical: 12,
        paddingHorizontal: 16,
        fontSize: 15,
        marginBottom: 16
    },
    mediaActions: {flexDirection: 'row', justifyContent: 'space-between', marginBottom: 24, gap: 12},
    mediaBtn: {
        flex: 1,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        paddingVertical: 12,
        borderRadius: 10,
        borderWidth: 1,
        gap: 8
    },
    mediaBtnText: {fontSize: 14, fontWeight: '600'},
    imagePreviewContainer: {
        width: '100%',
        height: 160,
        borderRadius: 12,
        marginBottom: 20,
        position: 'relative',
        overflow: 'hidden',
        borderWidth: 1
    },
    dialogImage: {width: '100%', height: '100%'},
    clearImageBtn: {position: 'absolute', top: 8, right: 8, backgroundColor: '#fff', borderRadius: 14, elevation: 2},
    dialogActions: {flexDirection: 'row', justifyContent: 'flex-end'},
    actionBtn: {paddingVertical: 8, paddingHorizontal: 16, borderRadius: 6, marginLeft: 8},
    primaryActionBtn: {justifyContent: 'center'},
    sheetHeader: {marginBottom: 16,},
    sheetTitle: {fontSize: 18, fontWeight: '700', marginBottom: 4,},
    sheetSubtitle: {fontSize: 13,},
});