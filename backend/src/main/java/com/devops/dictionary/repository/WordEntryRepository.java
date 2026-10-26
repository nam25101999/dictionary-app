package com.devops.dictionary.repository;

import com.devops.dictionary.model.WordEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface WordEntryRepository extends JpaRepository<WordEntry, Long> {
    Optional<WordEntry> findByWordIgnoreCase(String word);
}
