export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  timestamp?: string;
}

export interface DefinitionData {
  word: string;
  phonetic: string | null;
  partOfSpeech: string | null;
  definition: string;
  example: string | null;
}

export interface HistoryItem {
  id: number;
  word: string;
  searchedAt: string;
  success: boolean;
}

export interface HealthInfo {
  status: string;
  service: string;
  version: string;
  database: string;
}
