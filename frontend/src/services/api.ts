import { ApiResponse, DefinitionData, HealthInfo, HistoryItem } from '../types/dictionary';

const API_BASE = '/api';

export async function fetchDefinition(word: string): Promise<DefinitionData> {
  const encodedWord = encodeURIComponent(word.trim().toLowerCase());
  const response = await fetch(`${API_BASE}/define/${encodedWord}`);
  
  const payload: ApiResponse<DefinitionData> = await response.json();

  if (!response.ok || !payload.success) {
    throw new Error(payload.message || `Word '${word}' not found.`);
  }

  return payload.data;
}

export async function fetchHistory(): Promise<HistoryItem[]> {
  const response = await fetch(`${API_BASE}/history`);
  
  if (!response.ok) {
    throw new Error('Failed to fetch search history');
  }

  const payload: ApiResponse<HistoryItem[]> = await response.json();
  return payload.data || [];
}

export async function fetchHealth(): Promise<HealthInfo> {
  const response = await fetch(`${API_BASE}/health`);
  
  if (!response.ok) {
    throw new Error('Backend health check returned non-200');
  }

  const payload: ApiResponse<HealthInfo> = await response.json();
  return payload.data;
}
