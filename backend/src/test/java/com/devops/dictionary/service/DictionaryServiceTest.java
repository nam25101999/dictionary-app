package com.devops.dictionary.service;

import com.devops.dictionary.dto.DefinitionResponse;
import com.devops.dictionary.exception.WordNotFoundException;
import com.devops.dictionary.model.SearchHistory;
import com.devops.dictionary.model.WordEntry;
import com.devops.dictionary.repository.SearchHistoryRepository;
import com.devops.dictionary.repository.WordEntryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DictionaryServiceTest {

    @Mock
    private WordEntryRepository wordEntryRepository;

    @Mock
    private SearchHistoryRepository searchHistoryRepository;

    private DictionaryService dictionaryService;

    @BeforeEach
    void setUp() {
        dictionaryService = new DictionaryService(wordEntryRepository, searchHistoryRepository);
    }

    @Test
    @DisplayName("findDefinition should return definition and log successful search")
    void shouldFindDefinitionAndLogSuccess() {
        WordEntry entry = new WordEntry("devops", "/ˈdɛv.ɒps/", "noun", "DevOps definition", "Example");
        when(wordEntryRepository.findByWordIgnoreCase("devops")).thenReturn(Optional.of(entry));

        DefinitionResponse result = dictionaryService.findDefinition("  DevOps  ");

        assertThat(result.getWord()).isEqualTo("devops");
        assertThat(result.getPhonetic()).isEqualTo("/ˈdɛv.ɒps/");

        ArgumentCaptor<SearchHistory> historyCaptor = ArgumentCaptor.forClass(SearchHistory.class);
        verify(searchHistoryRepository).save(historyCaptor.capture());
        assertThat(historyCaptor.getValue().getWord()).isEqualTo("devops");
        assertThat(historyCaptor.getValue().isSuccess()).isTrue();
    }

    @Test
    @DisplayName("findDefinition should throw WordNotFoundException and log failed search")
    void shouldThrowAndLogFailureWhenNotFound() {
        when(wordEntryRepository.findByWordIgnoreCase("unknown")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> dictionaryService.findDefinition("unknown"))
                .isInstanceOf(WordNotFoundException.class)
                .hasMessageContaining("unknown");

        ArgumentCaptor<SearchHistory> historyCaptor = ArgumentCaptor.forClass(SearchHistory.class);
        verify(searchHistoryRepository).save(historyCaptor.capture());
        assertThat(historyCaptor.getValue().getWord()).isEqualTo("unknown");
        assertThat(historyCaptor.getValue().isSuccess()).isFalse();
    }

    @Test
    @DisplayName("findDefinition should reject blank input")
    void shouldRejectBlankInput() {
        assertThatThrownBy(() -> dictionaryService.findDefinition("   "))
                .isInstanceOf(IllegalArgumentException.class);
        verify(searchHistoryRepository, never()).save(any());
    }
}
