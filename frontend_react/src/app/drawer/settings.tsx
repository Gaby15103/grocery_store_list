import React, { useState } from 'react';
import {
    View,
    Text,
    StyleSheet,
    ScrollView,
    TextInput,
    Pressable,
    Alert,
    Clipboard,
    Platform,
    Modal, KeyboardAvoidingView
} from 'react-native';
import { Save, Copy, RefreshCw, Languages, Moon, Trash2 } from 'lucide-react-native';
import { useAuth } from "@/context/authContext";
import { useTheme } from "@/context/themeContext";
import { Picker } from "@react-native-picker/picker";
import { ThemeMode } from "@/context/themeContext";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import CustomAlert, {AlertButton} from "@/components/CustomAlert";

const useL10n = () => (key: string) => {
    const translations: Record<string, string> = {
        settings: "Paramètres",
        profile_header: "Profil",
        first_name: "Prénom",
        last_name: "Nom",
        email_address: "Adresse courriel",
        save_profile: "Sauvegarder le profil",
        notification_settings: "Notifications",
        notif_invites: "Invitations de groupe",
        notif_list_created: "Nouvelle liste créée",
        notif_carry_over: "Report d'articles",
        notif_items: "Modifications d'articles",
        sync_header: "Synchronisation",
        your_sync_code: "Votre code de synchronisation",
        connect_existing: "Lier un compte existant",
        sync_hint: "Entrez le code de synchronisation",
        sync_now: "Synchroniser",
        appearance_header: "Apparence",
        language_label: "Langue",
        theme_mode: "Mode Thème",
        danger_zone: "Zone de danger",
        factory_reset: "Réinitialisation complète",
        wipe_all: "Tout effacer",
        cancel: "Annuler",
    };
    return translations[key] || key;
};

