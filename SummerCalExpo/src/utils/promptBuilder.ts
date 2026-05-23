import { AIPlannerRequest, CalendarEvent, EventNote, PlaceCandidate, UserSettings } from '../models';
import { format } from 'date-fns';

export function buildDayPlannerPrompt(request: AIPlannerRequest): string {
  let prompt = 'You are a helpful day planner. Suggest realistic plans for today.\n\n';
  prompt += `Date: ${request.date}\n`;
  if (request.eventsSummary) prompt += `Events: ${request.eventsSummary}\n`;
  if (request.freeWindows.length === 0) {
    prompt += 'No significant free time today.\n';
  } else {
    const totalFree = request.freeWindows.reduce((s, w) => s + (new Date(w.end).getTime() - new Date(w.start).getTime()), 0) / 3600000;
    prompt += `Free time: ${totalFree.toFixed(1)} hours\n`;
  }
  if (request.weatherSummary) prompt += `Weather: ${request.weatherSummary}\n`;
  if (request.locationSummary) prompt += `Location: ${request.locationSummary}\n`;
  if (request.nearbyPlaces.length > 0) {
    prompt += 'Nearby places:\n';
    for (const p of request.nearbyPlaces.slice(0, 5)) prompt += `  - ${p.name} (${p.category})${p.openNow ? ' [OPEN]' : ''}\n`;
  }
  if (request.userPreferences.length) prompt += `Preferences: ${request.userPreferences.join(', ')}\n`;
  if (request.budgetPreference) prompt += `Budget: ${request.budgetPreference}\n`;
  if (request.energyLevel) prompt += `Energy level: ${request.energyLevel}\n`;
  prompt += '\nProvide: day summary, 3-5 suggestions with title/category/duration/cost, recommended plan, short notification.';
  return prompt;
}

export function buildEventPrepPrompt(event: CalendarEvent, notes: EventNote[], weatherSummary?: string): string {
  let prompt = `I have an event: "${event.title}" at ${format(new Date(event.startDate), 'h:mm a')}.\n`;
  if (event.location) prompt += `Location: ${event.location}\n`;
  if (weatherSummary) prompt += `Weather: ${weatherSummary}\n`;
  const prepNotes = notes.filter(n => n.noteType === 'prep' || n.noteType === 'checklist');
  if (prepNotes.length) {
    prompt += 'Current notes:\n';
    for (const n of prepNotes) prompt += `- ${n.body}\n`;
  }
  prompt += '\nSuggest 3-5 preparation items. Keep it brief.';
  return prompt;
}

export function buildFreeDaySuggestionsPrompt(freeWindows: { start: string; end: string }[], weather: string, places: PlaceCandidate[]): string {
  const totalFree = freeWindows.reduce((s, w) => s + (new Date(w.end).getTime() - new Date(w.start).getTime()), 0) / 3600000;
  let prompt = `Today is mostly free (about ${Math.round(totalFree)} hours). Weather: ${weather}.\n`;
  if (places.length) {
    prompt += 'Nearby options:\n';
    for (const p of places.slice(0, 5)) prompt += `- ${p.name} (${p.category})\n`;
  }
  prompt += '\nSuggest 3-5 specific activity ideas.';
  return prompt;
}

export function buildNoteSummaryPrompt(notes: EventNote[]): string {
  let prompt = 'Summarize these event notes into 1-3 short bullets for a notification preview:\n\n';
  for (const n of notes.slice(0, 5)) prompt += `- ${n.body}\n`;
  return prompt;
}
