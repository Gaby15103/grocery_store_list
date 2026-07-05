import React, { useState, useEffect } from 'react';
import {
    StyleSheet,
    View,
    Text,
    TextInput,
    TouchableOpacity,
    ScrollView,
    ActivityIndicator,
    Alert, Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAuth } from "@/context/authContext";
import {useTheme} from "@/context/themeContext";
import * as Linking from 'expo-linking';

export default function SetupScreen() {
    const { register, linkWithCode, isLoading } = useAuth();
    const router = useRouter();

    const [isSyncingMode, setIsSyncingMode] = useState(false);
    const [firstName, setFirstName] = useState('');
    const [lastName, setLastName] = useState('');
    const [email, setEmail] = useState('');
    const [syncCodeInput, setSyncCodeInput] = useState('');
    const { colors } = useTheme();

    useEffect(() => {
        Linking.getInitialURL().then((url) => {
            if (url) handleIncomingUrl(url);
        });

        const subscription = Linking.addEventListener('url', (event) => {
            handleIncomingUrl(event.url);
        });

        return () => subscription.remove();
    }, []);

    const handleIncomingUrl = (url: string) => {
        const { path, queryParams } = Linking.parse(url);
        if ((path === 'setup' || url.includes('/setup')) && queryParams?.code) {
            setIsSyncingMode(true);
            setSyncCodeInput(queryParams.code as string);
        }
    };

    const handleRegisterSubmit = async () => {
        const fNameTrimmed = firstName.trim();
        const lNameTrimmed = lastName.trim();
        const emailTrimmed = email.trim();

        if (!fNameTrimmed || !lNameTrimmed || !emailTrimmed.includes('@')) {
            Alert.alert('Erreur de validation', 'Veuillez remplir tous les champs avec une adresse courriel valide.');
            return;
        }

        try {
            await register(fNameTrimmed, lNameTrimmed, emailTrimmed);
            router.replace('/drawer/home');
        } catch (error: any) {
            Alert.alert('Échec de l’inscription', error.message || 'Une erreur est survenue.');
        }
    };

    const handleSyncSubmit = async () => {
        const codeTrimmed = syncCodeInput.trim();

        if (!codeTrimmed) {
            Alert.alert('Erreur de validation', 'Veuillez saisir un code de synchronisation.');
            return;
        }

        try {
            await linkWithCode(codeTrimmed);
            router.replace('/drawer/home');
        } catch (error: any) {
            Alert.alert('Erreur de synchronisation', 'Impossible de synchroniser le compte avec ce code. Vérifiez-le et réessayez.');
        }
    };

    if (isLoading) {
        return (
            <View style={[styles.centerContainer, {backgroundColor: colors.primary}]}>
                <ActivityIndicator size="large" color="#007AFF" />
            </View>
        );
    }

    return (
        <ScrollView contentContainerStyle={[styles.container, {backgroundColor: colors.background}]} keyboardShouldPersistTaps="handled">
            <View style={styles.logoSection}>
                <Ionicons name="basket" size={90} color="#007AFF" />
                <Text style={[styles.title,{color: colors.text}]}>
                    {isSyncingMode ? 'Synchroniser le compte' : 'Bienvenue sur Grocery Master'}
                </Text>
            </View>

            {!isSyncingMode ? (
                <View style={styles.formContainer}>
                    <Text style={[styles.subtitle, {color: colors.subtext}]}>Créez un compte localement ou associez un profil de groupe existant pour commencer.</Text>

                    <Text style={[styles.label, {color: colors.subtext}]}>Prénom</Text>
                    <TextInput
                        style={[styles.input, {backgroundColor: colors.inputBg, color: colors.subtext, borderColor: colors.border}]}
                        value={firstName}
                        placeholderTextColor={colors.subtext}
                        onChangeText={setFirstName}
                        placeholder="Jean"
                    />

                    <Text style={[styles.label, {color: colors.subtext}]}>Nom</Text>
                    <TextInput
                        style={[styles.input, {backgroundColor: colors.inputBg, color: colors.subtext, borderColor: colors.border}]}
                        value={lastName}
                        placeholderTextColor={colors.subtext}
                        onChangeText={setLastName}
                        placeholder="Tremblay"
                    />

                    <Text style={[styles.label, {color: colors.subtext}]}>Adresse courriel</Text>
                    <TextInput
                        style={[styles.input, {backgroundColor: colors.inputBg, color: colors.subtext, borderColor: colors.border}]}
                        value={email}
                        placeholderTextColor={colors.subtext}
                        onChangeText={setEmail}
                        placeholder="jean.tremblay@exemple.com"
                        autoCapitalize="none"
                        keyboardType="email-address"
                    />

                    <TouchableOpacity style={styles.primaryButton} onPress={handleRegisterSubmit}>
                        <Text style={styles.primaryButtonText}>Commencer</Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                        style={styles.linkButton}
                        onPress={() => setIsSyncingMode(true)}
                    >
                        <Text style={styles.linkButtonText}>Vous avez déjà un compte ? Synchronisez-le</Text>
                    </TouchableOpacity>
                </View>
            ) : (
                <View style={styles.formContainer}>
                    <Text style={styles.subtitle}>Saisissez le jeton de synchronisation généré par votre autre appareil mobile connecté.</Text>

                    <Text style={styles.label}>Code de synchronisation</Text>
                    <TextInput
                        style={[styles.input, styles.codeField, {backgroundColor: colors.inputBg, color: colors.subtext, borderColor: colors.border}]}
                        value={syncCodeInput}
                        placeholderTextColor={colors.subtext}
                        onChangeText={setSyncCodeInput}
                        placeholder="Collez la séquence de code ici..."
                        autoCapitalize="none"
                        autoCorrect={false}
                    />

                    <TouchableOpacity style={styles.primaryButton} onPress={handleSyncSubmit}>
                        <Text style={styles.primaryButtonText}>Synchroniser maintenant</Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                        style={styles.linkButton}
                        onPress={() => setIsSyncingMode(false)}
                    >
                        <Text style={styles.linkButtonText}>Retour au profil d'inscription</Text>
                    </TouchableOpacity>
                </View>
            )}
        </ScrollView>
    );
}

