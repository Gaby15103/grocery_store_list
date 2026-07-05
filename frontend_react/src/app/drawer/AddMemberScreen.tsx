import React, { useState } from 'react';
import {
    StyleSheet,
    Text,
    TextInput,
    TouchableOpacity,
    View,
    ActivityIndicator,
    Alert,
    KeyboardAvoidingView,
    Platform,
    ScrollView
} from 'react-native';
import {useLocalSearchParams, router, Stack} from 'expo-router';
import {useAuth} from "@/context/authContext";
import {AntDesign, Ionicons} from "@expo/vector-icons";
import {useTheme} from "@/context/themeContext";

export default function AddMemberScreen() {
    const { provisionNewUser } = useAuth();
    const { groupId } = useLocalSearchParams<{ groupId: string }>();
    const { colors } = useTheme();

    const [loading, setLoading] = useState(false);
    const [email, setEmail] = useState('');
    const [firstName, setFirstName] = useState('');
    const [lastName, setLastName] = useState('');
    const [message, setMessage] = useState('');

    const handleCreateUser = async () => {
        if (!email || !firstName || !lastName) {
            Alert.alert('Erreur', 'Veuillez remplir tous les champs.');
            return;
        }

        if (!groupId) {
            Alert.alert('Erreur', 'Aucun identifiant de groupe trouvé.');
            return;
        }

        setLoading(true);
        try {
            await provisionNewUser(
                firstName.trim(),
                lastName.trim(),
                email.trim(),
                groupId,
                message
            );

            Alert.alert(
                'Utilisateur Ajouté',
                'Le profil a été généré et sa clé de synchronisation lui a été envoyée.',
                [{ text: 'OK', onPress: () => router.back() }]
            );
        } catch (error: any) {
            Alert.alert('Erreur de création', error.message || 'Impossible de créer le membre.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <View style={styles.root}>
            <Stack.Screen
                options={{
                    title: "Créez un utilisateur",
                    headerLeft: () => (
                        <TouchableOpacity
                            onPress={() => router.back()}
                            style={{ marginLeft: 16, marginRight: 5 }}
                        >
                            <Ionicons name="arrow-back" size={24} color={colors.text} />
                        </TouchableOpacity>
                    )
                }}
            />
            <KeyboardAvoidingView
                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
            >
                <ScrollView contentContainerStyle={styles.scrollContainer} keyboardShouldPersistTaps="handled">
                    <Text style={[styles.title, {color: colors.text}]}>Ajouter un membre</Text>
                    <Text style={[styles.subtitle, {color: colors.subtext}]}>
                        Créez un profil pour un proche. Une clé d'accès unique lui sera envoyée pour synchroniser ses appareils à votre groupe.
                    </Text>

                    <View style={styles.form}>
                        <TextInput
                            style={[styles.input, {backgroundColor: colors.inputBg, borderColor: colors.inputBorder, color: colors.text}]}
                            placeholder="Prénom"
                            placeholderTextColor={colors.subtext}
                            value={firstName}
                            onChangeText={setFirstName}
                        />
                        <TextInput
                            style={[styles.input, {backgroundColor: colors.inputBg, borderColor: colors.inputBorder, color: colors.text}]}
                            placeholder="Nom de famille"
                            placeholderTextColor={colors.subtext}
                            value={lastName}
                            onChangeText={setLastName}
                        />
                        <TextInput
                            style={[styles.input, {backgroundColor: colors.inputBg, borderColor: colors.inputBorder, color: colors.text}]}
                            placeholder="Adresse courriel"
                            placeholderTextColor={colors.subtext}
                            keyboardType="email-address"
                            autoCapitalize="none"
                            value={email}
                            onChangeText={setEmail}
                        />
                        <TextInput
                            editable
                            style={[styles.textInput, {backgroundColor: colors.inputBg, borderColor: colors.inputBorder, color: colors.text}]}
                            placeholder="Ajouter un message."
                            placeholderTextColor={colors.subtext}
                            multiline
                            maxLength={40}
                            numberOfLines={6}
                            value={message}
                            onChangeText={setMessage}
                        />

                        <TouchableOpacity style={styles.primaryButton} onPress={handleCreateUser} disabled={loading}>
                            {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>Inviter et créer</Text>}
                        </TouchableOpacity>
                    </View>
                </ScrollView>
            </KeyboardAvoidingView>
        </View>

    );
}

const styles = StyleSheet.create({
    root: {
        flex: 1,
        backgroundColor: '#18181b',
    },
    scrollContainer: { flexGrow: 1, justifyContent: 'center', padding: 24 },
    title: { fontSize: 24, fontWeight: 'bold', color: '#f4f4f5', textAlign: 'center', marginBottom: 8 },
    subtitle: { fontSize: 14, color: '#a1a1aa', textAlign: 'center', marginBottom: 32, paddingHorizontal: 16, lineHeight: 20 },
    form: { width: '100%' },
    input: { paddingHorizontal: 16, paddingVertical: 14, borderRadius: 8, fontSize: 16, marginBottom: 16, borderWidth: 1 },
    textInput: {
        paddingHorizontal: 16,
        paddingVertical: 14,
        borderRadius: 8,
        fontSize: 16,
        marginBottom: 16,
        borderWidth: 1,
        height: 100,
        textAlignVertical: 'top',
    },
    primaryButton: { backgroundColor: '#2563eb', paddingVertical: 14, borderRadius: 8, alignItems: 'center', marginTop: 8 },
    buttonText: { color: '#ffffff', fontSize: 16, fontWeight: 'bold' },
});