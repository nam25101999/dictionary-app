package com.devops.dictionary.controller;

import com.devops.dictionary.model.WordEntry;
import com.devops.dictionary.repository.WordEntryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class DictionaryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private WordEntryRepository wordEntryRepository;

    @BeforeEach
    void setUp() {
        wordEntryRepository.deleteAll();
        wordEntryRepository.save(new WordEntry(
                "computer",
                "/kəmˈpjuːtər/",
                "noun",
                "An electronic device for processing data.",
                "Modern computers are powerful."
        ));
    }

    @Test
    @DisplayName("GET /api/define/computer should return HTTP 200 with definition")
    void shouldReturnWordDefinition() throws Exception {
        mockMvc.perform(get("/api/define/computer")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.word").value("computer"))
                .andExpect(jsonPath("$.data.phonetic").value("/kəmˈpjuːtər/"))
                .andExpect(jsonPath("$.data.partOfSpeech").value("noun"))
                .andExpect(jsonPath("$.data.definition").value("An electronic device for processing data."));
    }

    @Test
    @DisplayName("GET /api/define/unknownword should return HTTP 404 with error message")
    void shouldReturn404WhenNotFound() throws Exception {
        mockMvc.perform(get("/api/define/nonexistentword123")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Word 'nonexistentword123' not found in dictionary"));
    }

    @Test
    @DisplayName("GET /api/history should return HTTP 200 with search history list")
    void shouldReturnSearchHistory() throws Exception {
        // Query once to record history
        mockMvc.perform(get("/api/define/computer"));

        mockMvc.perform(get("/api/history")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.data[0].word").value("computer"))
                .andExpect(jsonPath("$.data[0].success").value(true));
    }
}
