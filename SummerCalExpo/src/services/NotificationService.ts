import * as Notifications from 'expo-notifications';
import { CalendarEvent, EventNote, NotificationLog, SmartNotificationKind } from '../models';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

export class NotificationService {
  async requestPermission(): Promise<boolean> {
    const { status } = await Notifications.requestPermissionsAsync();
    return status === 'granted';
  }

  async scheduleEventReminder(event: CalendarEvent, minutesBefore: number, notes?: EventNote[]): Promise<string> {
    const notificationId = `event_reminder_${event.id}_${minutesBefore}`;
    const triggerDate = new Date(new Date(event.startDate).getTime() - minutesBefore * 60 * 1000);

    let body = `Starts in ${minutesBefore} minutes`;
    if (notes && notes.length > 0) {
      body += '. Notes: ' + notes.slice(0, 2).map(n => n.body).join('. ');
    }

    await Notifications.scheduleNotificationAsync({
      identifier: notificationId,
      content: {
        title: event.title,
        body,
        data: { eventId: event.id, notificationType: 'event_reminder' },
        sound: 'default',
      },
      trigger: { date: triggerDate },
    });

    return notificationId;
  }

  async scheduleSmartNotification(
    id: string, title: string, body: string, date: Date, data?: Record<string, unknown>
  ): Promise<void> {
    await Notifications.scheduleNotificationAsync({
      identifier: id,
      content: {
        title, body,
        data: data || {},
        sound: 'default',
      },
      trigger: { date },
    });
  }

  async cancelNotification(id: string): Promise<void> {
    await Notifications.cancelScheduledNotificationAsync(id);
  }

  async cancelEventReminders(eventId: string): Promise<void> {
    const scheduled = await Notifications.getAllScheduledNotificationsAsync();
    for (const notif of scheduled) {
      if ((notif.content.data as any)?.eventId === eventId) {
        await Notifications.cancelScheduledNotificationAsync(notif.identifier);
      }
    }
  }

  async getPendingNotifications(): Promise<Notifications.NotificationRequest[]> {
    return Notifications.getAllScheduledNotificationsAsync();
  }

  async removeAllPending(): Promise<void> {
    await Notifications.cancelAllScheduledNotificationsAsync();
  }
}

export const notificationService = new NotificationService();
