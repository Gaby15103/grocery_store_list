import React from 'react';
import { Modal, View, Text, Pressable, StyleSheet } from 'react-native';

// Match the native Alert button API structure
export interface AlertButton {
    text: string;
    style?: 'cancel' | 'destructive' | 'default';
    onPress?: () => void;
}

interface CustomAlertProps {
    visible: boolean;
    title: string;
    message: string;
    buttons: AlertButton[];
    colors: {
        card: string;
        border: string;
        text: string;
        subtext: string;
        background: string;
        inputBg: string;
        danger: string
    };
}

export default function CustomAlert({ visible, title, message, buttons, colors }: CustomAlertProps) {
    return (
        <Modal
            transparent
            visible={visible}
            animationType="fade"
            onRequestClose={() => {
                // Handle hardware back button closure by triggering the cancel button if available
                const cancelBtn = buttons.find(b => b.style === 'cancel');
                if (cancelBtn?.onPress) cancelBtn.onPress();
            }}
        >
            <View style={styles.alertOverlay}>
                <View style={[styles.alertContainer, { backgroundColor: colors.card, borderColor: colors.border }]}>
                    <Text style={[styles.alertTitle, { color: colors.text }]}>{title}</Text>
                    <Text style={[styles.alertMessage, { color: colors.subtext }]}>{message}</Text>

                    <View style={styles.alertButtonContainer}>
                        {buttons.map((btn, index) => {
                            const isDestructive = btn.style === 'destructive';
                            const isCancel = btn.style === 'cancel';

                            return (
                                <Pressable
                                    key={index}
                                    style={[
                                        styles.alertButton,
                                        { borderColor: colors.border },
                                        index > 0 && { marginLeft: 12 },
                                        isDestructive && { backgroundColor: '#ef4444' },
                                        isCancel && { backgroundColor: colors.background }
                                    ]}
                                    onPress={btn.onPress}
                                >
                                    <Text style={[
                                        styles.alertButtonText,
                                        { color: colors.text },
                                        isDestructive && { color: '#ffffff', fontWeight: 'bold' },
                                        isCancel && { color: colors.subtext }
                                    ]}>
                                        {btn.text}
                                    </Text>
                                </Pressable>
                            );
                        })}
                    </View>
                </View>
            </View>
        </Modal>
    );
}

const styles = StyleSheet.create({
    alertOverlay: {
        flex: 1,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        justifyContent: 'center',
        alignItems: 'center',
        padding: 24,
    },
    alertContainer: {
        width: '100%',
        maxWidth: 340,
        borderRadius: 14,
        borderWidth: 1,
        padding: 20,
        alignItems: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 3 },
        shadowOpacity: 0.2,
        shadowRadius: 5,
        elevation: 6,
    },
    alertTitle: {
        fontSize: 18,
        fontWeight: '700',
        marginBottom: 8,
        textAlign: 'center',
    },
    alertMessage: {
        fontSize: 14,
        textAlign: 'center',
        marginBottom: 20,
        lineHeight: 20,
    },
    alertButtonContainer: {
        flexDirection: 'row',
        width: '100%',
        justifyContent: 'flex-end',
    },
    alertButton: {
        flex: 1,
        paddingVertical: 10,
        borderRadius: 8,
        borderWidth: 1,
        alignItems: 'center',
        justifyContent: 'center',
    },
    alertButtonText: {
        fontSize: 14,
        fontWeight: '600',
    },
});
