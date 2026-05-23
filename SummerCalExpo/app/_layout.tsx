import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { useDatabase } from '../src/hooks/useDatabase';

export default function RootLayout() {
  const { ready } = useDatabase();

  useEffect(() => {
    if (ready) {
      import('../src/services/NotificationService').then(m => {
        m.notificationService.requestPermission();
      });
    }
  }, [ready]);

  if (!ready) return null;

  return (
    <>
      <StatusBar style="dark" />
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="event/[id]" options={{ headerTitle: 'Event', presentation: 'card' }} />
        <Stack.Screen name="ai-planner" options={{ headerTitle: 'AI Planner', presentation: 'modal' }} />
        <Stack.Screen name="weather" options={{ headerTitle: 'Weather', presentation: 'modal' }} />
        <Stack.Screen name="ai-settings" options={{ headerTitle: 'AI Settings', presentation: 'card' }} />
        <Stack.Screen name="notification-settings" options={{ headerTitle: 'Notifications', presentation: 'card' }} />
      </Stack>
    </>
  );
}
