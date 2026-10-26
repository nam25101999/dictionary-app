package com.devops.dictionary.service;

import com.devops.dictionary.dto.DefinitionResponse;
import com.devops.dictionary.dto.HistoryResponse;
import com.devops.dictionary.exception.WordNotFoundException;
import com.devops.dictionary.model.SearchHistory;
import com.devops.dictionary.model.WordEntry;
import com.devops.dictionary.repository.SearchHistoryRepository;
import com.devops.dictionary.repository.WordEntryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class DictionaryService {

    private final WordEntryRepository wordEntryRepository;
    private final SearchHistoryRepository searchHistoryRepository;

    public DictionaryService(WordEntryRepository wordEntryRepository, SearchHistoryRepository searchHistoryRepository) {
        this.wordEntryRepository = wordEntryRepository;
        this.searchHistoryRepository = searchHistoryRepository;
    }

    @Transactional
    public DefinitionResponse findDefinition(String rawWord) {
        if (rawWord == null || rawWord.trim().isEmpty()) {
            throw new IllegalArgumentException("Search word must not be blank");
        }

        String cleanedWord = rawWord.trim().toLowerCase();
        Optional<WordEntry> entryOptional = wordEntryRepository.findByWordIgnoreCase(cleanedWord);

        boolean found = entryOptional.isPresent();

        // Record history
        SearchHistory history = new SearchHistory(cleanedWord, LocalDateTime.now(), found);
        searchHistoryRepository.save(history);

        if (!found) {
            throw new WordNotFoundException(cleanedWord);
        }

        WordEntry entry = entryOptional.get();
        return new DefinitionResponse(
                entry.getWord(),
                entry.getPhonetic(),
                entry.getPartOfSpeech(),
                entry.getDefinition(),
                entry.getExample()
        );
    }

    @Transactional(readOnly = true)
    public List<HistoryResponse> getRecentHistory() {
        return searchHistoryRepository.findTop20ByOrderBySearchedAtDesc()
                .stream()
                .map(h -> new HistoryResponse(h.getId(), h.getWord(), h.getSearchedAt(), h.isSuccess()))
                .collect(Collectors.toList());
    }
}