const styles = StyleSheet.create({
    container: {
        flexGrow: 1,
        padding: 24,
        backgroundColor: '#fff',
        justifyContent: 'center',
    },
    centerContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#fff',
    },
    logoSection: {
        alignItems: 'center',
        marginBottom: 32,
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#1c1c1e',
        marginTop: 16,
        textAlign: 'center',
    },
    subtitle: {
        fontSize: 14,
        color: '#8e8e93',
        textAlign: 'center',
        marginBottom: 24,
        lineHeight: 20,
    },
    formContainer: {
        width: '100%',
    },
    label: {
        fontSize: 14,
        fontWeight: '600',
        color: '#1c1c1e',
        marginBottom: 6,
    },
    input: {
        height: 48,
        borderWidth: 1,
        borderColor: '#e5e5ea',
        borderRadius: 8,
        paddingHorizontal: 12,
        fontSize: 16,
        marginBottom: 16,
        backgroundColor: '#fafafa',
    },
    codeField: {
        fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
        textAlign: 'center',
        fontSize: 15,
        borderStyle: 'dashed',
    },
    primaryButton: {
        backgroundColor: '#007AFF',
        height: 48,
        borderRadius: 8,
        justifyContent: 'center',
        alignItems: 'center',
        marginTop: 12,
    },
    primaryButtonText: {
        color: '#fff',
        fontSize: 16,
        fontWeight: '600',
    },
    linkButton: {
        marginTop: 16,
        alignItems: 'center',
    },
    linkButtonText: {
        color: '#007AFF',
        fontSize: 14,
    },
});