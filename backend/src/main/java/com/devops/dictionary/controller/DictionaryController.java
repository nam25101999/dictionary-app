package com.devops.dictionary.controller;

import com.devops.dictionary.dto.ApiResponse;
import com.devops.dictionary.dto.DefinitionResponse;
import com.devops.dictionary.dto.HistoryResponse;
import com.devops.dictionary.service.DictionaryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class DictionaryController {

    private final DictionaryService dictionaryService;

    public DictionaryController(DictionaryService dictionaryService) {
        this.dictionaryService = dictionaryService;
    }

    @GetMapping("/define/{word}")
    public ResponseEntity<ApiResponse<DefinitionResponse>> getDefinition(@PathVariable String word) {
        DefinitionResponse response = dictionaryService.findDefinition(word);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/history")
    public ResponseEntity<ApiResponse<List<HistoryResponse>>> getRecentHistory() {
        List<HistoryResponse> history = dictionaryService.getRecentHistory();
        return ResponseEntity.ok(ApiResponse.success(history));
    }
}