export default function SettingsScreen() {
    const t = useL10n();
    const auth = useAuth();
    const insets = useSafeAreaInsets();

    // Grab everything from the updated theme context
    const { colors, themeMode, setTheme, colorSeed, setColorSeed } = useTheme();

    // Form states
    const [firstName, setFirstName] = useState(auth.userProfile?.firstName || '');
    const [lastName, setLastName] = useState(auth.userProfile?.lastName || '');
    const [email, setEmail] = useState(auth.userProfile?.email || '');

    // Sync Dialog States
    const [isSyncModalVisible, setIsSyncModalVisible] = useState(false);
    const [syncInputCode, setSyncInputCode] = useState('');

    // App Preferences local states
    const [notifInvites, setNotifInvites] = useState(true);
    const [notifLists, setNotifLists] = useState(true);
    const [notifCarry, setNotifCarry] = useState(false);
    const [notifItems, setNotifItems] = useState(true);
    const [language, setLanguage] = useState('fr');

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
            buttons: buttons || [{ text: "OK", onPress: () => closeAlert() }]
        });
    };

    const closeAlert = () => setAlertConfig(prev => ({ ...prev, visible: false }));

    const themeOptions = [
        { label: 'System', value: 'system' },
        { label: 'Light', value: 'light' },
        { label: 'Dark', value: 'dark' },
    ];

    const colorPalette = ['#22c55e', '#3b82f6', '#ef4444', '#f97316', '#a855f7', '#14b8a6', '#ec4899', '#64748b'];

    const handleSaveProfile = async () => {
        try {
            await auth.updateProfile(firstName, lastName, email);
            triggerAlert("Succès", "Profil mis à jour avec succès.");
        } catch (e) {
            triggerAlert("Erreur", "Impossible de mettre le profil à jour.");
        }
    };

    const copyToClipboard = (code: string) => {
        Clipboard.setString(code);
        Alert.alert("Copié !", "Code de synchronisation copié dans le presse-papier.");
    };

    const handleSyncSubmit = async () => {
        const code = syncInputCode.trim();
        if (code.length > 0) {
            try {
                await auth.linkWithCode(code);
                setIsSyncModalVisible(false);
                setSyncInputCode('');
            } catch (e) {
                Alert.alert("Erreur", "Code invalide ou impossible de lier le compte.");
            }
        }
    };

    const handleFactoryReset = () => {
        triggerAlert(
            t('danger_zone'),
            "Êtes-vous certain de vouloir tout effacer ?",
            [
                { text: t('cancel'), style: 'cancel', onPress: closeAlert },
                {
                    text: t('wipe_all'),
                    style: 'destructive',
                    onPress: async () => {
                        closeAlert();
                        await auth.logout();
                    }
                }
            ]
        );
    };

    return (
        <View style={{flex: 1}}>
            <ScrollView
                style={[styles.container, { backgroundColor: colors.background }]}
                contentContainerStyle={styles.scrollContent}
            >
                {/* SECTION: PROFILE */}
                <Text style={[styles.sectionHeader, { color: colors.primary }]}>{t('profile_header')}</Text>
                <View style={[styles.card, { backgroundColor: colors.card, borderColor: colors.border }]}>
                    <View style={styles.inputGroup}>
                        <Text style={[styles.inputLabel, { color: colors.text }]}>{t('first_name')}</Text>
                        <TextInput
                            style={[styles.input, { backgroundColor: colors.background, borderColor: colors.border, color: colors.text }]}
                            value={firstName}
                            onChangeText={setFirstName}
                            placeholder="Gaby"
                            placeholderTextColor={colors.subtext}
                        />
                    </View>
                    <View style={styles.inputGroup}>
                        <Text style={[styles.inputLabel, { color: colors.text }]}>{t('last_name')}</Text>
                        <TextInput
                            style={[styles.input, { backgroundColor: colors.background, borderColor: colors.border, color: colors.text }]}
                            value={lastName}
                            onChangeText={setLastName}
                            placeholder="Morin"
                            placeholderTextColor={colors.subtext}
                        />
                    </View>
                    <View style={styles.inputGroup}>
                        <Text style={[styles.inputLabel, { color: colors.text }]}>{t('email_address')}</Text>
                        <TextInput
                            style={[styles.input, { backgroundColor: colors.background, borderColor: colors.border, color: colors.text }]}
                            value={email}
                            onChangeText={setEmail}
                            keyboardType="email-address"
                            autoCapitalize="none"
                        />
                    </View>
                    <View style={[styles.divider, { backgroundColor: colors.border }]}/>
                    <Pressable style={styles.syncRowClickable} onPress={handleSaveProfile}>
                        <View style={[styles.rowLayoutLeft, {marginBottom: 10}]}>
                            <Save size={18} color="#fff" style={{marginRight: 10}}/>
                            <Text style={styles.primaryButtonText}>{t('save_profile')}</Text>
                        </View>
                    </Pressable>
                </View>

                {/* SECTION: NOTIFICATIONS */}
                <Text style={[styles.sectionHeader, { color: colors.primary }]}>{t('notification_settings')}</Text>
                <View style={[styles.card, { backgroundColor: colors.card, borderColor: colors.border }]}>
                    {_buildRowSwitch(t('notif_invites'), notifInvites, setNotifInvites, colors, false)}
                    {_buildRowSwitch(t('notif_list_created'), notifLists, setNotifLists, colors, false)}
                    {_buildRowSwitch(t('notif_carry_over'), notifCarry, setNotifCarry, colors, false)}
                    {_buildRowSwitch(t('notif_items'), notifItems, setNotifItems, colors, true)}
                </View>

                {/* SECTION: SYNC */}
                <Text style={[styles.sectionHeader, { color: colors.subtext }]}>{t('sync_header')}</Text>
                <View style={[styles.card, { backgroundColor: colors.card, borderColor: colors.border }]}>
                    <View style={styles.syncRow}>
                        <View>
                            <Text style={[styles.syncLabel, { color: colors.subtext }]}>{t('your_sync_code')}</Text>
                            <Text style={[styles.syncCodeText, { color: colors.text }]}>{auth.syncCode}</Text>
                        </View>
                        <Pressable style={[styles.iconActionBtn]} onPress={() => copyToClipboard(auth.syncCode)}>
                            <Copy size={20} color={colors.text} />
                        </Pressable>
                    </View>
                    <View style={[styles.divider, { backgroundColor: colors.border }]}/>
                    <Pressable style={styles.syncRowClickable} onPress={() => setIsSyncModalVisible(true)}>
                        <View style={styles.rowLayoutLeft}>
                            <RefreshCw size={20} color={colors.text} style={{marginRight: 10}} />
                            <Text style={[styles.rowLabelText, { color: colors.text }]}>{t('connect_existing')}</Text>
                        </View>
                    </Pressable>
                </View>

                {/* SECTION: APPEARANCE */}
                <Text style={[styles.sectionHeader, { color: colors.primary }]}>{t('appearance_header')}</Text>
                <View style={[styles.card, { backgroundColor: colors.card, borderColor: colors.border }]}>
                    <View style={styles.selectRow}>
                        <View style={styles.rowLayoutLeft}>
                            <Languages size={20} color={colors.text} />
                            <Text style={[styles.rowLabelText, { color: colors.text, marginLeft: 10 }]}>{t('language_label')}</Text>
                        </View>
                        <Text style={[styles.selectValueText, { color: colors.subtext }]}>{language === 'fr' ? 'Français' : 'English'}</Text>
                    </View>
                    <View style={[styles.divider, { backgroundColor: colors.border }]} />

                    {/* Styled Theme Selection Row */}
                    <View style={styles.selectRow}>
                        <View style={styles.rowLayoutLeft}>
                            <Moon size={20} color={colors.text} />
                            <Text style={[styles.rowLabelText, { color: colors.text, marginLeft: 10 }]}>
                                {t('theme_mode')}
                            </Text>
                        </View>

                        <View
                            style={{
                                width: 150,
                                borderRadius: 8,
                                borderWidth: 1,
                                borderColor: colors.border,
                                backgroundColor: colors.card,
                                overflow: 'hidden',
                                justifyContent: 'center'
                            }}
                        >
                            <Picker
                                selectedValue={themeMode}
                                onValueChange={(itemValue) => setTheme(itemValue as ThemeMode)}
                                style={{
                                    color: colors.text,
                                    backgroundColor: colors.card,
                                }}
                                dropdownIconColor={colors.subtext}
                                mode="dropdown"
                            >
                                {themeOptions.map((opt) => (
                                    <Picker.Item
                                        key={opt.value}
                                        label={opt.label}
                                        value={opt.value}
                                        color={colors.text}
                                        style={{
                                            backgroundColor: colors.card,
                                            color: colors.text
                                        }}
                                    />
                                ))}
                            </Picker>
                        </View>
                    </View>
                    <View style={[styles.divider, { backgroundColor: colors.border }]} />

                    <Text style={[styles.colorMatrixLabel, { color: colors.text }]}>Couleur principale</Text>
                    <View style={styles.colorGrid}>
                        {colorPalette.map((color) => {
                            const isSelected = colorSeed === color;
                            return (
                                <Pressable
                                    key={color}
                                    style={[styles.colorCircle, { backgroundColor: color }]}
                                    onPress={() => setColorSeed(color)} // Fires the context persistent store action
                                >
                                    {isSelected && <View style={styles.colorIndicatorDot} />}
                                </Pressable>
                            );
                        })}
                    </View>
                </View>

                {/* SECTION: DANGER ZONE */}
                <Text style={[styles.sectionHeader, { color: '#ef4444' }]}>{t('danger_zone')}</Text>
                <View style={[styles.card, styles.dangerCard, { backgroundColor: themeMode === 'dark' ? '#2c1a1a' : '#fff5f5', borderColor: '#fecaca' }]}>
                    <Pressable style={styles.syncRowClickable} onPress={handleFactoryReset}>
                        <View style={styles.rowLayoutLeft}>
                            <Trash2 size={20} color="#ef4444" />
                            <Text style={[styles.rowLabelText, { color: '#ef4444', fontWeight: '600', marginLeft: 10 }]}>{t('factory_reset')}</Text>
                        </View>
                    </Pressable>
                </View>
            </ScrollView>
            {/* SYNC ALERTVIEW DIALOG (FLUTTER REPLACEMENT) */}
            <Modal
                transparent
                visible={isSyncModalVisible}
                animationType="fade"
                onRequestClose={() => setIsSyncModalVisible(false)}
            >
                <KeyboardAvoidingView
                    behavior={Platform.OS === "ios" ? "padding" : "height"}
                    style={styles.modalOverlay}
                >
                    <View style={[styles.dialogBox, { backgroundColor: colors.card, borderColor: colors.border }]}>
                        <Text style={[styles.dialogTitle, { color: colors.text }]}>
                            {t('connect_existing')}
                        </Text>

                        <TextInput
                            style={[styles.dialogInput, { backgroundColor: colors.background, borderColor: colors.border, color: colors.text }]}
                            placeholder={t('sync_hint')}
                            placeholderTextColor={colors.subtext}
                            value={syncInputCode}
                            onChangeText={setSyncInputCode}
                            autoCapitalize="characters"
                            autoCorrect={false}
                        />

                        <View style={styles.dialogActions}>
                            <Pressable
                                style={styles.dialogButton}
                                onPress={() => {
                                    setIsSyncModalVisible(false);
                                    setSyncInputCode('');
                                }}
                            >
                                <Text style={[styles.dialogButtonText, { color: colors.subtext }]}>
                                    {t('cancel')}
                                </Text>
                            </Pressable>

                            <Pressable
                                style={[styles.dialogButton, styles.dialogButtonPrimary, { backgroundColor: colors.primary }]}
                                onPress={handleSyncSubmit}
                            >
                                <Text style={[styles.dialogButtonText, { color: '#fff', fontWeight: '600' }]}>
                                    {t('sync_now')}
                                </Text>
                            </Pressable>
                        </View>
                    </View>
                </KeyboardAvoidingView>
            </Modal>
            {/* 4. Drop clean external reference element at base */}
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

function _buildRowSwitch(label: string, value: boolean, onToggle: (v: boolean) => void, colors: any, hideDivider = false) {
    return (
        <View>
            <View style={styles.switchRow}>
                <Text style={[styles.rowLabelText, { color: colors.text }]}>{label}</Text>
                <Pressable
                    style={[
                        styles.trackElement,
                        value ? { backgroundColor: '#34c759', alignItems: 'flex-end' } : { backgroundColor: colors.border, alignItems: 'flex-start' }
                    ]}
                    onPress={() => onToggle(!value)}
                >
                    <View style={styles.thumbElement} />
                </Pressable>
            </View>
            {!hideDivider && <View style={[styles.divider, { backgroundColor: colors.border }]} />}
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    scrollContent: {
        paddingHorizontal: 16,
        paddingTop: 12,
        paddingBottom: 40,
    },
    sectionHeader: {
        fontSize: 13,
        fontWeight: '700',
        textTransform: 'uppercase',
        letterSpacing: 0.6,
        marginTop: 22,
        marginBottom: 8,
        marginLeft: 4,
    },
    card: {
        borderRadius: 12,
        paddingVertical: 4,
        paddingHorizontal: 16,
        borderWidth: 1,
    },
    dangerCard: {
        borderWidth: 1,
    },
    inputGroup: {
        marginVertical: 10,
    },
    inputLabel: {
        fontSize: 14,
        fontWeight: '500',
        marginBottom: 6,
    },
    input: {
        height: 44,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        fontSize: 15,
    },
    primaryButton: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: 8,
        height: 44,
        marginVertical: 14,
    },
    primaryButtonText: {
        color: '#fff',
        fontSize: 15,
        fontWeight: '600',
        marginLeft: 8,
    },
    btnPressed: {
        opacity: 0.8,
    },
    switchRow: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 14,
    },
    rowLayoutLeft: {
        flexDirection: 'row',
        alignItems: 'center',
    },
    rowLabelText: {
        fontSize: 15,
        fontWeight: '500',
    },
    divider: {
        height: StyleSheet.hairlineWidth,
    },
    syncRow: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 12,
    },
    syncLabel: {
        fontSize: 13,
        marginBottom: 2,
    },
    syncCodeText: {
        fontSize: 16,
        fontFamily: 'monospace',
        fontWeight: '700',
    },
    iconActionBtn: {
        padding: 8,
        borderRadius: 6,
    },
    syncRowClickable: {
        paddingVertical: 14,
    },
    selectRow: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingVertical: 14,
    },
    selectValueText: {
        fontSize: 14,
    },
    colorMatrixLabel: {
        fontSize: 14,
        fontWeight: '500',
        marginTop: 14,
        marginBottom: 10,
    },
    colorGrid: {
        flexDirection: 'row',
        flexWrap: 'wrap',
        paddingBottom: 16,
    },
    colorCircle: {
        width: 36,
        height: 36,
        borderRadius: 18,
        marginRight: 12,
        marginBottom: 12,
        justifyContent: 'center',
        alignItems: 'center',
    },
    colorIndicatorDot: {
        width: 10,
        height: 10,
        borderRadius: 5,
        backgroundColor: '#fff',
    },
    trackElement: {
        width: 46,
        height: 26,
        borderRadius: 13,
        padding: 2,
        justifyContent: 'center',
    },
    thumbElement: {
        width: 22,
        height: 22,
        borderRadius: 11,
        backgroundColor: '#fff',
    },
    modalOverlay: {
        flex: 1,
        backgroundColor: 'rgba(0, 0, 0, 0.4)',
        justifyContent: 'center',
        alignItems: 'center',
        padding: 24,
    },
    dialogBox: {
        width: '100%',
        maxWidth: 320,
        borderRadius: 14,
        padding: 20,
        borderWidth: 1,
        elevation: 5,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.25,
        shadowRadius: 4,
    },
    dialogTitle: {
        fontSize: 18,
        fontWeight: '600',
        marginBottom: 16,
    },
    dialogInput: {
        height: 44,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        fontSize: 15,
        marginBottom: 20,
    },
    dialogActions: {
        flexDirection: 'row',
        justifyContent: 'flex-end',
        gap: 12,
    },
    dialogButton: {
        paddingVertical: 10,
        paddingHorizontal: 16,
        borderRadius: 8,
    },
    dialogButtonPrimary: {
        borderRadius: 8,
    },
    dialogButtonText: {
        fontSize: 15,
    },
});