import { Redirect } from 'expo-router';

export default function Index() {
    // 🚀 Instantly forward anyone landing on the root "/" to your "/setup" view
    return <Redirect href="/setup" />;
}