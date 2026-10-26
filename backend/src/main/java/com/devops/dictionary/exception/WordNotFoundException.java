package com.devops.dictionary.exception;

public class WordNotFoundException extends RuntimeException {
    public WordNotFoundException(String word) {
        super("Word '" + word + "' not found in dictionary");
    }
}
