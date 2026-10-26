package com.devops.dictionary.dto;

import java.time.LocalDateTime;

public class HistoryResponse {

    private Long id;
    private String word;
    private LocalDateTime searchedAt;
    private boolean success;

    public HistoryResponse() {
    }

    public HistoryResponse(Long id, String word, LocalDateTime searchedAt, boolean success) {
        this.id = id;
        this.word = word;
        this.searchedAt = searchedAt;
        this.success = success;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getWord() {
        return word;
    }

    public void setWord(String word) {
        this.word = word;
    }

    public LocalDateTime getSearchedAt() {
        return searchedAt;
    }

    public void setSearchedAt(LocalDateTime searchedAt) {
        this.searchedAt = searchedAt;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }
}
